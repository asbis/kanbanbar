//
//  CreateTaskView.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI

struct CreateTaskView: View {
    let project: GitHubProject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var taskCopilot = TaskCopilot()
    @State private var title = ""
    @State private var description = ""
    @State private var selectedStatus: ProjectFieldOption?
    @State private var selectedPriority: ProjectFieldOption?
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showAIMode = false
    @State private var aiInput = ""
    @State private var isProcessingAI = false
    @State private var selectedTemplate: QuickTaskTemplate?
    
    var statusOptions: [ProjectFieldOption] {
        project.fields.validNodes.first { $0.name == "Status" }?.safeOptions ?? []
    }
    
    var priorityOptions: [ProjectFieldOption] {
        project.fields.validNodes.first { $0.name == "Priority" }?.safeOptions ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            taskCreationHeader
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Mode Toggle Card
                    modeToggleCard
                    
                    if showAIMode {
                        // AI Section
                        aiCreationSection
                    } else {
                        // Manual Section
                        manualCreationSection
                    }
                    
                    // Settings Section
                    taskSettingsSection
                    
                    // Error Display
                    if let errorMessage = errorMessage {
                        errorMessageView(errorMessage)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer Actions
            taskCreationFooter
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .onAppear {
            selectedStatus = statusOptions.first
            selectedPriority = priorityOptions.first
        }
    }
    
    @ViewBuilder
    private var taskCreationHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create New Task")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("in \(project.title)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var modeToggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: showAIMode ? "brain.head.profile" : "pencil.and.list.clipboard")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Creation Mode")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Toggle("", isOn: $showAIMode)
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
            }
            
            Text(showAIMode ? "Use AI to generate tasks from natural language descriptions" : "Manually create tasks with detailed form fields")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var aiCreationSection: some View {
        VStack(spacing: 16) {
            // Quick Templates
            quickTemplatesCard
            
            // AI Input
            aiInputCard
        }
    }
    
    @ViewBuilder
    private var quickTemplatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Templates")
                .font(.headline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(QuickTaskTemplate.allCases, id: \.self) { template in
                    Button {
                        selectedTemplate = template
                        aiInput = template.prompt + " "
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: template.icon)
                                .font(.title2)
                                .foregroundColor(selectedTemplate == template ? .white : .blue)
                            Text(template.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .foregroundColor(selectedTemplate == template ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedTemplate == template ? Color.blue : Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTemplate == template ? Color.blue : Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var aiInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Describe Your Task")
                .font(.headline)
                .fontWeight(.medium)
            
            TextField("Describe what you want to create...", text: $aiInput, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(4...8)
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .disabled(isProcessingAI)
            
            if isProcessingAI {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("AI is analyzing your request...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            
            // Example hints
            VStack(alignment: .leading, spacing: 4) {
                Text("Examples:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                HStack {
                    Text("• \"Create a high priority bug for login issues\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                HStack {
                    Text("• \"Add feature request for dark mode with medium priority\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var manualCreationSection: some View {
        VStack(spacing: 16) {
            // Title Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Task Title")
                    .font(.headline)
                    .fontWeight(.medium)
                
                TextField("Enter task title...", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Description Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Description")
                        .font(.headline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("Optional")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TextField("Add a detailed description...", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(3...8)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                
                Text("Provide additional context, requirements, or details about this task.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var taskSettingsSection: some View {
        VStack(spacing: 16) {
            // Status & Priority
            HStack(spacing: 16) {
                // Status
                if !statusOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Status", selection: $selectedStatus) {
                            Text("Choose Status").tag(nil as ProjectFieldOption?)
                            ForEach(statusOptions) { option in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: option.color) ?? .gray)
                                        .frame(width: 8, height: 8)
                                    Text(option.name)
                                }
                                .tag(option as ProjectFieldOption?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Priority
                if !priorityOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Priority", selection: $selectedPriority) {
                            Text("Choose Priority").tag(nil as ProjectFieldOption?)
                            ForEach(priorityOptions) { option in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: option.color) ?? .gray)
                                        .frame(width: 8, height: 8)
                                    Text(option.name)
                                }
                                .tag(option as ProjectFieldOption?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var taskCreationFooter: some View {
        HStack {
            Spacer()
            
            if showAIMode {
                Button("Generate & Create Task") {
                    processAIInput()
                }
                .buttonStyle(.borderedProminent)
                .disabled(aiInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessingAI || isCreating)
                .keyboardShortcut(.return)
            } else {
                Button("Create Task") {
                    createTask()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                .keyboardShortcut(.return)
            }
            
            if isCreating {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private func errorMessageView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func processAIInput() {
        guard !aiInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isProcessingAI = true
        errorMessage = nil
        
        Task {
            // Extract task information from AI input
            let extractedTask = await extractTaskFromAIInput(aiInput)
            
            await MainActor.run {
                isProcessingAI = false
                
                // Apply the extracted information
                title = extractedTask.title
                
                // Find matching status
                if let statusName = extractedTask.status {
                    selectedStatus = statusOptions.first { $0.name.lowercased().contains(statusName.lowercased()) }
                }
                
                // Find matching priority
                if let priorityName = extractedTask.priority {
                    selectedPriority = priorityOptions.first { $0.name.lowercased().contains(priorityName.lowercased()) }
                }
                
                // Automatically create the task
                createTask()
            }
        }
    }
    
    private func extractTaskFromAIInput(_ input: String) async -> ExtractedTaskInfo {
        let lowercaseInput = input.lowercased()
        
        // Extract task type and title
        var cleanTitle = input
        var priority: String? = nil
        var status: String? = nil
        
        // Extract priority
        if lowercaseInput.contains("high priority") || lowercaseInput.contains("urgent") {
            priority = "high"
        } else if lowercaseInput.contains("medium priority") {
            priority = "medium"
        } else if lowercaseInput.contains("low priority") {
            priority = "low"
        }
        
        // Extract status hints
        if lowercaseInput.contains("todo") || lowercaseInput.contains("backlog") {
            status = "todo"
        } else if lowercaseInput.contains("in progress") || lowercaseInput.contains("working") {
            status = "in progress"
        }
        
        // Clean up the title
        let commandWords = ["create", "add", "new", "task", "bug", "feature", "issue", "high priority", "medium priority", "low priority", "urgent"]
        
        for word in commandWords {
            let patterns = [
                "^\(word)\\s+",
                "^\(word)\\s+a\\s+",
                "^\(word)\\s+an\\s+",
                "\\s+\(word)\\s+",
                "\\s+\(word)$"
            ]
            
            for pattern in patterns {
                cleanTitle = cleanTitle.replacingOccurrences(
                    of: pattern,
                    with: " ",
                    options: [.regularExpression, .caseInsensitive]
                )
            }
        }
        
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add appropriate prefix based on detected type
        if lowercaseInput.contains("bug") {
            if !cleanTitle.lowercased().hasPrefix("[bug]") {
                cleanTitle = "[BUG] \(cleanTitle)"
            }
        } else if lowercaseInput.contains("feature") {
            if !cleanTitle.lowercased().hasPrefix("[feature]") {
                cleanTitle = "[FEATURE] \(cleanTitle)"
            }
        }
        
        // Ensure we have a meaningful title
        if cleanTitle.isEmpty || cleanTitle.count < 3 {
            if lowercaseInput.contains("bug") {
                cleanTitle = "[BUG] New bug report"
            } else if lowercaseInput.contains("feature") {
                cleanTitle = "[FEATURE] New feature request"
            } else {
                cleanTitle = "New task from AI"
            }
        }
        
        return ExtractedTaskInfo(
            title: cleanTitle,
            priority: priority,
            status: status
        )
    }
    
    private func createTask() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            let success = await GitHubAPIService.shared.createTask(
                projectId: project.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                status: selectedStatus,
                priority: selectedPriority
            )
            
            await MainActor.run {
                isCreating = false
                
                if success {
                    dismiss()
                    // Refresh the projects to show the new task
                    Task {
                        await GitHubAPIService.shared.fetchProjects()
                    }
                } else {
                    errorMessage = "Failed to create task. Please try again."
                }
            }
        }
    }
}

#Preview {
    let mockProject = GitHubProject(
        id: "1",
        number: 1,
        title: "Sample Project",
        url: "https://github.com",
        fields: ProjectFieldList(nodes: [
            ProjectField(
                id: "status-field",
                name: "Status",
                options: [
                    ProjectFieldOption(id: "todo", name: "Todo", color: "d73a4a"),
                    ProjectFieldOption(id: "in-progress", name: "In Progress", color: "0052cc"),
                    ProjectFieldOption(id: "done", name: "Done", color: "28a745")
                ]
            ),
            ProjectField(
                id: "priority-field",
                name: "Priority",
                options: [
                    ProjectFieldOption(id: "high", name: "High", color: "d73a4a"),
                    ProjectFieldOption(id: "medium", name: "Medium", color: "f9c23c"),
                    ProjectFieldOption(id: "low", name: "Low", color: "28a745")
                ]
            )
        ]),
        items: ProjectItemList(nodes: [])
    )
    
    CreateTaskView(project: mockProject)
}

struct ExtractedTaskInfo {
    let title: String
    let priority: String?
    let status: String?
}

enum QuickTaskTemplate: CaseIterable {
    case bugReport
    case featureRequest
    case documentation
    case improvement
    
    var title: String {
        switch self {
        case .bugReport: return "Bug Report"
        case .featureRequest: return "Feature Request"
        case .documentation: return "Documentation"
        case .improvement: return "Improvement"
        }
    }
    
    var icon: String {
        switch self {
        case .bugReport: return "ladybug"
        case .featureRequest: return "sparkles"
        case .documentation: return "doc.text"
        case .improvement: return "arrow.up.circle"
        }
    }
    
    var prompt: String {
        switch self {
        case .bugReport:
            return "Create a high priority bug report for"
        case .featureRequest:
            return "Add a new feature request for"
        case .documentation:
            return "Create a documentation task for"
        case .improvement:
            return "Add an improvement task for"
        }
    }
}