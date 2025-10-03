import Foundation

public struct Conversation: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var preview: String?
    public var unreadCount: Int = 0
    public var last: TimeInterval = 0
    public var messages: [ServerMessage] = []
    public var seenBy: [String] = []
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case preview
        case unreadCount
        case last
        case messages
        case seenBy
    }
    
    public init(id: String,
                title: String) {
        self.id = id
        self.title = title
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.preview = try container.decodeIfPresent(String.self, forKey: .preview)
        self.unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        self.last = try container.decode(TimeInterval.self, forKey: .last)
        self.messages = try container.decode([ServerMessage].self, forKey: .messages)
        self.seenBy = try container.decode([String].self, forKey: .seenBy)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(preview, forKey: .preview)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(last, forKey: .last)
        try container.encode(messages, forKey: .messages)
        try container.encode(seenBy, forKey: .seenBy)
    }
        
}

extension Conversation {
    public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
