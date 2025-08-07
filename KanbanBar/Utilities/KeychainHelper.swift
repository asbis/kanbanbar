//
//  KeychainHelper.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let service = "com.kanbanbar.app"
    
    private init() {}
    
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete any existing item
        _ = delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // Convenience methods for common keys
    func saveAccessToken(_ token: String) -> Bool {
        save(key: "github_access_token", value: token)
    }
    
    func loadAccessToken() -> String? {
        load(key: "github_access_token")
    }
    
    func deleteAccessToken() -> Bool {
        delete(key: "github_access_token")
    }
}