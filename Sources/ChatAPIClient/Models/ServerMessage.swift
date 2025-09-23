import Foundation

public struct ServerMessage: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let sender: SenderRef
    public let text: String?
    public let attachments: [ServerAttachment]
    public let replyTo: String?
    public let expiresAt: Date?
    public let createdAt: Date
    public let editedAt: Date?
    public let deletedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case sender
        case text
        case attachments
        case replyTo
        case expiresAt
        case createdAt
        case editedAt
        case deletedAt
    }
    
    public init(id: String,
                sender: SenderRef,
                text: String?,
                attachments: [ServerAttachment],
                replyTo: String?,
                expiresAt: Date?,
                createdAt: Date,
                editedAt: Date?,
                deletedAt: Date?) {
        self.id = id
        self.sender = sender
        self.text = text
        self.attachments = attachments
        self.replyTo = replyTo
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.deletedAt = deletedAt
    }
    
    public init?(from dict: [String: Any]) {
        guard let id = dict["_id"] as? String,
              let senderDict = dict["sender"] as? [String: Any],
              let sender = SenderRef(from: senderDict),
              let createdAtTimestamp = dict["createdAt"] as? TimeInterval else {
            return nil
        }
        
        self.id = id
        self.sender = sender
        self.text = dict["text"] as? String
        self.replyTo = dict["replyTo"] as? String
        self.expiresAt = (dict["expiresAt"] as? TimeInterval).flatMap { Date(timeIntervalSince1970: $0) }
        self.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        self.editedAt = (dict["editedAt"] as? TimeInterval).flatMap { Date(timeIntervalSince1970: $0) }
        self.deletedAt = (dict["deletedAt"] as? TimeInterval).flatMap { Date(timeIntervalSince1970: $0) }
        
        if let attachmentsArray = dict["attachments"] as? [[String: Any]] {
            self.attachments = attachmentsArray.compactMap { ServerAttachment(from: $0) }
        } else {
            self.attachments = []
        }
    }
}

extension SenderRef {
    init?(from dict: [String: Any]) {
        guard let userId = dict["userId"] as? String,
              let displayName = dict["displayName"] as? String else {
            return nil
        }
        
        self.init(userId: userId, displayName: displayName)
    }
}

extension ServerAttachment {
    init?(from dict: [String: Any]) {
        guard let kind = dict["kind"] as? String else {
            return nil
        }
        
        self.init(
            kind: kind,
            url: dict["url"] as? String,
            href: dict["href"] as? String,
            lat: dict["lat"] as? Double,
            lng: dict["lng"] as? Double,
            meta: dict["meta"] as? [String: Any]
        )
    }
}
