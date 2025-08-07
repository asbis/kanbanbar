//
//  AuthenticationService.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import Foundation
internal import Combine
import AuthenticationServices

private struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}

@MainActor
class AuthenticationService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthenticationService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: GitHubUser?
    @Published var isLoading = false
    
    private let keychain = KeychainHelper.shared
    private let clientId = Configuration.GitHub.clientId
    private let clientSecret = Configuration.GitHub.clientSecret
    
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
        let authURL = "https://github.com/login/oauth/authorize?client_id=\(clientId)&scope=\(Configuration.GitHub.scope)"
        _ = "kanbanbar://oauth/callback"
        
        guard let url = URL(string: authURL) else {
            throw AuthError.invalidURL
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "kanbanbar"
            ) { callbackURL, error in
                if let error = error {
                    print("OAuth session error: \(error)")
                    if case ASWebAuthenticationSessionError.canceledLogin = error {
                        continuation.resume(throwing: AuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    print("No callback URL received")
                    continuation.resume(throwing: AuthError.invalidResponse)
                    return
                }
                
                print("Received callback URL: \(callbackURL)")
                
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    print("Could not extract authorization code from callback URL")
                    continuation.resume(throwing: AuthError.invalidResponse)
                    return
                }
                
                print("Extracted authorization code: \(code)")
                
                Task {
                    do {
                        let token = try await self.exchangeCodeForToken(code)
                        print("Successfully obtained access token")
                        continuation.resume(returning: token)
                    } catch {
                        print("Token exchange failed: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            if !session.start() {
                print("Failed to start authentication session")
                continuation.resume(throwing: AuthError.authenticationFailed)
            } else {
                print("Authentication session started successfully")
            }
        }
    }
    
    private func exchangeCodeForToken(_ code: String) async throws -> String {
        let tokenURL = "https://github.com/login/oauth/access_token"
        
        guard let url = URL(string: tokenURL) else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id=\(clientId)",
            "client_secret=\(clientSecret)",
            "code=\(code)"
        ].joined(separator: "&")
        
        request.httpBody = bodyParams.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug logging
        if let httpResponse = response as? HTTPURLResponse {
            print("Token exchange response status: \(httpResponse.statusCode)")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Token exchange response: \(responseString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.invalidResponse
        }
        
        // GitHub might return URL-encoded response instead of JSON
        let responseString = String(data: data, encoding: .utf8) ?? ""
        
        // Try parsing as URL-encoded first
        if responseString.contains("access_token=") {
            var components = URLComponents()
            components.query = responseString
            
            if let accessToken = components.queryItems?.first(where: { $0.name == "access_token" })?.value {
                print("Successfully extracted access token from URL-encoded response")
                return accessToken
            }
        }
        
        // Fallback to JSON parsing
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse.accessToken
    }
    
    private func validateToken(_ token: String) async {
        do {
            let user = try await fetchCurrentUser(token: token)
            self.currentUser = user
            self.isAuthenticated = true
        } catch {
            print("Token validation failed: \(error)")
            _ = keychain.deleteAccessToken()
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Log response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            print("GitHub API Response Status: \(httpResponse.statusCode)")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("GitHub API Response: \(responseString)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(GitHubUser.self, from: data)
    }
    
    func signOut() {
        _ = keychain.deleteAccessToken()
        isAuthenticated = false
        currentUser = nil
    }
}

enum AuthError: Error, LocalizedError {
    case invalidURL
    case authenticationFailed
    case invalidResponse
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidResponse:
            return "Invalid response from server"
        case .userCancelled:
            return "User cancelled authentication"
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthenticationService {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
