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
    //давай доработаем этот класс так чтобы каждый раз когда ему присваивают свойство participants (и только если количество элементов в participants >1) инициализировалось свойство title следующим образом: если type == "direct", то title присваивается имя второго участника чата (назодим его id в массиве participants, отличающееся от нвшего (Store.getSelfProfile) и затем получаем параметры Contact из Store.getContact(id) находем его firstName + LastName AI!
    public mutating func clearMessages() {
        self.messages.removeAll()
    }
    
    public mutating func setMessages(_ messages: [ServerMessage]) {
        self.messages = messages.sorted { $0.createdAt < $1.createdAt }
    }
    
    public mutating func mergeMessages(_ messages: [ServerMessage]) {
        var byId = Dictionary(uniqueKeysWithValues: self.messages.map { ($0.id, $0) })
        for m in messages {
            byId[m.id] = m // insert new or replace existing
        }
        self.messages = byId.values.sorted { $0.createdAt < $1.createdAt }
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
