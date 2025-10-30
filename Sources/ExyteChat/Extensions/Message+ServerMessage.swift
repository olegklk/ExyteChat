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
        
        let serverAttachments: [ServerAttachment] = attachments.map { attachment in
            // Если сервер поддерживает видео — замените .image на .file или нужный тип.
            let kind: ServerAttachment.AttachmentKind = .image
            
            return ServerAttachment(
                id: attachment.id,
                kind: kind,                
                href: nil,
                lat: nil,
                lng: nil,
                meta: makeMeta(from: attachment)
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
    
    private func makeMeta(from attachment: Attachment) -> [String: JSONValue]? {
        var components = DateComponents()
        components.day = 30
        let expiresAt = Calendar.current.date(byAdding: components, to: Date()) ?? Date()
        let expiresAtString = ISO8601DateFormatter().string(from: expiresAt)
        
        switch attachment.type {
        case .image:
            let imageObject: [String: JSONValue] = [
                "url": .string(attachment.full.absoluteString),
                "alt": .string(""),
                "expiresAt": .string(expiresAtString)
            ]
            return ["images": .array([.object(imageObject)])]
        case .video:
            
            return nil
        }
    }
}
