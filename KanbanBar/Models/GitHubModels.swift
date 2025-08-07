//
//  GitHubModels.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
internal import Combine

// MARK: - User Models
struct GitHubUser: Codable, Identifiable, Sendable {
    let id: Int
    let login: String
    let avatarUrl: String
    let name: String?
    let email: String?
}

// MARK: - Project Models
struct GitHubProject: Codable, Identifiable, Hashable, Equatable, Sendable {
    let id: String
    let number: Int
    let title: String
    let url: String
    let fields: ProjectFieldList
    let items: ProjectItemList
    
    enum CodingKeys: String, CodingKey {
        case id, number, title, url, fields, items
    }
    
    init(id: String, number: Int, title: String, url: String, fields: ProjectFieldList, items: ProjectItemList) {
        self.id = id
        self.number = number
        self.title = title
        self.url = url
        self.fields = fields
        self.items = items
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: GitHubProject, rhs: GitHubProject) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ProjectFieldList: Codable, Hashable, Equatable, Sendable {
    let nodes: [ProjectField]
    
    // Regular initializer for testing/preview purposes
    init(nodes: [ProjectField]) {
        self.nodes = nodes
    }
    
    // Custom decoder to handle null/empty field responses
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode as array of optional ProjectFields, filtering out nils
        let optionalNodes = try container.decode([ProjectField?].self, forKey: .nodes)
        self.nodes = optionalNodes.compactMap { $0 }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
    }
    
    private enum CodingKeys: String, CodingKey {
        case nodes
    }
    
    // Computed property for backwards compatibility
    var validNodes: [ProjectField] {
        return nodes
    }
}

struct ProjectField: Hashable, Equatable, Sendable {
    let id: String
    let name: String
    let options: [ProjectFieldOption]?
    
    // Regular initializer for testing/preview purposes
    init(id: String, name: String, options: [ProjectFieldOption]?) {
        self.id = id
        self.name = name
        self.options = options
    }
    
    // Computed property to safely get options
    var safeOptions: [ProjectFieldOption] {
        return options ?? []
    }
}

extension ProjectField: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, options
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode, but provide defaults if missing
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? "unknown-\(UUID().uuidString)"
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown Field"
        self.options = try container.decodeIfPresent([ProjectFieldOption].self, forKey: .options)
        
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(options, forKey: .options)
    }
}

struct ProjectFieldOption: Codable, Identifiable, Hashable, Equatable, Sendable {
    let id: String
    let name: String
    let color: String
}

struct ProjectItemList: Codable, Hashable, Equatable, Sendable {
    let nodes: [ProjectItem]
    
    init(nodes: [ProjectItem]) {
        self.nodes = nodes
    }
}

struct ProjectItem: Identifiable, Hashable, Equatable, Sendable, Transferable {
    let id: String
    let fieldValues: FieldValueList
    let content: ItemContent?
    
    var status: String? {
        fieldValues.nodes.first { $0.field?.name == "Status" }?.name
    }
    
    var priority: String? {
        fieldValues.nodes.first { $0.field?.name == "Priority" }?.name
    }
    
    init(id: String, fieldValues: FieldValueList, content: ItemContent?) {
        self.id = id
        self.fieldValues = fieldValues
        self.content = content
    }
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .data) { item in
            try JSONEncoder().encode(item)
        } importing: { data in
            try JSONDecoder().decode(ProjectItem.self, from: data)
        }
    }
}

extension ProjectItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, fieldValues, content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        fieldValues = try container.decode(FieldValueList.self, forKey: .fieldValues)
        
        // Try to decode content, but if it fails, set it to nil
        content = try? container.decode(ItemContent.self, forKey: .content)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fieldValues, forKey: .fieldValues)
        try container.encodeIfPresent(content, forKey: .content)
    }
}

struct FieldValueList: Codable, Hashable, Equatable, Sendable {
    let nodes: [FieldValue]
    
    init(nodes: [FieldValue]) {
        self.nodes = nodes
    }
}

struct FieldValue: Codable, Hashable, Equatable, Sendable {
    let name: String?
    let optionId: String?
    let field: FieldValueField?
    
    init(name: String?, optionId: String?, field: FieldValueField?) {
        self.name = name
        self.optionId = optionId
        self.field = field
    }
}

struct FieldValueField: Codable, Hashable, Equatable, Sendable {
    let id: String
    let name: String
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}


enum ItemContent: Codable, Hashable, Equatable, Sendable {
    case issue(Issue)
    case pullRequest(PullRequest)
    case draftIssue(DraftIssue)
    
    var title: String {
        switch self {
        case .issue(let issue):
            return issue.title
        case .pullRequest(let pr):
            return pr.title
        case .draftIssue(let draft):
            return draft.title
        }
    }
    
    var number: Int {
        switch self {
        case .issue(let issue):
            return issue.number
        case .pullRequest(let pr):
            return pr.number
        case .draftIssue:
            return 0 // Draft issues don't have numbers
        }
    }
    
    var body: String? {
        switch self {
        case .issue:
            return nil // Regular issues don't expose body in our current model
        case .pullRequest:
            return nil // PRs don't expose body in our current model  
        case .draftIssue(let draft):
            return draft.body
        }
    }
    
