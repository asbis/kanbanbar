//
//  EnhancedTaskDetailView.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct EnhancedTaskDetailView: View {
    let item: ProjectItem
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingComments = false
    @State private var selectedStatus: String?
    @State private var selectedPriority: String?
    @State private var isUpdatingStatus = false
    @State private var isUpdatingPriority = false
    @State private var showImagePicker = false
    @State private var selectedImages: [NSImage] = []
    @State private var taskNotes = ""
    @State private var estimatedHours: String = ""
    @State private var actualHours: String = ""
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let content = item.content {
                        // Header Section
                        HeaderSection(content: content)
                        
                        Divider()
                        
                        // Enhanced Metadata Section
                        EnhancedMetadataSection(
                            item: item,
                            content: content,
                            selectedStatus: $selectedStatus,
                            selectedPriority: $selectedPriority,
                            isUpdatingStatus: $isUpdatingStatus,
                            isUpdatingPriority: $isUpdatingPriority,
                            estimatedHours: $estimatedHours,
                            actualHours: $actualHours
                        )
                        
                        Divider()
                        
                        // Task Notes Section
                        TaskNotesSection(taskNotes: $taskNotes)
                        
                        Divider()
                        
                        // Tags Section
                        TagsSection(tags: $tags, newTag: $newTag)
                        
                        Divider()
                        
                        // Images Section
                        ImagesSection(
                            selectedImages: $selectedImages,
                            showImagePicker: $showImagePicker
                        )
                        
                        Divider()
                        
                        // Original Labels Section
                        if !content.labels.isEmpty {
                            LabelsSection(labels: content.labels)
                        }
                        
                        // Assignees Section
                        if !content.assignees.isEmpty {
                            AssigneesSection(assignees: content.assignees)
                        }
                    } else {
                        // Draft item
                        DraftItemSection()
                    }
                }
                .padding(20)
            }
            .navigationTitle("Enhanced Task Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            selectedStatus = item.status
            selectedPriority = item.priority
            loadAdditionalData()
        }
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            handleImageSelection(result)
        }
    }
    
    private func loadAdditionalData() {
        // Load additional task data (notes, time tracking, etc.)
        // This would integrate with your backend or local storage
        taskNotes = "Add your task notes here..."
        tags = ["enhancement", "ui"]
        estimatedHours = "4"
        actualHours = "3.5"
    }
    
    private func handleImageSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                if let image = NSImage(contentsOf: url) {
                    selectedImages.append(image)
                }
            }
        case .failure(let error):
            print("Failed to load images: \(error)")
        }
    }
}

struct HeaderSection: View {
    let content: ItemContent
    
    var body: some View {
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
            
            Text(content.title)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
    }
}

struct EnhancedMetadataSection: View {
    let item: ProjectItem
    let content: ItemContent
    @Binding var selectedStatus: String?
    @Binding var selectedPriority: String?
    @Binding var isUpdatingStatus: Bool
    @Binding var isUpdatingPriority: Bool
    @Binding var estimatedHours: String
    @Binding var actualHours: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Task Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                // Status
                VStack(alignment: .leading, spacing: 6) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    StatusPicker(
                        item: item,
                        selectedStatus: $selectedStatus,
                        isUpdating: $isUpdatingStatus
                    )
                }
                
                // Priority
                VStack(alignment: .leading, spacing: 6) {
                    Text("Priority")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    PriorityPicker(
                        item: item,
                        selectedPriority: $selectedPriority,
                        isUpdating: $isUpdatingPriority
                    )
                }
                
                // Estimated Hours
                VStack(alignment: .leading, spacing: 6) {
                    Text("Estimated Hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("Hours", text: $estimatedHours)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Actual Hours
                VStack(alignment: .leading, spacing: 6) {
                    Text("Actual Hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("Hours", text: $actualHours)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Dates
                VStack(alignment: .leading, spacing: 6) {
                    Text("Created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(formatFullDate(content.createdAt))
                        .font(.subheadline)
                        .padding(.vertical, 4)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Updated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(formatFullDate(content.updatedAt))
                        .font(.subheadline)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
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

struct StatusPicker: View {
    let item: ProjectItem
    @Binding var selectedStatus: String?
    @Binding var isUpdating: Bool
    
    var availableStatusOptions: [ProjectFieldOption]? {
        let allProjects = GitHubAPIService.shared.projects
        for project in allProjects {
            if project.items.nodes.contains(where: { $0.id == item.id }) {
                if let statusField = project.fields.validNodes.first(where: { $0.name == "Status" }) {
                    return statusField.safeOptions
                }
            }
        }
        return nil
    }
    
    var body: some View {
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
            .disabled(isUpdating)
            .onChange(of: selectedStatus) { _, newStatus in
                if let newStatus = newStatus, newStatus != item.status {
                    updateTaskStatus(to: newStatus)
                }
            }
        } else if let status = item.status {
            HStack(spacing: 6) {
                Circle()
                    .fill(.gray)
                    .frame(width: 8, height: 8)
                Text(status)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
    
    private func updateTaskStatus(to newStatus: String) {
        guard !isUpdating else { return }
        
        isUpdating = true
        
        Task {
            let success = await GitHubAPIService.shared.moveCard(itemId: item.id, to: newStatus)
            
            if success {
                await GitHubAPIService.shared.fetchProjects()
                await MainActor.run {
                    selectedStatus = newStatus
                    isUpdating = false
                }
            } else {
                await MainActor.run {
                    selectedStatus = item.status
                    isUpdating = false
                }
            }
        }
    }
}

struct PriorityPicker: View {
    let item: ProjectItem
    @Binding var selectedPriority: String?
    @Binding var isUpdating: Bool
    
    var body: some View {
        if let priority = item.priority {
            Text(priority)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(priorityColor(for: priority))
                .cornerRadius(6)
        } else {
            Text("None")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
}

struct TaskNotesSection: View {
    @Binding var taskNotes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextEditor(text: $taskNotes)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct TagsSection: View {
    @Binding var tags: [String]
    @Binding var newTag: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
                .fontWeight(.semibold)
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Button(action: { tags.removeAll { $0 == tag } }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.8))
                    .cornerRadius(12)
                }
                
                HStack(spacing: 4) {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .onSubmit {
                            if !newTag.isEmpty && !tags.contains(newTag) {
                                tags.append(newTag)
                                newTag = ""
                            }
                        }
                    
                    if !newTag.isEmpty {
                        Button(action: {
                            if !tags.contains(newTag) {
                                tags.append(newTag)
                                newTag = ""
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
        }
    }
}

struct ImagesSection: View {
    @Binding var selectedImages: [NSImage]
    @Binding var showImagePicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Images")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showImagePicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Add Image")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if selectedImages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No images attached")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Add Images") {
                        showImagePicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundColor(.secondary.opacity(0.5))
                )
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 100)
                                .clipped()
                                .cornerRadius(8)
                            
                            Button(action: { selectedImages.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .background(Color.white, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
                        }
                    }
                }
            }
        }
    }
}

struct LabelsSection: View {
    let labels: [Label]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GitHub Labels")
                .font(.headline)
                .fontWeight(.semibold)
            
            FlowLayout(spacing: 8) {
                ForEach(labels) { label in
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
}

struct AssigneesSection: View {
    let assignees: [Assignee]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assignees")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(assignees) { assignee in
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
}

struct DraftItemSection: View {
    var body: some View {
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


#Preview {
    EnhancedTaskDetailView(item: createMockProjectItem())
}

private func createMockProjectItem() -> ProjectItem {
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
            "title": "Implement enhanced task details",
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