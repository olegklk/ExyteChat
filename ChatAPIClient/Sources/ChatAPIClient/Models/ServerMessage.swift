import Foundation

public struct ServerMessage: Codable, Hashable, Sendable {
    public let id: String
    public let sender: SenderRef
    public let text: String?
    public let attachments: [ServerAttachment]?
    public let replyTo: String?
    public let expiresAt: Date?
    public let createdAt: Date
    public let editedAt: Date?
    public let deletedAt: Date?
    
    public init(
        id: String,
        sender: SenderRef,
        text: String? = nil,
        attachments: [ServerAttachment]? = nil,
        replyTo: String? = nil,
        expiresAt: Date? = nil,
        createdAt: Date,
        editedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
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
              let userId = senderDict["userId"] as? String,
              let displayName = senderDict["displayName"] as? String,
              let createdAtStr = dict["createdAt"] as? String else {
            return nil
        }
        
        self.id = id
        self.sender = SenderRef(userId: userId, displayName: displayName)
        
        self.text = dict["text"] as? String
        
        if let attachmentsArray = dict["attachments"] as? [[String: Any]] {
            self.attachments = attachmentsArray.compactMap { ServerAttachment(from: $0) }
        } else {
            self.attachments = nil
        }
        
        self.replyTo = dict["replyTo"] as? String
        
        // Parse dates
        self.expiresAt = DateFormatter.iso8601.date(from: dict["expiresAt"] as? String ?? "")
        self.createdAt = DateFormatter.iso8601.date(from: createdAtStr) ?? Date()
        self.editedAt = DateFormatter.iso8601.date(from: dict["editedAt"] as? String ?? "")
        self.deletedAt = DateFormatter.iso8601.date(from: dict["deletedAt"] as? String ?? "")
    }
}

extension ServerAttachment {
    init?(from dict: [String: Any]) {
        guard let kindStr = dict["kind"] as? String else {
            return nil
        }
        
        self.kind = AttachmentKind(rawValue: kindStr) ?? .file
        self.url = dict["url"] as? String
        self.href = dict["href"] as? String
        self.lat = dict["lat"] as? Double
        self.lng = dict["lng"] as? Double
        self.meta = dict["meta"] as? [String: Any]
    }
}

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
