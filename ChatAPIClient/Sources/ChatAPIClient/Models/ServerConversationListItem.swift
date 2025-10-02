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
