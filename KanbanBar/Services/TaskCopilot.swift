//
//  TaskCopilot.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import Foundation
internal import Combine

struct CopilotMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

@MainActor
class TaskCopilot: ObservableObject {
    @Published var messages: [CopilotMessage] = []
    
    func processMessage(_ prompt: String, with githubService: GitHubAPIService) async {
        // Analyze the user's intent
        let intent = analyzeIntent(prompt)
        let response = await executeIntent(intent, prompt: prompt, githubService: githubService)
        
        let aiMessage = CopilotMessage(
            id: UUID(),
            content: response,
            isFromUser: false,
            timestamp: Date()
        )
        
        messages.append(aiMessage)
    }
    
    private func analyzeIntent(_ prompt: String) -> TaskIntent {
        let lowercasePrompt = prompt.lowercased()
        
        // Create task intents
        if lowercasePrompt.contains("create") || lowercasePrompt.contains("add") || lowercasePrompt.contains("new") {
            if lowercasePrompt.contains("bug") {
                return .createBugTask
            } else if lowercasePrompt.contains("feature") {
                return .createFeatureTask
            } else {
                return .createGeneralTask
            }
        }
        
        // Move/update task intents
        if lowercasePrompt.contains("move") || lowercasePrompt.contains("update") || lowercasePrompt.contains("change") {
            if lowercasePrompt.contains("done") || lowercasePrompt.contains("complete") {
                return .moveTaskToDone
            } else if lowercasePrompt.contains("progress") || lowercasePrompt.contains("working") {
                return .moveTaskToInProgress
            } else {
                return .updateTaskStatus
            }
        }
        
        // Search/filter intents
        if lowercasePrompt.contains("show") || lowercasePrompt.contains("find") || lowercasePrompt.contains("list") {
            if lowercasePrompt.contains("high priority") || lowercasePrompt.contains("urgent") {
                return .showHighPriorityTasks
            } else if lowercasePrompt.contains("progress") {
                return .showInProgressTasks
            } else if lowercasePrompt.contains("done") || lowercasePrompt.contains("complete") {
                return .showCompletedTasks
            } else {
                return .showAllTasks
            }
        }
        
        // Priority update intents
        if lowercasePrompt.contains("priority") {
            if lowercasePrompt.contains("high") || lowercasePrompt.contains("urgent") {
                return .setHighPriority
            } else if lowercasePrompt.contains("low") {
                return .setLowPriority
            }
        }
        
        // Default to general help
        return .showHelp
    }
    
    private func executeIntent(_ intent: TaskIntent, prompt: String, githubService: GitHubAPIService) async -> String {
        switch intent {
        case .createGeneralTask:
            return await createTask(from: prompt, type: .general, githubService: githubService)
            
        case .createBugTask:
            return await createTask(from: prompt, type: .bug, githubService: githubService)
            
        case .createFeatureTask:
            return await createTask(from: prompt, type: .feature, githubService: githubService)
            
        case .moveTaskToDone:
            return await moveRecentTaskToStatus("Done", githubService: githubService)
            
        case .moveTaskToInProgress:
            return await moveRecentTaskToStatus("In progress", githubService: githubService)
            
        case .updateTaskStatus:
            return await updateTaskStatusFromPrompt(prompt, githubService: githubService)
            
        case .showHighPriorityTasks:
            return await showTasksByFilter(.highPriority, githubService: githubService)
            
        case .showInProgressTasks:
            return await showTasksByFilter(.inProgress, githubService: githubService)
            
        case .showCompletedTasks:
            return await showTasksByFilter(.completed, githubService: githubService)
            
        case .showAllTasks:
            return await showTasksByFilter(.all, githubService: githubService)
            
        case .setHighPriority, .setLowPriority:
            return await updateTaskPriority(from: prompt, githubService: githubService)
            
        case .showHelp:
            return getHelpMessage()
        }
    }
    
