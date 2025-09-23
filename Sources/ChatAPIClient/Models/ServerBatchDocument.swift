import Foundation

public struct ServerBatchDocument: Codable, Identifiable {
    public enum BatchType: String, Codable {
        case direct
        case group
        case channel
    }
    
    public let id: String
    public let conversationId: String
    public let type: BatchType
    public let participants: [String]
    public let startedAt: Date
    public let closedAt: Date?
    public let seenBy: [String]
    public let messages: [ServerMessage]
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case conversationId
        case type
        case participants
        case startedAt
        case closedAt
        case seenBy
        case messages
    }
    
    public init(id: String,
                conversationId: String,
                type: BatchType,
                participants: [String],
                startedAt: Date,
                closedAt: Date?,
                seenBy: [String],
                messages: [ServerMessage]) {
        self.id = id
        self.conversationId = conversationId
        self.type = type
        self.participants = participants
        self.startedAt = startedAt
        self.closedAt = closedAt
        self.seenBy = seenBy
        self.messages = messages
    }
}
