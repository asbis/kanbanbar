//
//  AuthenticationView.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
                
                Text("Welcome to KanbanBar")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Connect your GitHub account to view your Projects kanban boards right from your menu bar.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await authService.authenticate()
                    }
                }) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        Text("Connect to GitHub")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(authService.isLoading)
                
                Text("Your credentials are stored securely in the macOS Keychain")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("Features:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    FeatureRow(icon: "rectangle.3.group", text: "View all your GitHub Projects")
                    FeatureRow(icon: "arrow.left.arrow.right", text: "Drag and drop cards between columns")
                    FeatureRow(icon: "bell", text: "Get notified about updates")
                    FeatureRow(icon: "magnifyingglass", text: "Search and filter your tasks")
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    AuthenticationView()
        .frame(width: 400, height: 600)
}