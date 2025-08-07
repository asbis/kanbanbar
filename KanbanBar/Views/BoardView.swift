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
            if newProject != nil {
                viewModel.updateFilter()
            }
        }
        .onChange(of: searchText) { _, newText in
            viewModel.searchText = newText
            viewModel.updateFilter()
        }
        .onChange(of: viewModel.selectedFilter) { _, _ in
            viewModel.updateFilter()
        }
        .onAppear {
            if let firstProject = githubService.projects.first {
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
                ForEach(projects) { project in
                    Text(project.title)
                        .tag(project as GitHubProject?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct SearchFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: ProjectViewModel.ItemFilter
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search tasks...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            Picker("Filter", selection: $selectedFilter) {
                ForEach(ProjectViewModel.ItemFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName)
                        .tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct KanbanBoardView: View {
    let project: GitHubProject
    @ObservedObject var viewModel: ProjectViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(viewModel.columns, id: \.self) { column in
                    ColumnView(
                        title: column,
                        items: viewModel.items(for: column)
                    )
                    .frame(width: 200)
                }
                
                if viewModel.columns.isEmpty {
                    Text("No columns found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ColumnView: View {
    let title: String
    let items: [ProjectItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.separatorColor))
                    .cornerRadius(8)
            }
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        CardView(item: item)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

struct CardView: View {
    let item: ProjectItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let content = item.content {
                HStack {
                    Text("#\(content.number)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    StateIndicator(state: content.state)
                }
                
                Text(content.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                if !content.assignees.isEmpty {
                    HStack {
                        ForEach(content.assignees.prefix(3)) { assignee in
                            AsyncImage(url: URL(string: assignee.avatarUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 16, height: 16)
                            .clipShape(Circle())
                        }
                        
                        if content.assignees.count > 3 {
                            Text("+\(content.assignees.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                if !content.labels.isEmpty {
                    HStack {
                        ForEach(content.labels.prefix(3)) { label in
                            Circle()
                                .fill(Color(hex: label.color) ?? .gray)
                                .frame(width: 8, height: 8)
                        }
                        
                        if content.labels.count > 3 {
                            Text("+\(content.labels.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        .onTapGesture {
            if let _ = item.content,
               let url = URL(string: "https://github.com") {
                NSWorkspace.shared.open(url)
            }
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