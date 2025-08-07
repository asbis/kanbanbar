//
//  CopilotView.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI

struct CopilotView: View {
    @StateObject private var copilot = TaskCopilot()
    @StateObject private var githubService = GitHubAPIService.shared
    @State private var inputText = ""
    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(.blue.gradient)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI Task Copilot")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Create and manage tasks with natural language")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if !githubService.projects.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text("Connected to \(githubService.projects.count) project(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                Divider()
                
                // Chat Area
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // Welcome message
                        if copilot.messages.isEmpty {
                            CopilotMessageView(
                                message: CopilotMessage(
                                    id: UUID(),
                                    content: "👋 Hi! I'm your AI task copilot. I can help you:\n\n• Create new tasks\n• Update task status and priority\n• Move tasks between columns\n• Find and organize tasks\n\nJust tell me what you'd like to do in natural language!",
                                    isFromUser: false,
                                    timestamp: Date()
                                )
                            )
                        }
                        
                        ForEach(copilot.messages) { message in
                            CopilotMessageView(message: message)
                        }
                        
                        if isProcessing {
                            CopilotTypingIndicator()
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                
                // Input Area
                VStack(spacing: 12) {
                    // Quick Actions
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuickAction.allCases, id: \.self) { action in
                                Button(action.title) {
                                    inputText = action.prompt
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Text Input
                    HStack(spacing: 12) {
                        TextField("Tell me what you'd like to do...", text: $inputText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...3)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(inputText.isEmpty ? .secondary : .blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.isEmpty || isProcessing)
                    }
                    .padding()
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            }
        }
        .frame(width: 500, height: 600)
        .task {
            // Ensure we have project data
            if githubService.projects.isEmpty {
                await githubService.fetchProjects()
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty, !isProcessing else { return }
        
        let userMessage = CopilotMessage(
            id: UUID(),
            content: inputText,
            isFromUser: true,
            timestamp: Date()
        )
        
        copilot.messages.append(userMessage)
        let prompt = inputText
        inputText = ""
        isProcessing = true
        
        Task {
            await copilot.processMessage(prompt, with: githubService)
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

struct CopilotMessageView: View {
    let message: CopilotMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isFromUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(.blue.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    )
            } else {
                Circle()
                    .fill(.purple.gradient)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: message.id)
    }
}

struct CopilotTypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(.purple.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(.secondary)
                            .frame(width: 8, height: 8)
                            .scaleEffect(0.8 + 0.4 * sin(animationOffset + Double(index) * 0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                )
                
                Text("AI is thinking...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                animationOffset = .pi * 2
            }
        }
    }
}

enum QuickAction: CaseIterable {
    case createTask
    case moveTaskToDone
    case showHighPriority
    case createBugReport
    case showInProgress
    
    var title: String {
        switch self {
        case .createTask: return "Create Task"
        case .moveTaskToDone: return "Move to Done"
        case .showHighPriority: return "Show High Priority"
        case .createBugReport: return "Report Bug"
        case .showInProgress: return "Show In Progress"
        }
    }
    
    var prompt: String {
        switch self {
        case .createTask:
            return "Create a new task"
        case .moveTaskToDone:
            return "Move the latest task to Done"
        case .showHighPriority:
            return "Show me all high priority tasks"
        case .createBugReport:
            return "Create a bug report task"
        case .showInProgress:
            return "Show me all tasks in progress"
        }
    }
}

#Preview {
    CopilotView()
        .frame(width: 500, height: 600)
}