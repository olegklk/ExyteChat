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
    public static let selflProfileDidChange = Notification.Name("Store.selflProfileDidChange")
    private static var conversationsById: [String: Conversation] = [:]
//    private static var _activeConversationId: String?
    private static var _batchId: String?
    private static var _selfProfile: SelfProfile?
    private static var _contacts: [Contact] = []
    public static func setBatchId(_ id: String?) {
        _batchId = id
        NotificationCenter.default.post(name: Store.batchIdDidChange, object: nil)
    }
    
    public static func setSelfProfile(_ profile: SelfProfile) {
        _selfProfile = profile
        NotificationCenter.default.post(name: Store.selflProfileDidChange, object: nil)
    }
    
    public static func getSelfProfile() -> SelfProfile? {
        return _selfProfile
        
    }
    
    public static func ensureConversation(_ id: String) -> Conversation {
        
        var conversation = conversationsById[id]
        if conversation == nil {
            conversation = Conversation(id: id, title: id)
            if let userId = _selfProfile?.id {
                conversation!.participants = [userId]
            } else {
                conversation!.participants = []
            }
            upsertConversation(conversation!)
        }
        return conversation!
    }
    
    public static func createConversation(_ id: String, type: String, participants: [String]?, title: String?) -> Conversation {
        
        var allParticipants = participants
        if allParticipants != nil, let current = _selfProfile?.id, !allParticipants!.contains(current) {
                allParticipants!.append(current)
        }
        
        var conversation = Conversation(id: id, title: title ?? id)
        conversation.type = type
        if let allParticipants { conversation.participants = allParticipants }
        upsertConversation(conversation)
        return conversation
    }
    
    public static func conversation(for id: String) -> Conversation? {
        return conversationsById[id]
    }
    
    public static func upsertConversation(_ conversation: Conversation) {
        conversationsById[conversation.id] = conversation
    }
    
    public static func batchId() -> String? { _batchId }
    
    public static func userDisplayName() -> String {
        if let profile = _selfProfile {
            return "\(profile.firstName) \(profile.lastName)".trimmingCharacters(in: .whitespaces)
        }
        return "You"
    }
    
    static func setContacts(_ contacts: [Contact]) {
        _contacts = contacts
    }
    
    static func getContacts() -> [Contact] {
        _contacts
    }
        
}