    private func createTask(from prompt: String, type: TaskType, githubService: GitHubAPIService) async -> String {
        guard let project = githubService.projects.first else {
            return "❌ No projects available. Please connect to a project first."
        }
        
        // Extract task title from prompt
        let title = extractTaskTitle(from: prompt, type: type)
        
        // Get default status for new tasks
        let statusField = project.fields.validNodes.first { $0.name == "Status" }
        let defaultStatus = statusField?.safeOptions.first { $0.name == "Backlog" || $0.name == "Todo" }
        
        // Get priority if specified
        var priority: ProjectFieldOption? = nil
        if let priorityField = project.fields.validNodes.first(where: { $0.name == "Priority" }) {
            if prompt.lowercased().contains("high priority") || prompt.lowercased().contains("urgent") {
                priority = priorityField.safeOptions.first { $0.name.lowercased().contains("high") }
            } else if prompt.lowercased().contains("low priority") {
                priority = priorityField.safeOptions.first { $0.name.lowercased().contains("low") }
            }
        }
        
        let success = await githubService.createTask(
            projectId: project.id,
            title: title,
            body: nil,
            status: defaultStatus,
            priority: priority
        )
        
        if success {
            await githubService.fetchProjects()
            
            let priorityText = priority != nil ? " with \(priority!.name.lowercased()) priority" : ""
            let statusText = defaultStatus?.name ?? "default status"
            
            return "✅ Successfully created task: \"\(title)\"\n\n📋 Status: \(statusText)\(priorityText)\n🎯 Project: \(project.title)"
        } else {
            return "❌ Failed to create task. Please check your connection and try again."
        }
    }
    
    private func extractTaskTitle(from prompt: String, type: TaskType) -> String {
        // Remove command words to extract the actual task title
        let commandWords = ["create", "add", "new", "task", "bug", "feature", "issue"]
        var cleanTitle = prompt
        
        // Remove command words from the beginning
        for word in commandWords {
            let patterns = [
                "^\(word)\\s+",
                "^\(word)\\s+a\\s+",
                "^\(word)\\s+an\\s+"
            ]
            
            for pattern in patterns {
                cleanTitle = cleanTitle.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
            }
        }
        
        // Clean up the title
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add prefix based on type
        switch type {
        case .bug:
            if !cleanTitle.lowercased().hasPrefix("[bug]") && !cleanTitle.lowercased().hasPrefix("bug:") {
                cleanTitle = "[BUG] \(cleanTitle)"
            }
        case .feature:
            if !cleanTitle.lowercased().hasPrefix("[feature]") && !cleanTitle.lowercased().hasPrefix("feature:") {
                cleanTitle = "[FEATURE] \(cleanTitle)"
            }
        case .general:
            break
        }
        
        // Ensure we have a meaningful title
        if cleanTitle.isEmpty || cleanTitle.count < 3 {
            switch type {
            case .bug:
                return "[BUG] New bug report"
            case .feature:
                return "[FEATURE] New feature request"
            case .general:
                return "New task"
            }
        }
        
        return cleanTitle
    }
    
    private func moveRecentTaskToStatus(_ status: String, githubService: GitHubAPIService) async -> String {
        guard let project = githubService.projects.first else {
            return "❌ No projects available."
        }
        
        // Find the most recent task that's not already in the target status
        guard let recentTask = project.items.nodes
            .filter({ $0.status != status && $0.content != nil })
            .sorted(by: { first, second in
                // Sort by creation date if available, otherwise by ID
                if let firstDate = first.content?.createdAt,
                   let secondDate = second.content?.createdAt {
                    return firstDate > secondDate
                }
                return first.id > second.id
            })
            .first else {
            return "❌ No tasks found that can be moved to \(status)."
        }
        
        let success = await githubService.moveCard(itemId: recentTask.id, to: status)
        
        if success {
            await githubService.fetchProjects()
            
            let taskTitle = recentTask.content?.title ?? "Task #\(recentTask.id.suffix(8))"
            return "✅ Successfully moved task to \(status):\n\n📋 \(taskTitle)\n🎯 Project: \(project.title)"
        } else {
            return "❌ Failed to move task. Please try again."
        }
    }
    
