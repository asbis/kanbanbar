//
//  MainPopoverView.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI

struct MainPopoverView: View {
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var githubService = GitHubAPIService.shared
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(showSettings: $showSettings)
            
            Divider()
            
            // Main Content
            Group {
                if !authService.isAuthenticated {
                    AuthenticationView()
                } else if githubService.projects.isEmpty && !githubService.isLoading {
                    EmptyStateView()
                } else {
                    BoardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 600)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            if authService.isAuthenticated {
                Task {
                    await githubService.fetchProjects()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

struct HeaderView: View {
    @Binding var showSettings: Bool
    @StateObject private var githubService = GitHubAPIService.shared
    
    var body: some View {
        HStack {
            Text("KanbanBar")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 8) {
                if githubService.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }
                
                Button(action: {
                    Task {
                        await githubService.fetchProjects()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh")
                
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    MainPopoverView()
}