    var state: String {
        switch self {
        case .issue(let issue):
            return issue.state
        case .pullRequest(let pr):
            return pr.state
        case .draftIssue:
            return "draft"
        }
    }
    
    var assignees: [Assignee] {
        switch self {
        case .issue(let issue):
            return issue.assignees?.nodes ?? []
        case .pullRequest(let pr):
            return pr.assignees?.nodes ?? []
        case .draftIssue:
            return [] // Draft issues don't have assignees
        }
    }
    
    var labels: [Label] {
        switch self {
        case .issue(let issue):
            return issue.labels?.nodes ?? []
        case .pullRequest:
            return []
        case .draftIssue:
            return [] // Draft issues don't have labels
        }
    }
    
    var url: String {
        switch self {
        case .issue(let issue):
            return issue.url
        case .pullRequest(let pr):
            return pr.url
        case .draftIssue:
            return "" // Draft issues don't have URLs
        }
    }
    
    var createdAt: String {
        switch self {
        case .issue(let issue):
            return issue.createdAt
        case .pullRequest(let pr):
            return pr.createdAt
        case .draftIssue(let draft):
            return draft.createdAt ?? ""
        }
    }
    
    var updatedAt: String {
        switch self {
        case .issue(let issue):
            return issue.updatedAt
        case .pullRequest(let pr):
            return pr.updatedAt
        case .draftIssue(let draft):
            return draft.updatedAt ?? draft.createdAt ?? ""
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case issue, pullRequest, draftIssue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as issue first
        if let issue = try? container.decode(Issue.self) {
            self = .issue(issue)
            return
        }
        
        // Try to decode as pull request
        if let pr = try? container.decode(PullRequest.self) {
            self = .pullRequest(pr)
            return
        }
        
        // Try to decode as draft issue
        if let draft = try? container.decode(DraftIssue.self) {
            self = .draftIssue(draft)
            return
        }
        
        // If none worked, it might be an empty object or something else we don't handle
        // Just throw an error - the parent decoder will handle this as nil content
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Content is not an issue, pull request, or draft issue"
            )
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .issue(let issue):
            try container.encode(issue)
        case .pullRequest(let pr):
            try container.encode(pr)
        case .draftIssue(let draft):
            try container.encode(draft)
        }
    }
}

// MARK: - Issue & PR Models
struct Issue: Codable, Hashable, Equatable, Sendable {
    let title: String
    let number: Int
    let state: String
    let url: String
    let assignees: AssigneeList?
    let labels: LabelList?
    let createdAt: String
    let updatedAt: String
}

struct PullRequest: Codable, Hashable, Equatable, Sendable {
    let title: String
    let number: Int
    let state: String
    let url: String
    let assignees: AssigneeList?
    let createdAt: String
    let updatedAt: String
}

struct AssigneeList: Codable, Hashable, Equatable, Sendable {
    let nodes: [Assignee]
}

struct Assignee: Codable, Identifiable, Hashable, Equatable, Sendable {
    let id: String
    let login: String
    let avatarUrl: String
}

struct LabelList: Codable, Hashable, Equatable, Sendable {
    let nodes: [Label]
}

struct Label: Codable, Identifiable, Hashable, Equatable, Sendable {
    let id: String
    let name: String
    let color: String
}

struct DraftIssue: Codable, Hashable, Equatable, Sendable {
    let title: String
    let body: String?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - API Response Models
struct ProjectsResponse: Codable, Sendable {
    let data: ProjectsData
}

struct ProjectsData: Codable, Sendable {
    let user: UserProjects?
    let viewer: UserProjects?
}

struct UserProjects: Codable, Sendable {
    let projectsV2: ProjectList
}

struct ProjectList: Codable, Sendable {
    let nodes: [GitHubProject]
}

// Simple project model for basic queries
struct SimpleProject: Codable, Identifiable, Sendable {
    let id: String
    let number: Int
    let title: String
    let url: String
}

struct SimpleProjectList: Codable, Sendable {
    let nodes: [SimpleProject]
}

struct SimpleUserProjects: Codable, Sendable {
    let projectsV2: SimpleProjectList
}

struct SimpleProjectsData: Codable, Sendable {
    let viewer: SimpleUserProjects?
}

struct SimpleProjectsResponse: Codable, Sendable {
    let data: SimpleProjectsData
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
    
    var columns: [ProjectFieldOption] {
        guard let project = selectedProject else { return [] }
        
        // Get all single select fields and their options
        var allOptions: [ProjectFieldOption] = []
        for field in project.fields.validNodes {
            // For now, we'll focus on the Status field since that's what determines columns
            // but we could expand this to show other single select fields as separate views
            if field.name == "Status" {
                allOptions.append(contentsOf: field.safeOptions)
            }
        }
        
        return allOptions.sorted(by: { $0.name < $1.name })
    }
    
    var columnNames: [String] {
        return columns.map { $0.name }
    }
    
    func items(for column: String) -> [ProjectItem] {
        filteredItems.filter { $0.status == column }
    }
    
    func updateFilter() {
        guard let project = selectedProject else {
            filteredItems = []
            return
        }
        
        var items = project.items.nodes
        
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
