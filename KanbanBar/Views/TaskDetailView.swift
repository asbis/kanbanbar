//
//  TaskDetailView.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI

struct TaskDetailView: View {
    let item: ProjectItem
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingComments = false
    @State private var selectedStatus: String?
    @State private var isUpdatingStatus = false
    @State private var isEditMode = false
    @State private var editingTitle = ""
    @State private var editingDescription = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let content = item.content {
                        // Header Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: content.state.lowercased() == "open" ? "circle" : "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(content.state.lowercased() == "open" ? .green : .purple)
                                    
                                    Text("#\(content.number)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Open in Browser") {
                                    if let url = URL(string: content.url) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            if isEditMode {
                                TextField("Task title", text: $editingTitle, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            } else {
                                Text(content.title)
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        
                        // Description Section
                        if let body = content.body, !body.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Description")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                
                                if isEditMode {
                                    TextField("Task description", text: $editingDescription, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 14))
                                        .lineLimit(5...15)
                                        .padding(12)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        )
                                } else {
                                    Text(body)
                                        .font(.system(size: 14))
                                        .lineLimit(nil)
                                        .foregroundColor(.primary)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                        .cornerRadius(8)
                                        .textSelection(.enabled)
                                }
                            }
                        } else if isEditMode {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Description")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                TextField("Add a description for this task...", text: $editingDescription, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .lineLimit(5...15)
                                    .padding(12)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        
                        Divider()
                        
                        // Metadata Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Status and Priority
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Status")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    if let availableStatuses = availableStatusOptions, !availableStatuses.isEmpty {
                                        Picker("Status", selection: $selectedStatus) {
                                            ForEach(availableStatuses, id: \.name) { option in
                                                HStack(spacing: 6) {
                                                    Circle()
                                                        .fill(Color(hex: option.color) ?? .gray)
                                                        .frame(width: 8, height: 8)
                                                    Text(option.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                }
                                                .tag(option.name as String?)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .disabled(isUpdatingStatus)
                                        .onChange(of: selectedStatus) { _, newStatus in
                                            if let newStatus = newStatus, newStatus != item.status {
                                                updateTaskStatus(to: newStatus)
                                            }
                                        }
                                    } else if let status = item.status {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(statusColor(for: status))
                                                .frame(width: 8, height: 8)
                                            Text(status)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                    }
                                }
                                
                                if let priority = item.priority {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Priority")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        
                                        Text(priority)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(priorityColor(for: priority))
                                            .cornerRadius(6)
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            // Dates
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Created")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    Text(formatFullDate(content.createdAt))
                                        .font(.subheadline)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Updated")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    Text(formatFullDate(content.updatedAt))
                                        .font(.subheadline)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        
                        // Labels Section
                        if !content.labels.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Labels")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(content.labels) { label in
                                        Text(label.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: label.color) ?? .gray)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        
                        // Assignees Section
                        if !content.assignees.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Assignees")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(spacing: 8) {
                                    ForEach(content.assignees) { assignee in
                                        HStack {
                                            AsyncImage(url: URL(string: assignee.avatarUrl)) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Circle()
                                                    .fill(Color.gray.opacity(0.3))
                                            }
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                            
                                            Text("@\(assignee.login)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    } else {
                        // Draft item
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            
                            VStack(spacing: 8) {
                                Text("Draft Item")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                
                                Text("This is a draft item that hasn't been linked to an issue or pull request yet.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                }
                .padding(20)
            }
            .navigationTitle(isEditMode ? "Edit Task" : "Task Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditMode {
                        Button("Cancel") {
                            cancelEditing()
                        }
                    } else {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isEditMode {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(editingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                        .keyboardShortcut(.return, modifiers: .command)
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                        .keyboardShortcut("e", modifiers: .command)
                    }
                }
                
                if isSaving {
                    ToolbarItem(placement: .status) {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            selectedStatus = item.status
            setupEditingFields()
        }
    }
    
    // MARK: - Editing Functions
    
    private func setupEditingFields() {
        if let content = item.content {
            editingTitle = content.title
            editingDescription = content.body ?? ""
        }
    }
    
    private func startEditing() {
        setupEditingFields()
        isEditMode = true
    }
    
    private func cancelEditing() {
        isEditMode = false
        setupEditingFields() // Reset to original values
    }
    
    private func saveChanges() {
        guard !isSaving else { return }
        
        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = editingDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else { return }
        
        isSaving = true
        
        Task {
            // Call the API to update the task
            let success = await GitHubAPIService.shared.updateTask(
                itemId: item.id,
                title: trimmedTitle,
                body: trimmedDescription.isEmpty ? nil : trimmedDescription
            )
            
            await MainActor.run {
                isSaving = false
                
                if success {
                    isEditMode = false
                    
                    // Refresh the projects to get updated data
                    Task {
                        await GitHubAPIService.shared.fetchProjects()
                    }
                    
                    print("Task updated successfully")
                } else {
                    // Keep edit mode open on failure so user can retry
                    print("Failed to update task")
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var availableStatusOptions: [ProjectFieldOption]? {
        // Find all projects to get the status field options
        let allProjects = GitHubAPIService.shared.projects
        
        // Look for the project that contains this item
        for project in allProjects {
            if project.items.nodes.contains(where: { $0.id == item.id }) {
                // Find the Status field in this project
                if let statusField = project.fields.validNodes.first(where: { $0.name == "Status" }) {
                    return statusField.safeOptions
                }
            }
        }
        return nil
    }
    
    private func updateTaskStatus(to newStatus: String) {
        guard !isUpdatingStatus else { return }
        
        isUpdatingStatus = true
        
        Task {
            let success = await GitHubAPIService.shared.moveCard(itemId: item.id, to: newStatus)
            
            if success {
                print("Status update successful, refreshing projects...")
                
                // Refresh projects to get updated data
                await GitHubAPIService.shared.fetchProjects()
                
                await MainActor.run {
                    // Update the selected status to reflect the change
                    selectedStatus = newStatus
                    isUpdatingStatus = false
                }
            } else {
                print("Status update failed")
                await MainActor.run {
                    // Revert selection on failure
                    selectedStatus = item.status
                    isUpdatingStatus = false
                }
            }
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "todo", "backlog":
            return .gray
        case "in progress", "in review":
            return .blue
        case "done", "completed":
            return .green
        default:
            return .gray
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
    
    private func formatFullDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: date)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var bounds: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
            var currentRowX: CGFloat = 0
            var currentRowY: CGFloat = 0
            var currentRowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentRowX + size.width > maxWidth && currentRowX > 0 {
                    // Move to next row
                    currentRowX = 0
                    currentRowY += currentRowHeight + spacing
                    currentRowHeight = 0
                }
                
                positions.append(CGPoint(x: currentRowX, y: currentRowY))
                currentRowX += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
                bounds.width = max(bounds.width, currentRowX - spacing)
            }
            
            bounds.height = currentRowY + currentRowHeight
        }
    }
}

#Preview {
    // Create a mock project item for preview
    TaskDetailView(item: createMockProjectItem())
}

private func createMockProjectItem() -> ProjectItem {
    // Create mock data using the existing decoder path
    let jsonString = """
    {
        "id": "1",
        "fieldValues": {
            "nodes": [
                {
                    "name": "In Progress",
                    "optionId": "option1",
                    "field": {
                        "id": "field1",
                        "name": "Status"
                    }
                }
            ]
        },
        "content": {
            "title": "Implement dark mode toggle",
            "number": 123,
            "state": "open",
            "url": "https://github.com/example/repo/issues/123",
            "createdAt": "2025-01-07T10:30:00Z",
            "updatedAt": "2025-01-07T15:45:00Z",
            "assignees": {
                "nodes": [
                    {
                        "id": "1",
                        "login": "john-doe",
                        "avatarUrl": "https://github.com/github.png"
                    }
                ]
            },
            "labels": {
                "nodes": [
                    {
                        "id": "1",
                        "name": "enhancement",
                        "color": "0052CC"
                    },
                    {
                        "id": "2",
                        "name": "ui",
                        "color": "1D76DB"
                    }
                ]
            }
        }
    }
    """
    
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try! decoder.decode(ProjectItem.self, from: data)
}