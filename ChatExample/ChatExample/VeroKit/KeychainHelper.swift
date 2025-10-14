//
//  KeychainHelper.swift
//  NCW-sandbox
//
//  Created by Adib Dehghan on 2/19/24.
//

import Foundation

final class KeychainHelper: Sendable {
    
    public enum Account {
        case vero
    }
    
    public enum Service {
        case credential
        case token
    }
    
    static let standard = KeychainHelper()
    private init() {}
    
    private func read(service: Service, account: Account = .vero) -> Data? {
        
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        return (result as? Data)
    }
    
    private func save(_ data: Data, service: Service, account: Account = .vero) {

        // Create query
          let query = [
              kSecValueData: data,
              kSecClass: kSecClassGenericPassword,
              kSecAttrService: service,
              kSecAttrAccount: account,
          ] as CFDictionary
          
          // Add data in query to keychain
          let status = SecItemAdd(query, nil)
          
          if status != errSecSuccess {
              // Print out the error
              print("Error: \(status)")
          }

        if status == errSecDuplicateItem {
            // Item already exist, thus update it.
            let query = [
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecClass: kSecClassGenericPassword,
            ] as CFDictionary

            let attributesToUpdate = [kSecValueData: data] as CFDictionary

            // Update existing item
            SecItemUpdate(query, attributesToUpdate)
        }
    }
    
    func delete(service: Service, account: Account = .vero) {
        
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            ] as CFDictionary
        
        // Delete item from keychain
        SecItemDelete(query)
    }
    
    func save<T>(_ item: T, service: Service, account: Account = .vero) where T : Codable {
        
        do {
            // Encode as JSON data and save in keychain
            let data = try JSONEncoder().encode(item)
            save(data, service: service, account: account)
            
        } catch {
            assertionFailure("Fail to encode item for keychain: \(error)")
        }
    }
    
    func read<T>(service: Service, account: Account = .vero, type: T.Type) -> T? where T : Codable {
        
        // Read item data from keychain
        guard let data = read(service: service, account: account) else {
            return nil
        }
        
        // Decode JSON data to object
        do {
            let item = try JSONDecoder().decode(type, from: data)
            return item
        } catch {
            assertionFailure("Fail to decode item for keychain: \(error)")
            return nil
        }
    }
}


class KeychainHelper2 {

    private static let account = "VeroAccount"
    private static let service = "VeroLogin"
    
    private static func save(_ data: Data, for account: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func retrieve(account: String, service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess else { return nil }
        return dataTypeRef as? Data
    }

    private static func delete(account: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }

    static func save<T: Codable>(_ object: T, for account: String = account, service: String = service) -> Bool {
        do {
            let data = try JSONEncoder().encode(object)
            return save(data, for: account, service: service)
        } catch {
            print("Failed to encode object: \(error)")
            return false
        }
    }

    static func retrieve<T: Codable>(account: String = account, service: String = service, type: T.Type) -> T? {
        guard let data = retrieve(account: account, service: service) else { return nil }
        do {
            let object = try JSONDecoder().decode(T.self, from: data)
            return object
        } catch {
            print("Failed to decode object: \(error)")
            return nil
        }
    }
    
    static func saveVeroLoginData(email: String, password: String) -> Bool {
        
        let veroLoginData = VeroLoginData(email: email, password: password)
        let result = save(veroLoginData)
        
        return result
    }
}
