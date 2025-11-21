import Foundation

public struct ServerReaction: Codable, Hashable, Sendable {
    public let id: String
    public let type: String // "emoji" or "sticker"
    public let content: String // Emoji or URL string
    
    public init(id: String, type: String, content: String) {
        self.id = id
        self.type = type
        self.content = content
    }
    
    
    /// Creates ServerMessage for sending to the server
    public func toServerAttachment() -> ServerAttachment {
        let meta: [String: JSONValue] = [
            "type": .string(type),
            "content": .string(content)
        ]
        
        return ServerAttachment(
            id: id,
            kind: .reaction,
            href: nil,
            lat: nil,
            lng: nil,
            meta: meta
        )
                
    }
    
    /// Extracts ServerReaction from incoming ServerMessage
    public static func from(serverMessage: ServerMessage) -> ServerReaction? {
        // Reaction must be a reply (replyTo) and have an attachment of type .reaction
        guard let replyTo = serverMessage.replyTo,
              let attachment = serverMessage.attachments.first(where: { $0.kind == .reaction }),
              let meta = attachment.meta else {
            return nil
        }
        
        // Extract data from meta
        guard let type = meta["type"]?.anyValue as? String,
              let content = meta["content"]?.anyValue as? String
        else { return nil }
        
        let id = meta["id"]?.anyValue as? String ?? serverMessage.id
        var date = serverMessage.createdAt

        return ServerReaction(
            id: id,
            type: type,
            content: content
        )
    }
}
