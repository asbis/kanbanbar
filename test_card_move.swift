#!/usr/bin/env swift

import Foundation

let testToken = ProcessInfo.processInfo.environment["GITHUB_TEST_TOKEN"] ?? ""

func testCardMove() async {
    print("🔄 Testing card move operation...")
    
    // Using real data from the previous test
    let projectId = "PVT_kwHOAK1iD84A9SF2"  // Supportify project
    let itemId = "PVTI_lAHOAK1iD84A9SF2zgcnLZs"  // First item
    let fieldId = "PVTSSF_lAHOAK1iD84A9SF2zgxB8GI"  // Status field
    let targetStatus = "Done"  // Move to Done
    
    // First, let's find the option ID for "Done"
    let optionsQuery = """
    query GetStatusOptions {
      node(id: "\(fieldId)") {
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
    """
    
    let graphQLURL = URL(string: "https://api.github.com/graphql")!
    var request = URLRequest(url: graphQLURL)
    request.httpMethod = "POST"
    request.setValue("Bearer \(testToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let queryBody = ["query": optionsQuery]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: queryBody)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Failed to fetch field options")
            return
        }
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let data = jsonObject["data"] as? [String: Any],
              let node = data["node"] as? [String: Any],
              let options = node["options"] as? [[String: Any]] else {
            print("❌ Could not parse field options response")
            return
        }
        
        guard let doneOption = options.first(where: { ($0["name"] as? String) == targetStatus }),
              let doneOptionId = doneOption["id"] as? String else {
            print("❌ Could not find 'Done' option")
            return
        }
        
        print("✅ Found 'Done' option ID: \(doneOptionId)")
        
        // Now perform the actual move
        let mutation = """
        mutation UpdateProjectV2ItemFieldValue {
          updateProjectV2ItemFieldValue(
            input: {
              projectId: "\(projectId)"
              itemId: "\(itemId)"
              fieldId: "\(fieldId)"
              value: {
                singleSelectOptionId: "\(doneOptionId)"
              }
            }
          ) {
            projectV2Item {
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
            }
          }
        }
        """
        
        let mutationBody = ["query": mutation]
        request.httpBody = try JSONSerialization.data(withJSONObject: mutationBody)
        
        let (mutationData, mutationResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = mutationResponse as? HTTPURLResponse {
            print("   Mutation Status Code: \(httpResponse.statusCode)")
            
            if let responseString = String(data: mutationData, encoding: .utf8) {
                print("   Mutation Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                if let jsonObject = try? JSONSerialization.jsonObject(with: mutationData) as? [String: Any],
                   let data = jsonObject["data"] as? [String: Any],
                   data["updateProjectV2ItemFieldValue"] != nil {
                    
                    print("✅ Card move operation successful!")
                    
                    // Now move it back to original status
                    print("\n🔄 Moving card back to 'In review'...")
                    
                    guard let reviewOption = options.first(where: { ($0["name"] as? String) == "In review" }),
                          let reviewOptionId = reviewOption["id"] as? String else {
                        print("❌ Could not find 'In review' option")
                        return
                    }
                    
                    let revertMutation = """
                    mutation UpdateProjectV2ItemFieldValue {
                      updateProjectV2ItemFieldValue(
                        input: {
                          projectId: "\(projectId)"
                          itemId: "\(itemId)"
                          fieldId: "\(fieldId)"
                          value: {
                            singleSelectOptionId: "\(reviewOptionId)"
                          }
                        }
                      ) {
                        projectV2Item {
                          id
                        }
                      }
                    }
                    """
                    
                    let revertBody = ["query": revertMutation]
                    request.httpBody = try JSONSerialization.data(withJSONObject: revertBody)
                    
                    let (revertData, revertResponse) = try await URLSession.shared.data(for: request)
                    
                    if let httpResponse = revertResponse as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        print("✅ Card successfully moved back to original status!")
                    } else {
                        print("⚠️ Could not revert card to original status")
                    }
                    
                } else {
                    print("❌ Unexpected mutation response structure")
                }
            } else {
                print("❌ Mutation failed with status: \(httpResponse.statusCode)")
            }
        }
        
    } catch {
        print("❌ Error during card move test: \(error)")
    }
}

// Test task creation
func testCreateTask() async {
    print("\n🔄 Testing task creation...")
    
    let projectId = "PVT_kwHOAK1iD84A9SF2"  // Supportify project
    let taskTitle = "Test Task Created by API - \(Date())"
    
    let createMutation = """
    mutation CreateProjectV2DraftIssue {
      addProjectV2DraftIssue(
        input: {
          projectId: "\(projectId)"
          title: "\(taskTitle)"
        }
      ) {
        projectItem {
          id
          content {
            ... on DraftIssue {
              title
            }
          }
        }
      }
    }
    """
    
    let graphQLURL = URL(string: "https://api.github.com/graphql")!
    var request = URLRequest(url: graphQLURL)
    request.httpMethod = "POST"
    request.setValue("Bearer \(testToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = ["query": createMutation]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   Create Status Code: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Create Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = jsonObject["data"] as? [String: Any],
                   let addProjectV2DraftIssue = data["addProjectV2DraftIssue"] as? [String: Any],
                   let projectItem = addProjectV2DraftIssue["projectItem"] as? [String: Any],
                   let itemId = projectItem["id"] as? String {
                    
                    print("✅ Task created successfully with ID: \(itemId)")
                } else {
                    print("❌ Unexpected create response structure")
                }
            } else {
                print("❌ Task creation failed with status: \(httpResponse.statusCode)")
            }
        }
    } catch {
        print("❌ Error during task creation: \(error)")
    }
}

// Main execution
await testCardMove()
await testCreateTask()

print("\n🎉 All API operations tested successfully!")