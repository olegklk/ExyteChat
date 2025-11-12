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
    
    public static func conversation(_ id: String) -> Conversation? {
        return conversationsById[id]
    }
    
    public static func ensureConversation(_ id: String) async -> Conversation {
        
        var conversation = conversationsById[id]
        if conversation == nil {
            conversation = Conversation(id: id, title: nil)
            if let userId = _selfProfile?.id {
                conversation!.participants = [userId]
            } else {
                conversation!.participants = []
            }
            upsertConversation(conversation!)
        }
        conversation!.coverURL = makeConversationCoverURL(conversation!)
        
        conversation!.title = await makeConversationTitle(conversation!)
        
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
    
    public static func upsertConversation(_ conversation: Conversation) {
        conversationsById[conversation.id] = conversation
    }
    
    public static func batchId() -> String? { _batchId }
    
    public static func selfDisplayName() -> String {
        if let profile = _selfProfile {
            return displayName(fName: profile.firstName, lName: profile.lastName)
        }
        return "You"
    }
    
    // helper to render full name
    public static func displayName(fName: String, lName: String?) -> String {
        "\(fName) \(lName ?? "")".trimmingCharacters(in: .whitespaces)
    }
    
    static func setContacts(_ contacts: [Contact]) {
        _contacts = contacts
    }
    
    static func getContacts() -> [Contact] {
        _contacts
    }
    
    static func getContact(_ id: String) -> Contact? {
        return _contacts.first(where: { $0.id == id })
    }
    
    static func fetchRemoteContact(_ id: String) async -> Contact? {
        
        guard let token = KeychainHelper.standard.read(service: .token, type: CompleteLoginResponse.self)?.veroPass?.jwt else {
            return nil
        }

        if let profiles = await VeroAPIManager.shared.getProfiles(forIDs: [id], accessToken: token),
           let p = profiles.first {
            let newContact = Contact(id: id, username: p.username, firstname: p.firstName, lastname: p.lastName, picture: p.picture)
                _contacts.append(newContact)
                return newContact
        }
        return nil
    }
        
    static func makeConversationTitle(_ c: Conversation) async -> String {
        var title = c.title
        if c.type == "direct", c.participants.count > 1, let myProfile = _selfProfile {
            if let userId = c.participants.first(where: {$0 != myProfile.id}) {
                if let user = getContact(userId) {
                    title = displayName(fName: user.firstname, lName: user.lastname)
                } else {
                    if let user = await fetchRemoteContact(userId) {
                        title = displayName(fName: user.firstname, lName: user.lastname)
                    }
                }
            }
        } else if c.participants.count > 2, let myProfile = _selfProfile { //group or channel
            if let userId = c.participants.first(where: {$0 != myProfile.id}) {//переделай этот блок так чтобы для каждого участника чата кроме меня самого его имя (созданное через displayName() добавлялось через запятую в title AI!
                if let user = getContact(userId) {
                    title = displayName(fName: user.firstname, lName: user.lastname)
                } else {
                    if let user = await fetchRemoteContact(userId) {
                        title = displayName(fName: user.firstname, lName: user.lastname)
                    }
                }
            }
        }
        return title ?? c.id
    }
    
    static func makeConversationCoverURL(_ c: Conversation) -> URL? {
        var coverURL = c.coverURL
        if c.type == "direct", c.participants.count > 1, let myProfile = _selfProfile {
            if let userId = c.participants.first(where: {$0 != myProfile.id}),
             let user = getContact(userId) {
                if let picture = user.picture {
                    coverURL = URL(string: picture)
                }
            }
        }
        return coverURL
    }
}
