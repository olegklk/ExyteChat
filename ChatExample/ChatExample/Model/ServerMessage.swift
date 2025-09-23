import Foundation
import ExyteChat

struct ServerMessage: Codable {
    let id: String
    let conversationId: String
    let batchId: String
    let sender: ServerSenderRef
    let text: String?
    let attachments: [ServerAttachment]?
    let replyTo: String?
    let expiresAt: Date?
    let createdAt: Date
    let editedAt: Date?
    let deletedAt: Date?
}

struct ServerSenderRef: Codable {
    let userId: String
    let displayName: String
}

struct ServerAttachment: Codable {
    let kind: String
    let url: String?
    let href: String?
    let lat: Double?
    let lng: Double?
    let meta: [String: Any]?
    
    func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["kind"] = kind
        if let url = url { dict["url"] = url }
        if let href = href { dict["href"] = href }
        if let lat = lat { dict["lat"] = lat }
        if let lng = lng { dict["lng"] = lng }
        if let meta = meta { dict["meta"] = meta }
        return dict
    }
}

struct ServerBatchDocument: Codable {
    let id: String // batchId
    let conversationId: String
    let type: String // direct, group, channel
    let participants: [String]
    let startedAt: Date
    let closedAt: Date?
    let seenBy: [String]
    let messages: [ServerMessage]
}

extension ServerMessage {
    init?(from dict: [String: Any]) {
        guard let id = dict["_id"] as? String,
              let conversationId = dict["conversationId"] as? String,
              let batchId = dict["batchId"] as? String,
              let senderDict = dict["sender"] as? [String: Any],
              let senderId = senderDict["userId"] as? String,
              let senderName = senderDict["displayName"] as? String,
              let createdAtString = dict["createdAt"] as? String,
              let createdAt = Date.iso8601Date.date(from: createdAtString) else {
            return nil
        }
        
        self.id = id
        self.conversationId = conversationId
        self.batchId = batchId
        self.sender = ServerSenderRef(userId: senderId, displayName: senderName)
        self.text = dict["text"] as? String
        self.replyTo = dict["replyTo"] as? String
        self.expiresAt = (dict["expiresAt"] as? String).flatMap { Date.iso8601Date.date(from: $0) }
        self.createdAt = createdAt
        self.editedAt = (dict["editedAt"] as? String).flatMap { Date.iso8601Date.date(from: $0) }
        self.deletedAt = (dict["deletedAt"] as? String).flatMap { Date.iso8601Date.date(from: $0) }
        
        if let attachmentsArray = dict["attachments"] as? [[String: Any]] {
            self.attachments = attachmentsArray.compactMap { ServerAttachment(from: $0) }
        } else {
            self.attachments = nil
        }
    }
}

extension ServerAttachment {
    init?(from dict: [String: Any]) {
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

extension ServerBatchDocument {
    init?(from dict: [String: Any]) {
        guard let id = dict["_id"] as? String,
              let conversationId = dict["conversationId"] as? String,
              let type = dict["type"] as? String,
              let participants = dict["participants"] as? [String],
              let startedAtString = dict["startedAt"] as? String,
              let startedAt = Date.iso8601Date.date(from: startedAtString) else {
            return nil
        }
        
        self.id = id
        self.conversationId = conversationId
        self.type = type
        self.participants = participants
        self.startedAt = startedAt
        self.closedAt = (dict["closedAt"] as? String).flatMap { Date.iso8601Date.date(from: $0) }
        self.seenBy = dict["seenBy"] as? [String] ?? []
        
        if let messagesArray = dict["messages"] as? [[String: Any]] {
            self.messages = messagesArray.compactMap { ServerMessage(from: $0) }
        } else {
            self.messages = []
        }
    }
}

// Conversion from server models to chat models
extension ServerSenderRef {
    func toChatUser(isCurrentUser: Bool) -> ExyteChat.User {
        ExyteChat.User(id: userId, name: displayName, avatarURL: nil, isCurrentUser: isCurrentUser)
    }
}

extension ServerAttachment {
    func toChatAttachment() -> ExyteChat.Attachment {
        let type: AttachmentType = kind == "image" ? .image : .video
        let url = URL(string: self.url ?? "") ?? URL(string: "https://example.com/placeholder.png")!
        return ExyteChat.Attachment(id: UUID().uuidString, url: url, type: type)
    }
}

extension ServerMessage {
    func toChatMessage(currentUserId: String) -> ExyteChat.Message {
        let user = sender.toChatUser(isCurrentUser: sender.userId == currentUserId)
        let attachments = self.attachments?.map { $0.toChatAttachment() } ?? []
        let replyMessage = self.replyTo != nil ? 
            ReplyMessage(id: self.replyTo ?? "", user: user, createdAt: createdAt) : nil
        
        return ExyteChat.Message(
            id: id,
            user: user,
            status: .sent, // Assume sent since it's from server
            createdAt: createdAt,
            text: text ?? "",
            attachments: attachments,
            replyMessage: replyMessage
        )
    }
}
