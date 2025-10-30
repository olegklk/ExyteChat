//
//  ServerMessage+Message.swift
//  ExyteChat
//
//  Created by Developer on [Date].
//

import Foundation
import ChatAPIClient

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
            case .image, .gif:
                return Attachment(
                    id: UUID().uuidString,
                    thumbnail: urlObj,
                    full: urlObj,
                    type: .image,
                    status: .uploaded,
                    thumbnailCacheKey: nil,
                    fullCacheKey: nil
                )
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
            status: .sent,
            createdAt: createdAt,
            text: text ?? "",
            attachments: chatAttachments,
            recording: nil,
            replyMessage: replyMessage
        )
    }
}
