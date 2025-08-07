//
//  GitHubModels.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import Foundation
internal import Combine

// MARK: - User Models
struct GitHubUser: Codable, Identifiable {
    let id: String
    let login: String
    let avatarUrl: String
    let name: String?
    let email: String?
}

// MARK: - Project Models
struct GitHubProject: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let number: Int
    let title: String
    let description: String?
    let url: String
    let items: [ProjectItem]
    
    enum CodingKeys: String, CodingKey {
        case id, number, title, description, url, items
    }
}

struct ProjectItem: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let fieldValues: [FieldValue]
    let content: ItemContent?
    
    var status: String? {
        fieldValues.first { $0.field?.name == "Status" }?.name
    }
    
    var priority: String? {
        fieldValues.first { $0.field?.name == "Priority" }?.name
    }
}

struct FieldValue: Codable, Hashable, Equatable {
    let name: String?
    let field: ProjectField?
}

struct ProjectField: Codable, Hashable, Equatable {
    let name: String
}

enum ItemContent: Codable, Hashable, Equatable {
    case issue(Issue)
    case pullRequest(PullRequest)
    
    var title: String {
        switch self {
        case .issue(let issue):
            return issue.title
        case .pullRequest(let pr):
            return pr.title
        }
    }
    
    var number: Int {
        switch self {
        case .issue(let issue):
            return issue.number
        case .pullRequest(let pr):
            return pr.number
        }
    }
    
    var state: String {
        switch self {
        case .issue(let issue):
            return issue.state
        case .pullRequest(let pr):
            return pr.state
        }
    }
    
    var assignees: [Assignee] {
        switch self {
        case .issue(let issue):
            return issue.assignees?.nodes ?? []
        case .pullRequest(let pr):
            return pr.assignees?.nodes ?? []
        }
    }
    
    var labels: [Label] {
        switch self {
        case .issue(let issue):
            return issue.labels?.nodes ?? []
        case .pullRequest:
            return []
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case issue, pullRequest
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let issue = try? container.decode(Issue.self) {
            self = .issue(issue)
        } else if let pr = try? container.decode(PullRequest.self) {
            self = .pullRequest(pr)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode ItemContent"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .issue(let issue):
            try container.encode(issue)
        case .pullRequest(let pr):
            try container.encode(pr)
        }
    }
}

// MARK: - Issue & PR Models
struct Issue: Codable, Hashable, Equatable {
    let title: String
    let number: Int
    let state: String
    let url: String
    let assignees: AssigneeList?
    let labels: LabelList?
    let createdAt: String
    let updatedAt: String
}

struct PullRequest: Codable, Hashable, Equatable {
    let title: String
    let number: Int
    let state: String
    let url: String
    let assignees: AssigneeList?
    let createdAt: String
    let updatedAt: String
}

struct AssigneeList: Codable, Hashable, Equatable {
    let nodes: [Assignee]
}

struct Assignee: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let login: String
    let avatarUrl: String
}

struct LabelList: Codable, Hashable, Equatable {
    let nodes: [Label]
}

struct Label: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let name: String
    let color: String
}

// MARK: - API Response Models
struct ProjectsResponse: Codable {
    let data: ProjectsData
}

struct ProjectsData: Codable {
    let user: UserProjects?
    let viewer: UserProjects?
}

struct UserProjects: Codable {
    let projectsV2: ProjectList
}

struct ProjectList: Codable {
    let nodes: [GitHubProject]
}

// MARK: - View Models
@MainActor
class ProjectViewModel: ObservableObject {
    @Published var selectedProject: GitHubProject?
    @Published var filteredItems: [ProjectItem] = []
    @Published var searchText: String = ""
    @Published var selectedFilter: ItemFilter = .all
    
    enum ItemFilter: String, CaseIterable {
        case all = "All"
        case assignedToMe = "Assigned to me"
        case createdByMe = "Created by me"
        case mentioned = "Mentioned"
        
        var displayName: String { rawValue }
    }
    
    var columns: [String] {
        guard let project = selectedProject else { return [] }
        let statuses = Set(project.items.compactMap { $0.status })
        return Array(statuses).sorted()
    }
    
    func items(for column: String) -> [ProjectItem] {
        filteredItems.filter { $0.status == column }
    }
    
    func updateFilter() {
        guard let project = selectedProject else {
            filteredItems = []
            return
        }
        
        var items = project.items
        
        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                guard let content = item.content else { return false }
                return content.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply selection filter
        switch selectedFilter {
        case .all:
            break
        case .assignedToMe, .createdByMe, .mentioned:
            // These would require current user info to implement properly
            break
        }
        
        filteredItems = items
    }
}
