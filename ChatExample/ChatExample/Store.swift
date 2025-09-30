//
//  Store.swift
//  ChatExample
//
//  Created by Oleg Kolokolov on 30.09.2025.
//

import Foundation

@MainActor
public final class Store {
    public static let conversationIdDidChange = Notification.Name("Store.conversationIdDidChange")
    public static let batchIdDidChange = Notification.Name("Store.batchIdDidChange")
    private static var _batchId: String?
    public static func setBatchId(_ id: String?) {
        _batchId = id
        NotificationCenter.default.post(name: Store.batchIdDidChange, object: nil)
    }
    
    public static func persistConversationId(_ id: String?) {
        let defaults = UserDefaults.standard
        if let id { defaults.set(id, forKey: AppKeys.UserDefaults.conversationId) } else { defaults.removeObject(forKey: AppKeys.UserDefaults.conversationId) }
        NotificationCenter.default.post(name: Store.conversationIdDidChange, object: nil)
    }
    
    public static func batchId() -> String? { _batchId }
    
    public static func persistUserId(_ id: String?) {
        let defaults = UserDefaults.standard
        if let id { defaults.set(id, forKey: AppKeys.UserDefaults.userId) } else { defaults.removeObject(forKey: AppKeys.UserDefaults.userId) }
    }
    
    public static func persistUserName(_ name: String?) {
        let defaults = UserDefaults.standard
        if let name { defaults.set(name, forKey: AppKeys.UserDefaults.userName) } else { defaults.removeObject(forKey: AppKeys.UserDefaults.userName) }
    }
    
    public static func userName() -> String {
        return UserDefaults.standard.string(forKey: AppKeys.UserDefaults.userName) ?? ""
    }
    
    public static func userId() -> String {
        if let savedId = UserDefaults.standard.string(forKey: AppKeys.UserDefaults.userId) {
            return savedId
        }
        
        let newId = ChatUtils.generateRandomUserId()
        persistUserId(newId)
        return newId
    }
    
    public static func conversationId() -> String {
        if let savedId = UserDefaults.standard.string(forKey: AppKeys.UserDefaults.conversationId) {
            return savedId
        }
        
        let newId = ChatUtils.generateRandomConversationId()
        persistConversationId(newId)
        return newId
    }
    
    public static func conversationURL() -> String {
        let convId = conversationId()
        if let batchId = _batchId {
            //https://chat.gramatune.com/#conversation=07DDC757-797C-4A1F-BB82-0268BB078231&batch=f9f45e7a-8a44-477d-9b89-e972cc210a94
            return "https://chat.gramatune.com/#conversation=\(convId)&batch=\(batchId)"
        }
        
        return "http://"
    }
        
}
