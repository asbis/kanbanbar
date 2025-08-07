//
//  AuthenticationService.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import Foundation
internal import Combine
internal import Combine
import AuthenticationServices

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: GitHubUser?
    @Published var isLoading = false
    
    private let keychain = KeychainHelper.shared
    private let clientId = "Ov23liUJKpEmyBh1leUf" // Replace with actual client ID from GitHub OAuth App
    
    override init() {
        super.init()
        checkExistingAuth()
    }
    
    private func checkExistingAuth() {
        if let token = keychain.loadAccessToken() {
            Task {
                await validateToken(token)
            }
        }
    }
    
    func authenticate() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let token = try await performOAuthFlow()
            
            if keychain.saveAccessToken(token) {
                await validateToken(token)
            }
        } catch {
            print("Authentication failed: \(error)")
        }
    }
    
    private func performOAuthFlow() async throws -> String {
        // This is a simplified OAuth flow
        // In a real app, you'd need to:
        // 1. Open a web browser to GitHub's OAuth URL
        // 2. Handle the callback with authorization code
        // 3. Exchange the code for an access token
        
        return try await withCheckedThrowingContinuation { continuation in
            let authURL = "https://github.com/login/oauth/authorize?client_id=\(clientId)&scope=repo,read:user,read:project"
            
            guard let url = URL(string: authURL) else {
                continuation.resume(throwing: AuthError.invalidURL)
                return
            }
            
            // For demo purposes, we'll simulate getting a token
            // In reality, you'd handle the OAuth callback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                // This should be replaced with actual OAuth implementation
                continuation.resume(returning: "demo_token_replace_with_real_oauth")
            }
        }
    }
    
    private func validateToken(_ token: String) async {
        do {
            let user = try await fetchCurrentUser(token: token)
            self.currentUser = user
            self.isAuthenticated = true
        } catch {
            print("Token validation failed: \(error)")
            keychain.deleteAccessToken()
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    private func fetchCurrentUser(token: String) async throws -> GitHubUser {
        guard let url = URL(string: "https://api.github.com/user") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(GitHubUser.self, from: data)
    }
    
    func signOut() {
        keychain.deleteAccessToken()
        isAuthenticated = false
        currentUser = nil
    }
}

enum AuthError: Error, LocalizedError {
    case invalidURL
    case authenticationFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
