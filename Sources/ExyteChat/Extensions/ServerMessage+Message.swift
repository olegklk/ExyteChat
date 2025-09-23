//
//  ServerMessage+Message.swift
//  ExyteChat
//
//  Created by Developer on [Date].
//

import Foundation

extension ServerMessage {
    public func toMessage(currentUserId: String?) -> Message {
        let userType: UserType = (sender.userId == currentUserId) ? .current : .other
        let user = User(
            id: sender.userId,
            name: sender.displayName,
            avatarURL: nil,
            type: userType
        )
        
        // Convert attachments
        let chatAttachments = attachments.compactMap { attachment -> Attachment? in
            guard let url = attachment.url, let urlObj = URL(string: url) else { return nil }
            
            switch attachment.kind {
            case "image":
                return Attachment(id: UUID().uuidString, url: urlObj, type: .image)
            case "video":
                return Attachment(id: UUID().uuidString, url: urlObj, type: .video)
            default:
                return nil
            }
        }
        
        // Create reply message if needed
        var replyMessage: ReplyMessage? = nil
        if let replyToId = replyTo, !replyToId.isEmpty {
            replyMessage = ReplyMessage(
                id: replyToId,
                user: user,
                createdAt: createdAt,
                text: text ?? ""
            )
        }
        
        return Message(
            id: id,
            user: user,
            status: .sent, // Server messages are considered sent
            createdAt: createdAt,
            text: text ?? "",
            attachments: chatAttachments,
            reactions: [],
            replyMessage: replyMessage
        )
    }
}
