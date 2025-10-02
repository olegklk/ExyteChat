import Foundation

public struct ServerConversationListItem: Codable, Hashable, Sendable {
    public let conversationId: String
    public let unreadBatchIds: [String]
    public let unreadCount: Int
    public let latestUnreadStartedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case conversationId
        case unreadBatchIds
        case unreadCount
        case latestUnreadStartedAt
    }
    
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.conversationId = try container.decode(String.self, forKey: .conversationId)
        self.unreadBatchIds = try container.decode([String].self, forKey: .unreadBatchIds)
        self.unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        self.latestUnreadStartedAt = try container.decode(Date.self, forKey: .latestUnreadStartedAt)
    }
        
}

extension ServerConversationListItem {
    public static func == (lhs: ServerConversationListItem, rhs: ServerConversationListItem) -> Bool {
        lhs.conversationId == rhs.conversationId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(conversationId)
    }
}
