import Foundation

public struct SenderRef: Codable {
    public let userId: String
    public let displayName: String
    
    public init(userId: String, displayName: String) {
        self.userId = userId
        self.displayName = displayName
    }
}

public struct ServerAttachment: Codable {
    public let kind: String
    public let url: String?
    public let href: String?
    public let lat: Double?
    public let lng: Double?
    public let meta: [String: Any]?
    
    public init(kind: String, url: String?, href: String?, lat: Double?, lng: Double?, meta: [String: Any]?) {
        self.kind = kind
        self.url = url
        self.href = href
        self.lat = lat
        self.lng = lng
        self.meta = meta
    }
    
    public func toDict() -> [String: Any] {
        var dict: [String: Any] = ["kind": kind]
        if let url = url { dict["url"] = url }
        if let href = href { dict["href"] = href }
        if let lat = lat { dict["lat"] = lat }
        if let lng = lng { dict["lng"] = lng }
        if let meta = meta { dict["meta"] = meta }
        return dict
    }
}

public struct ServerMessage: Codable, Identifiable {
    public let id: String
    public let sender: SenderRef
    public let text: String?
    public let attachments: [ServerAttachment]
    public let replyTo: String?
    public let createdAt: Date
    public let editedAt: Date?
    public let deletedAt: Date?
    
    public init(id: String, sender: SenderRef, text: String?, attachments: [ServerAttachment], replyTo: String?, createdAt: Date, editedAt: Date?, deletedAt: Date?) {
        self.id = id
        self.sender = sender
        self.text = text
        self.attachments = attachments
        self.replyTo = replyTo
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.deletedAt = deletedAt
    }
}

public struct ServerBatchDocument: Codable {
    public let id: String
    public let conversationId: String
    public let type: String
    public let participants: [String]
    public let startedAt: Date
    public let closedAt: Date?
    public let seenBy: [String]
    public let messages: [ServerMessage]
    
    public init(id: String, conversationId: String, type: String, participants: [String], startedAt: Date, closedAt: Date?, seenBy: [String], messages: [ServerMessage]) {
        self.id = id
        self.conversationId = conversationId
        self.type = type
        self.participants = participants
        self.startedAt = startedAt
        self.closedAt = closedAt
        self.seenBy = seenBy
        self.messages = messages
    }
}

// Extension for creating ServerMessage from dictionary
extension ServerMessage {
    public init?(from dict: [String: Any]) {
        guard let id = dict["_id"] as? String,
              let senderDict = dict["sender"] as? [String: Any],
              let senderUserId = senderDict["userId"] as? String,
              let senderDisplayName = senderDict["displayName"] as? String,
              let createdAtString = dict["createdAt"] as? String else {
            return nil
        }
        
        self.id = id
        self.sender = SenderRef(userId: senderUserId, displayName: senderDisplayName)
        self.text = dict["text"] as? String
        self.replyTo = dict["replyTo"] as? String
        
        // Parse dates
        let formatter = ISO8601DateFormatter()
        self.createdAt = formatter.date(from: createdAtString) ?? Date()
        self.editedAt = dict["editedAt"] as? String.flatMap { formatter.date(from: $0) }
        self.deletedAt = dict["deletedAt"] as? String.flatMap { formatter.date(from: $0) }
        
        // Parse attachments
        self.attachments = (dict["attachments"] as? [[String: Any]])?.compactMap { ServerAttachment(from: $0) } ?? []
    }
}

// Extension for creating ServerAttachment from dictionary
extension ServerAttachment {
    public init?(from dict: [String: Any]) {
        guard let kind = dict["kind"] as? String else {
            return nil
        }
        
        self.kind = kind
        self.url = dict["url"] as? String
        self.href = dict["href"] as? String
        self.lat = dict["lat"] as? Double
        self.lng = dict["lng"] as? Double
        self.meta = dict["meta"] as? [String: Any]
    }
}

// Extension for creating ServerBatchDocument from dictionary
extension ServerBatchDocument {
    public init?(from dict: [String: Any]) {
        guard let id = dict["_id"] as? String,
              let conversationId = dict["conversationId"] as? String,
              let type = dict["type"] as? String,
              let participants = dict["participants"] as? [String],
              let startedAtString = dict["startedAt"] as? String,
              let messagesDict = dict["messages"] as? [[String: Any]] else {
            return nil
        }
        
        self.id = id
        self.conversationId = conversationId
        self.type = type
        self.participants = participants
        
        // Parse dates
        let formatter = ISO8601DateFormatter()
        self.startedAt = formatter.date(from: startedAtString) ?? Date()
        self.closedAt = dict["closedAt"] as? String.flatMap { formatter.date(from: $0) }
        
        // Parse seenBy
        self.seenBy = dict["seenBy"] as? [String] ?? []
        
        // Parse messages
        self.messages = messagesDict.compactMap { ServerMessage(from: $0) }
    }
}
