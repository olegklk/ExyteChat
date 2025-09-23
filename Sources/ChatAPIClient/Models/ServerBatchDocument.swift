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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.conversationId = try container.decode(String.self, forKey: .conversationId)
        self.type = try container.decode(BatchType.self, forKey: .type)
        self.participants = try container.decode([String].self, forKey: .participants)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        self.seenBy = try container.decode([String].self, forKey: .seenBy)
        self.messages = try container.decode([ServerMessage].self, forKey: .messages)
    }
    
    public init?(from dict: [String: Any]) {
        guard let id = dict["_id"] as? String,
              let conversationId = dict["conversationId"] as? String,
              let typeString = dict["type"] as? String,
              let type = BatchType(rawValue: typeString),
              let participantIds = dict["participants"] as? [String],
              let startedAtTimestamp = dict["startedAt"] as? TimeInterval else {
            return nil
        }
        
        self.id = id
        self.conversationId = conversationId
        self.type = type
        self.participants = participantIds
        self.startedAt = Date(timeIntervalSince1970: startedAtTimestamp)
        self.closedAt = (dict["closedAt"] as? TimeInterval).flatMap { Date(timeIntervalSince1970: $0) }
        self.seenBy = dict["seenBy"] as? [String] ?? []
        
        if let messagesArray = dict["messages"] as? [[String: Any]] {
            self.messages = messagesArray.compactMap { ServerMessage(from: $0) }
        } else {
            self.messages = []
        }
    }
}
