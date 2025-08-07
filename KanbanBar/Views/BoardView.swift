//
//  BoardView.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI

struct BoardView: View {
    @StateObject private var githubService = GitHubAPIService.shared
    @StateObject private var viewModel = ProjectViewModel()
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Project Selector
            ProjectSelectorView(
                selectedProject: $viewModel.selectedProject,
                projects: githubService.projects
            )
            
            Divider()
            
            // Search and Filter Bar
            SearchFilterBar(
                searchText: $searchText,
                selectedFilter: $viewModel.selectedFilter
            )
            
            Divider()
            
            // Kanban Board
            if let selectedProject = viewModel.selectedProject {
                KanbanBoardView(
                    project: selectedProject,
                    viewModel: viewModel
                )
            } else {
                ProjectSelectionPrompt()
            }
        }
        .onChange(of: viewModel.selectedProject) { _, newProject in
            Task { @MainActor in
                if newProject != nil {
                    viewModel.updateFilter()
                }
            }
        }
        .onChange(of: githubService.projects) { _, _ in
            Task { @MainActor in
                // Update selected project with fresh data
                if let currentProject = viewModel.selectedProject,
                   let updatedProject = githubService.projects.first(where: { $0.id == currentProject.id }) {
                    viewModel.selectedProject = updatedProject
                    viewModel.updateFilter()
                }
            }
        }
        .onChange(of: searchText) { _, newText in
            Task { @MainActor in
                viewModel.searchText = newText
                viewModel.updateFilter()
            }
        }
        .onChange(of: viewModel.selectedFilter) { _, _ in
            Task { @MainActor in
                viewModel.updateFilter()
            }
        }
        .onAppear {
            if viewModel.selectedProject == nil, let firstProject = githubService.projects.first {
                viewModel.selectedProject = firstProject
            }
        }
    }
}

struct ProjectSelectorView: View {
    @Binding var selectedProject: GitHubProject?
    let projects: [GitHubProject]
    
