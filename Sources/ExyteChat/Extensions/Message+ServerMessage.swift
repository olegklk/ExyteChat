//
//  Message+ServerMessage.swift
//  ExyteChat
//
//  Created by Developer on [Date].
//

import Foundation

extension Message {
    public func toServerMessage(conversationId: String, batchId: String) -> ServerMessage {
        let sender = ServerUser(id: user.id, displayName: user.name)
        
        let serverAttachments = attachments.map { attachment -> ServerAttachment in
            // This is a simplified conversion - in practice you'd need the actual server URLs
            return ServerAttachment(
                kind: attachment.type == .image ? "image" : "video",
                url: attachment.full.absoluteString
            )
        }
        
        return ServerMessage(
            id: id,
            conversationId: conversationId,
            batchId: batchId,
            sender: sender,
            text: text.isEmpty ? nil : text,
            attachments: serverAttachments,
            replyTo: replyMessage?.id,
            createdAt: createdAt
        )
    }
}
