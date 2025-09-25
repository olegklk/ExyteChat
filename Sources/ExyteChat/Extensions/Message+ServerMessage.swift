//
//  Message+ServerMessage.swift
//  ExyteChat
//
//  Created by Developer on [Date].
//

import Foundation
import ChatAPIClient

extension Message {
    public func toServerMessage() -> ServerMessage {
        let sender = SenderRef(userId: user.id, displayName: user.name)
        
        let serverAttachments: [ServerAttachment] = attachments.compactMap { attachment in
            guard attachment.type == .image else { return nil }
            return ServerAttachment(
                kind: .image,
                url: attachment.full.absoluteString,
                href: nil,
                lat: nil,
                lng: nil,
                meta: nil
            )
        }
        
        return ServerMessage(
            id: id,
            sender: sender,
            text: text.isEmpty ? nil : text,
            attachments: serverAttachments,
            replyTo: replyMessage?.id,
            expiresAt: nil,
            createdAt: createdAt,
            editedAt: nil,
            deletedAt: nil
        )
    }
}
