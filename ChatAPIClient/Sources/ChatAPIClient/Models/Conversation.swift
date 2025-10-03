import Foundation

public struct Conversation: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var type: String = "direct" //direct or group
    public var participants: [String] = []
    public var unreadCount: Int = 0
    public var messages: [ServerMessage] = []
    
    
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case type
        case participants
        case unreadCount
        case messages
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
        self.type = try container.decode(String.self, forKey: .type)
        self.participants = try container.decode([String].self, forKey: .participants)
        self.unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        self.messages = try container.decode([ServerMessage].self, forKey: .messages)
        
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(participants, forKey: .participants)
        try container.encode(messages, forKey: .messages)        
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
