//
//  GitHubAPITests.swift
//  KanbanBarTests
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import XCTest
@testable import KanbanBar

@MainActor
final class GitHubAPITests: XCTestCase {
    private let testToken = ProcessInfo.processInfo.environment["GITHUB_TEST_TOKEN"] ?? ""
    private var apiService: GitHubAPIService!
    
    override func setUp() {
        super.setUp()
        apiService = GitHubAPIService.shared
        
        // Store test token in keychain for testing
        KeychainHelper.shared.saveAccessToken(testToken)
    }
    
    override func tearDown() {
        // Clean up keychain after tests
        KeychainHelper.shared.deleteAccessToken()
        super.tearDown()
    }
    
    func testTokenIsAvailable() {
        let token = KeychainHelper.shared.loadAccessToken()
        XCTAssertNotNil(token, "Token should be available for testing")
        XCTAssertEqual(token, testToken, "Token should match test token")
    }
    
    func testFetchProjects() async throws {
        // Test fetching projects
        await apiService.fetchProjects()
        
        XCTAssertFalse(apiService.projects.isEmpty, "Should fetch at least one project")
        XCTAssertNil(apiService.error, "Should not have any errors")
        
        print("✅ Successfully fetched \(apiService.projects.count) projects:")
        for project in apiService.projects {
            print("  - \(project.title) (ID: \(project.id))")
            print("    Items: \(project.items.nodes.count)")
            print("    Fields: \(project.fields.nodes.count)")
        }
    }
    
    func testProjectStructure() async throws {
        await apiService.fetchProjects()
        
        guard let firstProject = apiService.projects.first else {
            XCTFail("No projects available for testing")
            return
        }
        
        // Test project structure
        XCTAssertFalse(firstProject.id.isEmpty, "Project should have an ID")
        XCTAssertFalse(firstProject.title.isEmpty, "Project should have a title")
        XCTAssertGreaterThan(firstProject.number, 0, "Project should have a valid number")
        
        // Test fields structure
        print("✅ Project fields:")
        for field in firstProject.fields.validNodes {
            print("  - \(field.name) (ID: \(field.id))")
            if !field.safeOptions.isEmpty {
                print("    Options: \(field.safeOptions.map { $0.name }.joined(separator: ", "))")
            }
        }
        
        // Test items structure
        print("✅ Project items:")
        for item in firstProject.items.nodes {
            print("  - Item \(item.id)")
            if let content = item.content {
                print("    Title: \(content.title)")
                print("    Number: #\(content.number)")
                print("    Status: \(item.status ?? "None")")
                print("    Priority: \(item.priority ?? "None")")
            } else {
                print("    Draft item")
            }
        }
    }
    
    func testStatusFieldExists() async throws {
        await apiService.fetchProjects()
        
        guard let firstProject = apiService.projects.first else {
            XCTFail("No projects available for testing")
            return
        }
        
        let statusField = firstProject.fields.validNodes.first { $0.name == "Status" }
        XCTAssertNotNil(statusField, "Project should have a Status field")
        
        if let statusField = statusField {
            XCTAssertFalse(statusField.safeOptions.isEmpty, "Status field should have options")
            print("✅ Status field options:")
            for option in statusField.safeOptions {
                print("  - \(option.name) (Color: \(option.color))")
            }
        }
    }
    
    func testMoveCard() async throws {
        await apiService.fetchProjects()
        
        guard let firstProject = apiService.projects.first,
              let itemToMove = firstProject.items.nodes.first,
              let statusField = firstProject.fields.validNodes.first(where: { $0.name == "Status" }),
              statusField.safeOptions.count >= 2 else {
            XCTFail("Insufficient test data: need project with items and at least 2 status options")
            return
        }
        
        let originalStatus = itemToMove.status
        let targetStatus = statusField.safeOptions.first { $0.name != originalStatus }?.name
        
        guard let targetStatus = targetStatus else {
            XCTFail("Could not find a different status to move to")
            return
        }
        
        print("🔄 Testing card move from '\(originalStatus ?? "None")' to '\(targetStatus)'")
        
        // Test moving the card
        let success = await apiService.moveCard(itemId: itemToMove.id, to: targetStatus)
        XCTAssertTrue(success, "Card move should succeed")
        
        // Verify the change by fetching fresh data
        await apiService.fetchProjects()
        
        guard let updatedProject = apiService.projects.first(where: { $0.id == firstProject.id }),
              let updatedItem = updatedProject.items.nodes.first(where: { $0.id == itemToMove.id }) else {
            XCTFail("Could not find updated project or item")
            return
        }
        
        XCTAssertEqual(updatedItem.status, targetStatus, "Item status should be updated")
        print("✅ Card successfully moved to '\(updatedItem.status ?? "None")'")
        
        // Move it back to original status if it existed
        if let originalStatus = originalStatus {
            print("🔄 Moving card back to original status: '\(originalStatus)'")
            let moveBackSuccess = await apiService.moveCard(itemId: itemToMove.id, to: originalStatus)
            XCTAssertTrue(moveBackSuccess, "Moving card back should succeed")
        }
    }
    
