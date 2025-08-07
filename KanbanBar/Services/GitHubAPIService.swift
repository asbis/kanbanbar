//
//  GitHubAPIService.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import Foundation
internal import Combine
internal import Combine

@MainActor
class GitHubAPIService: ObservableObject {
    static let shared = GitHubAPIService()
    
    @Published var projects: [GitHubProject] = []
    @Published var isLoading = false
    @Published var error: APIError?
    
    private let keychain = KeychainHelper.shared
    private let graphQLURL = URL(string: "https://api.github.com/graphql")!
    
    private init() {}
    
    func fetchProjects() async {
        guard let token = keychain.loadAccessToken() else {
            error = .noToken
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let query = """
            query GetProjects {
              viewer {
                projectsV2(first: 20) {
                  nodes {
                    id
                    number
                    title
                    description
                    url
                    items(first: 50) {
                      nodes {
                        id
                        fieldValues(first: 10) {
                          nodes {
                            ... on ProjectV2ItemFieldSingleSelectValue {
                              name
                              field {
                                ... on ProjectV2SingleSelectField {
                                  name
                                }
                              }
                            }
                          }
                        }
                        content {
                          ... on Issue {
                            title
                            number
                            state
                            url
                            createdAt
                            updatedAt
                            assignees(first: 5) {
                              nodes {
                                id
                                login
                                avatarUrl
                              }
                            }
                            labels(first: 5) {
                              nodes {
                                id
                                name
                                color
                              }
                            }
                          }
                          ... on PullRequest {
                            title
                            number
                            state
                            url
                            createdAt
                            updatedAt
                            assignees(first: 5) {
                              nodes {
                                id
                                login
                                avatarUrl
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            """
            
            let response = try await performGraphQLQuery(query: query, token: token)
            self.projects = response.data.viewer?.projectsV2.nodes ?? []
            self.error = nil
            
        } catch {
            self.error = error as? APIError ?? .unknown(error)
            print("Failed to fetch projects: \(error)")
        }
    }
    
    func moveCard(itemId: String, to status: String) async -> Bool {
        guard let token = keychain.loadAccessToken() else {
            error = .noToken
            return false
        }
        
        // This would implement the actual card moving logic
        // For now, we'll return true to simulate success
        print("Moving card \(itemId) to \(status)")
        return true
    }
    
    private func performGraphQLQuery(query: String, token: String) async throws -> ProjectsResponse {
        var request = URLRequest(url: graphQLURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(ProjectsResponse.self, from: data)
    }
}

enum APIError: Error, LocalizedError {
    case noToken
    case invalidResponse
    case networkError(Error)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No authentication token found"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
