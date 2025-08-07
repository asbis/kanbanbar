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
            await MainActor.run {
                error = .noToken
            }
            return
        }
        
        // Print token for testing (remove in production)
        print("🔑 Current GitHub Token: \(token)")
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let query = """
            query GetProjects {
              viewer {
                projectsV2(first: 20) {
                  nodes {
                    id
                    number
                    title
                    url
                    fields(first: 20) {
                      nodes {
                        ... on ProjectV2SingleSelectField {
                          id
                          name
                          options {
                            id
                            name
                            color
                          }
                        }
                      }
                    }
                    items(first: 50) {
                      nodes {
                        id
                        fieldValues(first: 10) {
                          nodes {
                            ... on ProjectV2ItemFieldSingleSelectValue {
                              name
                              optionId
                              field {
                                ... on ProjectV2SingleSelectField {
                                  id
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
                          ... on DraftIssue {
                            title
                            body
                            createdAt
                            updatedAt
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
            let projects = response.data.viewer?.projectsV2.nodes ?? []
            
            await MainActor.run {
                self.projects = projects
                self.error = nil
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.error = error as? APIError ?? .unknown(error)
                self.isLoading = false
            }
            print("Failed to fetch projects: \(error)")
            
            // Let's try a much simpler query to see what we can get
            do {
                let simpleQuery = """
                query GetBasicProjects {
                  viewer {
                    projectsV2(first: 5) {
                      nodes {
                        id
                        number
                        title
                        url
                      }
                    }
                  }
                }
                """
                
                let simpleResponse = try await performSimpleGraphQLQuery(query: simpleQuery, token: token)
                let simpleProjects = simpleResponse.data.viewer?.projectsV2.nodes ?? []
            } catch {
                print("Fallback query failed: \(error)")
            }
        }
    }
    
    func moveCard(itemId: String, to status: String) async -> Bool {
        guard let token = keychain.loadAccessToken() else {
            error = .noToken
            return false
        }
        
        // Find the project and field ID for the status update
        guard let project = projects.first(where: { project in
            project.items.nodes.contains { $0.id == itemId }
        }),
              let statusField = project.fields.validNodes.first(where: { $0.name == "Status" }),
              let option = statusField.safeOptions.first(where: { $0.name == status }) else {
            print("Could not find project, field, or option for move operation")
            print("Available projects: \(projects.map { $0.title })")
            print("Looking for item: \(itemId)")
            print("Target status: \(status)")
            return false
        }
        
        do {
            let mutation = """
            mutation UpdateProjectV2ItemFieldValue {
              updateProjectV2ItemFieldValue(
                input: {
                  projectId: "\(project.id)"
                  itemId: "\(itemId)"
                  fieldId: "\(statusField.id)"
                  value: {
                    singleSelectOptionId: "\(option.id)"
                  }
                }
              ) {
                projectV2Item {
                  id
                }
              }
            }
            """
            
            _ = try await performGraphQLMutation(mutation: mutation, token: token)
            return true
        } catch {
            print("Failed to move card: \(error)")
            self.error = error as? APIError ?? .unknown(error)
            return false
        }
    }
    
    private func performGraphQLMutation(mutation: String, token: String) async throws -> [String: Any] {
        var request = URLRequest(url: graphQLURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["query": mutation]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("HTTP Status: \(statusCode)")
            throw APIError.invalidResponse
        }
        
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }
        
        // Debug the actual mutation response
        if let dataString = String(data: data, encoding: .utf8) {
            print("GraphQL Mutation Response: \(dataString)")
        }
        
        // Check for GraphQL errors
        if let errors = result["errors"] as? [[String: Any]] {
            for error in errors {
                if let message = error["message"] as? String {
                    print("GraphQL Error: \(message)")
                }
            }
            throw APIError.invalidResponse
        }
        
        return result
    }
    
    func updateTask(itemId: String, title: String, body: String?) async -> Bool {
        guard let token = keychain.loadAccessToken() else {
            error = .noToken
            return false
        }
        
        do {
            // Find the project containing this item
            guard let project = projects.first(where: { project in
                project.items.nodes.contains { $0.id == itemId }
            }) else {
                print("Could not find project containing item: \(itemId)")
                return false
            }
            
            // For draft issues, we can update the title and body directly
            let bodyParam = body?.isEmpty == false ? "body: \"\(body!.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n"))\"" : ""
            
            let updateMutation = """
            mutation UpdateProjectV2DraftIssue {
              updateProjectV2DraftIssue(
                input: {
                  draftIssueId: "\(itemId)"
                  title: "\(title.replacingOccurrences(of: "\"", with: "\\\""))"
                  \(bodyParam)
                }
              ) {
                draftIssue {
                  id
                  title
                }
              }
            }
            """
            
            let updateResult = try await performGraphQLMutation(mutation: updateMutation, token: token)
            
            // Check if update was successful
            if let data = updateResult["data"] as? [String: Any],
               let updateProjectV2DraftIssue = data["updateProjectV2DraftIssue"] as? [String: Any],
               updateProjectV2DraftIssue["draftIssue"] != nil {
                print("Successfully updated task: \(title)")
                return true
            } else {
                print("Failed to update task - no draft issue in response")
                return false
            }
            
        } catch {
            print("Failed to update task: \(error)")
            self.error = error as? APIError ?? .unknown(error)
            return false
        }
    }
    
    func createTask(projectId: String, title: String, body: String?, status: ProjectFieldOption?, priority: ProjectFieldOption?) async -> Bool {
        guard let token = keychain.loadAccessToken() else {
            error = .noToken
            return false
        }
        
        do {
            // First, create a draft issue in the project
            let bodyParam = body?.isEmpty == false ? "body: \"\(body!.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n"))\"" : ""
            let createDraftMutation = """
            mutation CreateProjectV2DraftIssue {
              addProjectV2DraftIssue(
                input: {
                  projectId: "\(projectId)"
                  title: "\(title.replacingOccurrences(of: "\"", with: "\\\""))"
                  \(bodyParam)
                }
              ) {
                projectItem {
                  id
                }
              }
            }
            """
            
            let createResult = try await performGraphQLMutation(mutation: createDraftMutation, token: token)
            
            // Extract the item ID from the response
            guard let data = createResult["data"] as? [String: Any],
                  let addProjectV2DraftIssue = data["addProjectV2DraftIssue"] as? [String: Any],
                  let projectItem = addProjectV2DraftIssue["projectItem"] as? [String: Any],
                  let itemId = projectItem["id"] as? String else {
                print("Failed to extract item ID from create response")
                return false
            }
            
            // Set status if provided
            if let status = status,
               let project = projects.first(where: { $0.id == projectId }),
               let statusField = project.fields.validNodes.first(where: { $0.name == "Status" }) {
                
                let setStatusMutation = """
                mutation UpdateProjectV2ItemFieldValue {
                  updateProjectV2ItemFieldValue(
                    input: {
                      projectId: "\(projectId)"
                      itemId: "\(itemId)"
                      fieldId: "\(statusField.id)"
                      value: {
                        singleSelectOptionId: "\(status.id)"
                      }
                    }
                  ) {
                    projectV2Item {
                      id
                    }
                  }
                }
                """
                
                _ = try await performGraphQLMutation(mutation: setStatusMutation, token: token)
            }
            
            // Set priority if provided
            if let priority = priority,
               let project = projects.first(where: { $0.id == projectId }),
               let priorityField = project.fields.validNodes.first(where: { $0.name == "Priority" }),
               priorityField.safeOptions.contains(where: { $0.id == priority.id }) {
                
                let setPriorityMutation = """
                mutation UpdateProjectV2ItemFieldValue {
                  updateProjectV2ItemFieldValue(
                    input: {
                      projectId: "\(projectId)"
                      itemId: "\(itemId)"
                      fieldId: "\(priorityField.id)"
                      value: {
                        singleSelectOptionId: "\(priority.id)"
                      }
                    }
                  ) {
                    projectV2Item {
                      id
                    }
                  }
                }
                """
                
                _ = try await performGraphQLMutation(mutation: setPriorityMutation, token: token)
            }
            
            print("Successfully created task: \(title)")
            return true
            
        } catch {
            print("Failed to create task: \(error)")
            self.error = error as? APIError ?? .unknown(error)
            return false
        }
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
    
    private func performSimpleGraphQLQuery(query: String, token: String) async throws -> SimpleProjectsResponse {
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
        
        return try decoder.decode(SimpleProjectsResponse.self, from: data)
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
