import Foundation

public struct Conversation: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var coverURL: URL?
    public var batchId: String?
    public var type: String?  //direct or group
    public var participants: [String]
    public var unreadCount: Int = 0
    public var messages: [ServerMessage] = []
    
    
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case coverURL
        case type
        case participants
        case unreadCount
        case messages
        case batchId
    }
    
    public init(id: String,
                title: String) {
        self.id = id
        self.title = title
        self.participants = []
    }
    
    public mutating func setMessages(_ messages: [ServerMessage]) {
        self.messages = messages
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.coverURL = try container.decodeIfPresent(URL.self, forKey: .coverURL)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.participants = try container.decode([String].self, forKey: .participants)
        self.unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        self.messages = try container.decode([ServerMessage].self, forKey: .messages)
        self.batchId = try container.decode(String.self, forKey: .batchId)
        
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(coverURL, forKey: .coverURL)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(participants, forKey: .participants)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(batchId, forKey: .batchId)
    }
    
    public func url() -> String {
        
        if let batchId = batchId {
            return "https://chat.gramatune.com/#conversation=\(id)&batch=\(batchId)"
        }
        
        return "http://"
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
