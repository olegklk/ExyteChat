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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.sender = try container.decode(SenderRef.self, forKey: .sender)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.attachments = try container.decode([ServerAttachment].self, forKey: .attachments)
        self.replyTo = try container.decodeIfPresent(String.self, forKey: .replyTo)
        self.expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt)
        self.deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sender, forKey: .sender)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encode(attachments, forKey: .attachments)
        try container.encodeIfPresent(replyTo, forKey: .replyTo)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(editedAt, forKey: .editedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
    
    public init?(from dict: [String: Any]) {
        guard let id = (dict["_id"] as? String) ?? (dict["messageId"] as? String) else { return nil }

        var senderRef: SenderRef?
        if let senderDict = dict["sender"] as? [String: Any] {
            senderRef = SenderRef(dict: senderDict)
        } else if let senderId = dict["senderId"] as? String {
            senderRef = SenderRef(userId: senderId, displayName: (dict["senderName"] as? String) ?? "")
        }
        guard let sender = senderRef else { return nil }

        guard let createdAt = Date.parseDate(dict["createdAt"]) else { return nil }

        self.id = id
        self.sender = sender
        self.text = dict["text"] as? String
        self.replyTo = dict["replyTo"] as? String
        self.expiresAt = Date.parseDate(dict["expiresAt"])
        self.createdAt = createdAt
        self.editedAt = Date.parseDate(dict["editedAt"])
        self.deletedAt = Date.parseDate(dict["deletedAt"])

        if let attachmentsArray = dict["attachments"] as? [[String: Any]] {
            self.attachments = attachmentsArray.compactMap { ServerAttachment(dict: $0) }
        } else {
            self.attachments = []
        }
    }
}

extension SenderRef {
    init?(dict: [String: Any]) {
        guard let userId = dict["userId"] as? String,
              let displayName = dict["displayName"] as? String else {
            return nil
        }

        self.init(userId: userId, displayName: displayName)
    }
}

public struct ServerReaction: Codable, Hashable, Sendable {
    public let id: String
    public let messageID: String
    public let content: String // Эмодзи или тип реакции
    public let createdAt: Date
    public let senderId: String
    public let senderName: String
    
    public init(id: String = UUID().uuidString,
                messageID: String,
                content: String,
                createdAt: Date = Date(),
                senderId: String,
                senderName: String) {
        self.id = id
        self.messageID = messageID
        self.content = content
        self.createdAt = createdAt
        self.senderId = senderId
        self.senderName = senderName
    }
    
    /// Создаёт ServerMessage для отправки на сервер
    public func toServerMessage() -> ServerMessage {
        let meta: [String: JSONValue] = [
            "id": .string(id),
            "type": .string(content),
            "createdAt": .string(ISO8601DateFormatter().string(from: createdAt)),
            "messageID": .string(messageID)
        ]
        
        let attachment = ServerAttachment(
            id: id,
            kind: .reaction,
            href: nil,
            lat: nil,
            lng: nil,
            meta: meta
        )
        
        return ServerMessage(
            id: UUID().uuidString,
            sender: SenderRef(userId: senderId, displayName: senderName),
            text: nil,
            attachments: [attachment],
            replyTo: messageID,
            expiresAt: nil,
            createdAt: createdAt,
            editedAt: nil,
            deletedAt: nil
        )
    }
    
    /// Извлекает ServerReaction из входящего ServerMessage
    public static func from(serverMessage: ServerMessage) -> ServerReaction? {
        // Реакция должна быть ответом (replyTo) и иметь аттачмент типа .reaction
        guard let replyTo = serverMessage.replyTo,
              let attachment = serverMessage.attachments.first(where: { $0.kind == .reaction }),
              let meta = attachment.meta else {
            return nil
        }
        
        // Извлекаем данные из meta
        guard let content = meta["type"]?.stringValue,
              let messageID = meta["messageID"]?.stringValue ?? Optional(replyTo)
        else { return nil }
        
        let id = meta["id"]?.stringValue ?? serverMessage.id
        
        // Пытаемся распарсить дату из meta, иначе берем дату сообщения
        var date = serverMessage.createdAt
        if let dateStr = meta["createdAt"]?.stringValue,
           let parsed = Date.parseDate(dateStr) {
            date = parsed
        }

        return ServerReaction(
            id: id,
            messageID: messageID,
            content: content,
            createdAt: date,
            senderId: serverMessage.sender.userId,
            senderName: serverMessage.sender.displayName
        )
    }
}

// Вспомогательное расширение для извлечения строки из JSONValue
fileprivate extension JSONValue {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}
