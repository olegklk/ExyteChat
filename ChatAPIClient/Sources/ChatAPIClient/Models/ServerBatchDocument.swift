import Foundation

public struct ServerBatchDocument: Codable, Identifiable, Sendable {
    public enum BatchType: String, Codable, Sendable {
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
    
    public init(from dict: [String: Any]) {
        self.id = (dict["_id"] as? String) ?? ""
        self.conversationId = (dict["conversationId"] as? String) ?? ""
        self.type = BatchType(rawValue: (dict["type"] as? String) ?? "direct") ?? .direct
        self.participants = (dict["participants"] as? [String]) ?? []
        self.startedAt = Self.parseDate(dict["startedAt"]) ?? Date()
        self.closedAt = Self.parseDate(dict["closedAt"])
        self.seenBy = (dict["seenBy"] as? [String]) ?? []
        if let msgs = dict["messages"] as? [[String: Any]] {
            self.messages = msgs.compactMap { ServerMessage(from: $0) }
        } else {
            self.messages = []
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.conversationId = try container.decode(String.self, forKey: .conversationId)
        let typeString = try container.decode(String.self, forKey: .type)
        self.type = BatchType(rawValue: typeString) ?? .direct
        self.participants = try container.decode([String].self, forKey: .participants)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        self.seenBy = try container.decode([String].self, forKey: .seenBy)
        self.messages = try container.decode([ServerMessage].self, forKey: .messages)
    }

    private static func parseDate(_ any: Any?) -> Date? {
        switch any {
        case let s as String:
            if let t = TimeInterval(s) { return Date(timeIntervalSince1970: t) }
            let isoFS = ISO8601DateFormatter()
            isoFS.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return isoFS.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        case let d as Double:
            return Date(timeIntervalSince1970: d)
        case let i as Int:
            return Date(timeIntervalSince1970: TimeInterval(i))
        default:
            return nil
        }
    }
}