    func testCreateTask() async throws {
        await apiService.fetchProjects()
        
        guard let firstProject = apiService.projects.first else {
            XCTFail("No projects available for testing")
            return
        }
        
        let testTaskTitle = "Test Task Created at \(Date())"
        
        // Get available status options
        let statusField = firstProject.fields.validNodes.first { $0.name == "Status" }
        let firstStatusOption = statusField?.safeOptions.first
        
        print("🆕 Testing task creation: '\(testTaskTitle)'")
        
        // Create the task
        let success = await apiService.createTask(
            projectId: firstProject.id,
            title: testTaskTitle,
            status: firstStatusOption,
            priority: nil
        )
        
        XCTAssertTrue(success, "Task creation should succeed")
        
        // Verify the task was created by fetching fresh data
        await apiService.fetchProjects()
        
        guard let updatedProject = apiService.projects.first(where: { $0.id == firstProject.id }) else {
            XCTFail("Could not find updated project")
            return
        }
        
        let createdTask = updatedProject.items.nodes.first { item in
            item.content?.title.contains("Test Task Created") == true
        }
        
        if let createdTask = createdTask {
            print("✅ Task successfully created: '\(createdTask.content?.title ?? "Draft")'")
            print("   Status: \(createdTask.status ?? "None")")
        } else {
            print("⚠️ Created task not found in project items (may be a draft)")
        }
    }
    
    func testMultipleOperations() async throws {
        print("🔄 Testing multiple sequential operations...")
        
        await apiService.fetchProjects()
        let initialProjectCount = apiService.projects.count
        
        // Test 1: Fetch projects multiple times
        for i in 1...3 {
            await apiService.fetchProjects()
            XCTAssertEqual(apiService.projects.count, initialProjectCount, "Project count should remain consistent on fetch #\(i)")
        }
        
        // Test 2: Create multiple tasks
        guard let firstProject = apiService.projects.first else {
            XCTFail("No projects available for testing")
            return
        }
        
        for i in 1...2 {
            let success = await apiService.createTask(
                projectId: firstProject.id,
                title: "Batch Test Task #\(i) - \(Date())",
                status: nil,
                priority: nil
            )
            XCTAssertTrue(success, "Batch task creation #\(i) should succeed")
        }
        
        print("✅ Multiple operations test completed successfully")
    }
    
    func testErrorHandling() async throws {
        print("🔄 Testing error handling...")
        
        // Test with invalid item ID
        let invalidMoveSuccess = await apiService.moveCard(itemId: "invalid-id", to: "Done")
        XCTAssertFalse(invalidMoveSuccess, "Move with invalid ID should fail")
        
        // Test with invalid project ID
        let invalidCreateSuccess = await apiService.createTask(
            projectId: "invalid-id",
            title: "Test Task",
            status: nil,
            priority: nil
        )
        XCTAssertFalse(invalidCreateSuccess, "Create with invalid project ID should fail")
        
        print("✅ Error handling test completed")
    }
}

// MARK: - Performance Tests

@MainActor
final class GitHubAPIPerformanceTests: XCTestCase {
    private let testToken = ProcessInfo.processInfo.environment["GITHUB_TEST_TOKEN"] ?? ""
    private var apiService: GitHubAPIService!
    
    override func setUp() {
        super.setUp()
        apiService = GitHubAPIService.shared
        KeychainHelper.shared.saveAccessToken(testToken)
    }
    
    override func tearDown() {
        KeychainHelper.shared.deleteAccessToken()
        super.tearDown()
    }
    
    func testFetchProjectsPerformance() throws {
        measure {
            let expectation = self.expectation(description: "Fetch projects")
            Task {
                await apiService.fetchProjects()
                expectation.fulfill()
            }
            waitForExpectations(timeout: 10.0)
        }
    }
    
    func testConcurrentOperations() throws {
        measure {
            let expectation = self.expectation(description: "Concurrent operations")
            expectation.expectedFulfillmentCount = 5
            
            // Perform 5 concurrent fetch operations
            for _ in 1...5 {
                Task {
                    await apiService.fetchProjects()
                    expectation.fulfill()
                }
            }
            
            waitForExpectations(timeout: 15.0)
        }
    }
}