    private func updateTaskStatusFromPrompt(_ prompt: String, githubService: GitHubAPIService) async -> String {
        // This would require more sophisticated parsing to identify specific tasks
        // For now, provide guidance
        return """
        🤔 To update a task status, please be more specific. You can say:
        
        • "Move the latest task to Done"
        • "Move task #123 to In Progress"
        • "Update the bug task to Done"
        
        Or use the quick actions above for common operations.
        """
    }
    
    private func showTasksByFilter(_ filter: TaskFilter, githubService: GitHubAPIService) async -> String {
        guard let project = githubService.projects.first else {
            return "❌ No projects available."
        }
        
        let filteredTasks = project.items.nodes.filter { item in
            switch filter {
            case .all:
                return true
            case .highPriority:
                return item.priority?.lowercased().contains("high") == true
            case .inProgress:
                return item.status?.lowercased().contains("progress") == true
            case .completed:
                return item.status?.lowercased().contains("done") == true ||
                       item.status?.lowercased().contains("complete") == true
            }
        }
        
        if filteredTasks.isEmpty {
            return "📭 No tasks found matching your criteria."
        }
        
        let filterName = filter == .all ? "All tasks" : filter.displayName
        var result = "📋 \(filterName) (\(filteredTasks.count)):\n\n"
        
        for (index, task) in filteredTasks.enumerated() {
            let title = task.content?.title ?? "Draft Task"
            let status = task.status ?? "No Status"
            let priority = task.priority ?? "No Priority"
            let number = task.content?.number != nil ? "#\(task.content!.number)" : ""
            
            result += "• \(title) \(number)\n"
            result += "  Status: \(status) | Priority: \(priority)\n"
            
            if index < filteredTasks.count - 1 {
                result += "\n"
            }
        }
        
        return result
    }
    
    private func updateTaskPriority(from prompt: String, githubService: GitHubAPIService) async -> String {
        _ = prompt // Suppress unused variable warning
        _ = githubService // Suppress unused variable warning
        return """
        🚧 Priority updates are coming soon!
        
        For now, you can:
        • Create new tasks with priority (e.g., "Create a high priority bug task")
        • Move tasks between status columns
        • View tasks by priority level
        """
    }
    
    private func getHelpMessage() -> String {
        return """
        🤖 **AI Task Copilot Help**
        
        I can help you with these commands:
        
        **📝 Creating Tasks:**
        • "Create a new task for user authentication"
        • "Add a bug report for login issues"
        • "Create a high priority feature for dark mode"
        
        **🔄 Moving Tasks:**
        • "Move the latest task to Done"
        • "Update the recent task to In Progress"
        
        **📋 Viewing Tasks:**
        • "Show all high priority tasks"
        • "List tasks in progress"
        • "Show completed tasks"
        
        **💡 Tips:**
        • Be specific about task titles and priorities
        • Use natural language - I'll understand!
        • Try the quick action buttons for common tasks
        """
    }
}

enum TaskIntent {
    case createGeneralTask
    case createBugTask
    case createFeatureTask
    case moveTaskToDone
    case moveTaskToInProgress
    case updateTaskStatus
    case showHighPriorityTasks
    case showInProgressTasks
    case showCompletedTasks
    case showAllTasks
    case setHighPriority
    case setLowPriority
    case showHelp
}

enum TaskType {
    case general
    case bug
    case feature
}

enum TaskFilter {
    case all
    case highPriority
    case inProgress
    case completed
    
    var displayName: String {
        switch self {
        case .all: return "All tasks"
        case .highPriority: return "High priority tasks"
        case .inProgress: return "Tasks in progress"
        case .completed: return "Completed tasks"
        }
    }
}