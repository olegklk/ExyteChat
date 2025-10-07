//
//  Store.swift
//  ChatExample
//
//  Created by Oleg Kolokolov on 30.09.2025.
//

import Foundation
import ChatAPIClient

@MainActor
public final class Store {
    
    public static let conversationIdDidChange = Notification.Name("Store.conversationIdDidChange")
    public static let batchIdDidChange = Notification.Name("Store.batchIdDidChange")
    private static var conversationsById: [String: Conversation] = [:]
//    private static var _activeConversationId: String?
    private static var _batchId: String?
    public static func setBatchId(_ id: String?) {
        _batchId = id
        NotificationCenter.default.post(name: Store.batchIdDidChange, object: nil)
    }
    
    public static func ensureConversation(_ id: String) -> Conversation {
        
        var conversation = conversationsById[id]
        if conversation == nil {
            conversation = Conversation(id: id, title: "")
            conversation!.participants = [userId()]
            upsertConversation(conversation!)
        }
        return conversation!
    }
    
    public static func createConversation(_ id: String, type: String, participants: [String]?, title: String?) -> Conversation {
        
        var allParticipants = participants
        if allParticipants != nil {
            let current = userId()
            if !allParticipants!.contains(current) {
                allParticipants!.append(current)
            }
        }
        
        var conversation = Conversation(id: id, title: title ?? String(id.prefix(8)))
        conversation.type = type
        if let allParticipants { conversation.participants = allParticipants }
        upsertConversation(conversation)
        return conversation
    }
    
    public static func conversation(for id: String) -> Conversation? {
        return conversationsById[id]!
    }
    
    public static func upsertConversation(_ conversation: Conversation) {
        conversationsById[conversation.id] = conversation
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
        
}
