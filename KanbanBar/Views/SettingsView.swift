//
//  SettingsView.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var authService = AuthenticationService.shared
    @AppStorage("refreshInterval") private var refreshInterval: Double = 300 // 5 minutes
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                refreshInterval: $refreshInterval,
                launchAtLogin: $launchAtLogin,
                showNotifications: $showNotifications
            )
            .tabItem {
                HStack {
                    Image(systemName: "gear")
                    Text("General")
                }
            }
            
            AccountSettingsView()
                .tabItem {
                    HStack {
                        Image(systemName: "person.circle")
                        Text("Account")
                    }
                }
            
            AboutSettingsView()
                .tabItem {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("About")
                    }
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @Binding var refreshInterval: Double
    @Binding var launchAtLogin: Bool
    @Binding var showNotifications: Bool
    
    var body: some View {
        Form {
            Section("Refresh") {
                HStack {
                    Text("Update interval:")
                    Spacer()
                    Picker("", selection: $refreshInterval) {
                        Text("1 minute").tag(60.0)
                        Text("5 minutes").tag(300.0)
                        Text("15 minutes").tag(900.0)
                        Text("30 minutes").tag(1800.0)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                }
            }
            
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }
            
            Section("Notifications") {
                Toggle("Show notifications", isOn: $showNotifications)
            }
        }
        .padding()
    }
}

struct AccountSettingsView: View {
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            if authService.isAuthenticated {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 48))
                    
                    Text("Connected to GitHub")
                        .font(.headline)
                    
                    if let username = authService.currentUser?.login {
                        Text("Signed in as \(username)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Sign Out") {
                        authService.signOut()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 48))
                    
                    Text("Not connected")
                        .font(.headline)
                    
                    Text("Connect your GitHub account to view your projects")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Connect to GitHub") {
                        Task {
                            await authService.authenticate()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
                
                Text("KanbanBar")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .foregroundColor(.secondary)
                
                Text("GitHub Projects in your menu bar")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("Built with Swift & SwiftUI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Link("GitHub", destination: URL(string: "https://github.com")!)
                    Text("•")
                    Link("Issues", destination: URL(string: "https://github.com")!)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}