    var body: some View {
        HStack {
            Text("Project:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Project", selection: $selectedProject) {
                Text("Select Project...")
                    .tag(nil as GitHubProject?)
                ForEach(projects) { project in
                    Text(project.title)
                        .tag(project as GitHubProject?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

struct SearchFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: ProjectViewModel.ItemFilter
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                TextField("Search tasks...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 1)
            )
            
            // Custom tab-style filter picker
            HStack(spacing: 0) {
                ForEach(ProjectViewModel.ItemFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.displayName)
                            .font(.system(size: 12, weight: selectedFilter == filter ? .semibold : .medium))
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedFilter == filter ? 
                                Color.blue : Color.clear
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(3)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct KanbanBoardView: View {
    let project: GitHubProject
    @ObservedObject var viewModel: ProjectViewModel
    @StateObject private var githubService = GitHubAPIService.shared
    
    private func moveItem(_ item: ProjectItem, to columnName: String) {
        // Store original status for potential rollback
        let originalStatus = item.status
        
        // Optimistic update - immediately update UI
        Task { @MainActor in
            updateItemStatusLocally(item: item, newStatus: columnName)
        }
        
        // Perform actual API call
        Task {
            let success = await GitHubAPIService.shared.moveCard(itemId: item.id, to: columnName)
            
            if success {
                print("Card move successful, confirming with fresh data...")
                // Refresh to get the authoritative state from server
                await GitHubAPIService.shared.fetchProjects()
                
                await MainActor.run {
                    if let currentProject = viewModel.selectedProject,
                       let updatedProject = githubService.projects.first(where: { $0.id == currentProject.id }) {
                        viewModel.selectedProject = updatedProject
                        viewModel.updateFilter()
                    }
                }
            } else {
                print("Card move failed, reverting optimistic update...")
                // Revert the optimistic update
                await MainActor.run {
                    if let originalStatus = originalStatus {
                        updateItemStatusLocally(item: item, newStatus: originalStatus)
                    }
                }
            }
        }
    }
    
    private func updateItemStatusLocally(item: ProjectItem, newStatus: String) {
        guard let project = viewModel.selectedProject else { return }
        
        // Create updated project with modified item status
        var updatedItems = project.items.nodes
        if let itemIndex = updatedItems.firstIndex(where: { $0.id == item.id }) {
            // Update the item's field values to reflect new status
            var updatedFieldValues = updatedItems[itemIndex].fieldValues.nodes
            
            // Remove old status field value
            updatedFieldValues.removeAll { $0.field?.name == "Status" }
            
            // Add new status field value
            if let statusField = project.fields.validNodes.first(where: { $0.name == "Status" }),
               let statusOption = statusField.safeOptions.first(where: { $0.name == newStatus }) {
                let newFieldValue = FieldValue(
                    name: newStatus,
                    optionId: statusOption.id,
                    field: FieldValueField(id: statusField.id, name: "Status")
                )
                updatedFieldValues.append(newFieldValue)
            }
            
            // Create updated item
            let updatedItem = ProjectItem(
                id: item.id,
                fieldValues: FieldValueList(nodes: updatedFieldValues),
                content: item.content
            )
            
            updatedItems[itemIndex] = updatedItem
            
            // Create updated project
            let updatedProject = GitHubProject(
                id: project.id,
                number: project.number,
                title: project.title,
                url: project.url,
                fields: project.fields,
                items: ProjectItemList(nodes: updatedItems)
            )
            
            // Update view model
            viewModel.selectedProject = updatedProject
            viewModel.updateFilter()
        }
    }
    
    var body: some View {
        if viewModel.columns.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                
                Text("No columns found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("This project might not have any status fields configured.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(viewModel.columns) { column in
                        ColumnView(
                            column: column,
                            items: viewModel.items(for: column.name),
                            onDrop: { item in
                                moveItem(item, to: column.name)
                            },
                            project: project
                        )
                        .frame(width: 200)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
    }
}

struct ColumnView: View {
    let column: ProjectFieldOption
    let items: [ProjectItem]
    let onDrop: ((ProjectItem) -> Void)?
    let project: GitHubProject
    @State private var showCreateTask = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column Header
            HStack {
                Circle()
                    .fill(Color(hex: column.color) ?? .gray)
                    .frame(width: 8, height: 8)
                
                Text(column.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(items.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.separatorColor).opacity(0.5))
                    .cornerRadius(10)
                
                Button {
                    showCreateTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add task to \(column.name)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            
            Divider()
            
            // Cards Container
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        CardView(item: item)
                            .draggable(item)
                    }
                    
                    // Add some bottom padding
                    Color.clear
                        .frame(height: 8)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }
            .frame(maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .dropDestination(for: ProjectItem.self) { items, location in
                if let item = items.first {
                    onDrop?(item)
                    return true
                }
                return false
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showCreateTask) {
            CreateTaskView(project: project)
        }
    }
}

struct CardView: View {
    let item: ProjectItem
    @State private var isHovered = false
    @State private var showTaskDetail = false
    @State private var showEnhancedDetail = false
    
    var body: some View {
        cardContent
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .shadow(
                color: isHovered ? .black.opacity(0.15) : .black.opacity(0.06),
                radius: isHovered ? 8 : 3,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isHovered ? Color.blue.opacity(0.3) : Color(NSColor.separatorColor).opacity(0.2),
                        lineWidth: isHovered ? 1 : 0.5
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                showTaskDetail = true
            }
            .contextMenu {
                contextMenuContent
            }
            .sheet(isPresented: $showTaskDetail) {
                TaskDetailView(item: item)
            }
            .sheet(isPresented: $showEnhancedDetail) {
                EnhancedTaskDetailView(item: item)
            }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let content = item.content {
                contentCardBody(content)
            } else {
                draftCardBody
            }
        }
    }
    
    @ViewBuilder
    private func contentCardBody(_ content: ItemContent) -> some View {
        // Header Section
        VStack(alignment: .leading, spacing: 8) {
            headerSection(content)
            titleSection(content)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        
        // Description Section
        if let body = content.body, !body.isEmpty {
            descriptionSection(body)
        }
        
        // Labels Section
        if !content.labels.isEmpty {
            labelsSection(content.labels)
        }
        
        // Bottom Section
        if !content.assignees.isEmpty {
            assigneesSection(content)
        } else {
            Color.clear
                .frame(height: 8)
                .padding(.bottom, 4)
        }
    }
    
    @ViewBuilder
    private var draftCardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Draft")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                Spacer()
            }
            
            Text("Untitled Draft Item")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(12)
    }
    
    @ViewBuilder
    private func headerSection(_ content: ItemContent) -> some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: content.state.lowercased() == "open" ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(content.state.lowercased() == "open" ? .green : .purple)
                
                Text("#\(content.number)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Priority indicator if available
            if let priority = item.priority {
                Text(priority)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor(for: priority))
                    .cornerRadius(10)
            }
        }
    }
    
    @ViewBuilder
    private func titleSection(_ content: ItemContent) -> some View {
        Text(content.title)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private func descriptionSection(_ body: String) -> some View {
        Text(body)
            .font(.system(size: 11))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 4)
    }
    
    @ViewBuilder
    private func labelsSection(_ labels: [Label]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(labels.prefix(4)) { label in
                    Text(label.name)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: label.color) ?? .gray)
                        .cornerRadius(12)
                }
                
                if labels.count > 4 {
                    Text("+\(labels.count - 4)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func assigneesSection(_ content: ItemContent) -> some View {
        HStack {
            HStack(spacing: -6) {
                ForEach(content.assignees.prefix(3)) { assignee in
                    AsyncImage(url: URL(string: assignee.avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(NSColor.controlBackgroundColor), lineWidth: 2)
                    )
                }
                
                if content.assignees.count > 3 {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 24, height: 24)
                        
                        Text("+\(content.assignees.count - 3)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color(NSColor.controlBackgroundColor), lineWidth: 2)
                    )
                }
            }
            
            Spacer()
            
            Text(formatDate(content.updatedAt))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            showTaskDetail = true
        } label: {
            HStack {
                Image(systemName: "eye")
                Text("Quick View")
            }
        }
        
        Button {
            showEnhancedDetail = true
        } label: {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("Enhanced Details")
            }
        }
        
        Divider()
        
        Button {
            copyTaskURL()
        } label: {
            HStack {
                Image(systemName: "doc.on.doc")
                Text("Copy URL")
            }
        }
        
        if let content = item.content {
            Button {
                openInBrowser(content.url)
            } label: {
                HStack {
                    Image(systemName: "safari")
                    Text("Open in Browser")
                }
            }
        }
    }
    
    private func priorityColor(for priority: String) -> Color {
        switch priority.lowercased() {
        case "high", "urgent":
            return .red
        case "medium":
            return .orange
        case "low":
            return .green
        default:
            return .gray
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? date) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: date, to: now)
            if let days = components.day, days < 7 {
                return "\(days)d ago"
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d"
                return dateFormatter.string(from: date)
            }
        }
    }
    
    private func copyTaskURL() {
        if let content = item.content {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(content.url, forType: .string)
        }
    }
    
    private func openInBrowser(_ url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct StateIndicator: View {
    let state: String
    
    var color: Color {
        switch state.lowercased() {
        case "open":
            return .green
        case "closed":
            return .purple
        case "merged":
            return .blue
        default:
            return .gray
        }
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

struct ProjectSelectionPrompt: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.up")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            
            Text("Select a project above to view its kanban board")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 6 {
            let scanner = Scanner(string: hex)
            var hexNumber: UInt64 = 0
            
            if scanner.scanHexInt64(&hexNumber) {
                let r = Double((hexNumber & 0xff0000) >> 16) / 255
                let g = Double((hexNumber & 0x00ff00) >> 8) / 255
                let b = Double(hexNumber & 0x0000ff) / 255
                
                self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
                return
            }
        }
        
        return nil
    }
}

#Preview {
    BoardView()
        .frame(width: 400, height: 600)
}