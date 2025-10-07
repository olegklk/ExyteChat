import Foundation

public struct ServerConversationListItem: Codable, Hashable, Sendable {
    public let conversationId: String
    public let batchIds: [String]
    public let totalBatches: Int
    public let unreadCount: Int
    public let latestStartedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case conversationId
        case batchIds
        case totalBatches
        case unreadCount
        case latestStartedAt
    }
    
    public init(conversationId: String,
                batchIds: [String],
                totalBatches: Int,
                unreadCount: Int,
                latestStartedAt: Date
    ) {
        self.conversationId = conversationId
        self.batchIds = batchIds
        self.totalBatches = totalBatches
        self.unreadCount = unreadCount
        self.latestStartedAt = latestStartedAt
    }
    
    public init(from dict: [String: Any]) {
        self.conversationId = (dict["conversationId"] as? String) ?? ""
        if let batches = dict["batchIds"] as? [String] {
            self.batchIds = batches
        } else {
            self.batchIds = []
        }
        self.totalBatches = (dict["totalBatches"] as? Int) ?? 0
        self.unreadCount = (dict["unreadCount"] as? Int) ?? 0
        self.latestStartedAt = JSONValue.parseDate(dict["latestStartedAt"]) ?? Date()
        
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.conversationId = try container.decode(String.self, forKey: .conversationId)
        self.batchIds = try container.decode([String].self, forKey: .batchIds)
        self.totalBatches = try container.decode(Int.self, forKey: .totalBatches)
        self.unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        self.latestStartedAt = try container.decode(Date.self, forKey: .latestStartedAt)
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
