//
//  Configuration.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import Foundation

struct Configuration {
    struct GitHub {
        static let clientId: String = {
            // First try environment variable
            if let envClientId = ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"],
               !envClientId.isEmpty {
                return envClientId
            }
            
            // Fallback to .env file
            if let envClientId = loadFromEnvFile(key: "GITHUB_CLIENT_ID") {
                return envClientId
            }
            
            // Final fallback to hardcoded value (for development only)
            return "Ov23liUJKpEmyBh1leUf"
        }()
        
        static let clientSecret: String = {
            // First try environment variable
            if let envClientSecret = ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"],
               !envClientSecret.isEmpty {
                return envClientSecret
            }
            
            // Fallback to .env file
            if let envClientSecret = loadFromEnvFile(key: "GITHUB_CLIENT_SECRET") {
                return envClientSecret
            }
            
            // No fallback for client secret - must be provided
            print("⚠️  WARNING: GITHUB_CLIENT_SECRET not found. OAuth will not work.")
            print("   Please create a .env file or set environment variables.")
            return ""
        }()
        
        static let callbackURL = "kanbanbar://oauth/callback"
        static let scope = "repo,read:user,project"
    }
    
    private static func loadFromEnvFile(key: String) -> String? {
        guard let projectRoot = findProjectRoot() else {
            return nil
        }
        
        let envFilePath = projectRoot.appendingPathComponent(".env")
        
        guard FileManager.default.fileExists(atPath: envFilePath.path) else {
            return nil
        }
        
        do {
            let envContent = try String(contentsOf: envFilePath, encoding: .utf8)
            let lines = envContent.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if trimmedLine.hasPrefix("#") || trimmedLine.isEmpty {
                    continue
                }
                
                let parts = trimmedLine.components(separatedBy: "=")
                if parts.count == 2 {
                    let envKey = parts[0].trimmingCharacters(in: .whitespaces)
                    let envValue = parts[1].trimmingCharacters(in: .whitespaces)
                    
                    if envKey == key {
                        return envValue
                    }
                }
            }
        } catch {
            print("Error reading .env file: \(error)")
        }
        
        return nil
    }
    
    private static func findProjectRoot() -> URL? {
        // For development, try the current working directory first
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let envPathInCurrent = currentDir.appendingPathComponent(".env")
        
        if FileManager.default.fileExists(atPath: envPathInCurrent.path) {
            return currentDir
        }
        
        // Try common development paths
        let developmentPaths: [URL] = [
            URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        ]
        
        for devPath in developmentPaths {
            let envPath = devPath.appendingPathComponent(".env")
            if FileManager.default.fileExists(atPath: envPath.path) {
                return devPath
            }
        }
        
        // Fallback to executable path traversal
        guard let executablePath = Bundle.main.executablePath else {
            return nil
        }
        
        var currentPath = URL(fileURLWithPath: executablePath)
        
        while currentPath.path != "/" {
            currentPath = currentPath.deletingLastPathComponent()
            
            let gitPath = currentPath.appendingPathComponent(".git")
            let xcodeProjectPath = currentPath.appendingPathComponent("KanbanBar.xcodeproj")
            
            if FileManager.default.fileExists(atPath: gitPath.path) ||
               FileManager.default.fileExists(atPath: xcodeProjectPath.path) {
                return currentPath
            }
        }
        
        return nil
    }
}