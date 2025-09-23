import Foundation

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
    
    // Helper method to convert to dictionary for Socket.IO
    func toDict() -> [String: Any] {
        var dict: [String: Any] = ["kind": kind]
        if let url = url { dict["url"] = url }
        if let href = href { dict["href"] = href }
        if let lat = lat { dict["lat"] = lat }
        if let lng = lng { dict["lng"] = lng }
        if let meta = meta { dict["meta"] = meta }
        return dict
    }
}
