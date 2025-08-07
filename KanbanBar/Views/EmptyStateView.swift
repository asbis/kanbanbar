//
//  EmptyStateView.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI

struct EmptyStateView: View {
    @StateObject private var githubService = GitHubAPIService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("No Projects Found")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("You don't have any GitHub Projects yet, or they might not be accessible with your current permissions.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await githubService.fetchProjects()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    if let url = URL(string: "https://github.com/new") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Create a Project on GitHub")
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("To get started:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 6) {
                    StepRow(number: "1", text: "Create a Project in your GitHub repository")
                    StepRow(number: "2", text: "Add some issues or pull requests to the project")
                    StepRow(number: "3", text: "Organize them into columns (To Do, In Progress, Done)")
                    StepRow(number: "4", text: "Refresh this app to see your project")
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }
}

struct StepRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 400, height: 600)
}