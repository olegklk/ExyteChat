import Foundation

public struct ServerConversationListItem: Codable, Hashable, Sendable {
    public let conversationId: String
    public let unreadBatchIds: [String]
    public let unreadCount: Int
    public let latestUnreadStartedAt: Date
    
    public init(conversationId: String,
                unreadBatchIds: [String],
                unreadCount: Int,
                latestUnreadStartedAt: Date
    ) {
        self.conversationId = conversationId
        self.unreadBatchIds = unreadBatchIds
        self.unreadCount = unreadCount
        self.latestUnreadStartedAt = latestUnreadStartedAt
    }
    
    public init(from dict: [String: Any]) {
        self.conversationId = (dict["conversationId"] as? String) ?? ""
        if let batches = dict["unreadBatchIds"] as? [String] {
            self.unreadBatchIds = batches
        } else {
            self.unreadBatchIds = []
        }
        self.unreadCount = (dict["unreadCount"] as? Int) ?? 0
        self.latestUnreadStartedAt = JSONValue.parseDate(dict["latestUnreadStartedAt"]) ?? Date()
        
    }
}
import Foundation

public struct ServerConversationListItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var preview: String?
    public var unreadCount: Int = 0
    public var last: TimeInterval = 0
    public var seenBy: [String] = []
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case preview
        case unreadCount
        case last
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
        self.seenBy = try container.decode([String].self, forKey: .seenBy)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(preview, forKey: .preview)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(last, forKey: .last)
        try container.encode(seenBy, forKey: .seenBy)
    }
    
    public init(from dict: [String: Any]) {
        self.id = dict["_id"] as? String ?? ""
        self.title = dict["title"] as? String ?? ""
        self.preview = dict["preview"] as? String
        self.unreadCount = dict["unreadCount"] as? Int ?? 0
        self.last = dict["last"] as? TimeInterval ?? 0
        self.seenBy = dict["seenBy"] as? [String] ?? []
    }
}

extension ServerConversationListItem {
    public static func == (lhs: ServerConversationListItem, rhs: ServerConversationListItem) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
