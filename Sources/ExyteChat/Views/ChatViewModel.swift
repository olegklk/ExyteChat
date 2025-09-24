//
//  Created by Alex.M on 20.06.2022.
//

import Foundation
import Combine
import UIKit
import ChatAPIClient

@MainActor
final class ChatViewModel: ObservableObject {

    // Server-related properties
    @Published var serverMessages: [Message] = []
    @Published var isConnectedToServer = false
    @Published var connectionError: String?

    @Published private(set) var fullscreenAttachmentItem: Optional<Attachment> = nil
    @Published var fullscreenAttachmentPresented = false

    @Published var messageMenuRow: MessageRow?
    
    /// The messages frame that is currently being rendered in the Message Menu
    /// - Note: Used to further refine a messages frame (instead of using the cell boundary), mainly used for positioning reactions
    @Published var messageFrame: CGRect = .zero
    
    /// Provides a mechanism to issue haptic feedback to the user
    /// - Note: Used when launching the MessageMenu
    
    let inputFieldId = UUID()

    var didSendMessage: (DraftMessage) -> Void = {_ in}
    var inputViewModel: InputViewModel?
    var globalFocusState: GlobalFocusState?
    
    // Server integration callbacks
    var onServerMessageReceived: ((ServerMessage) -> Void)?
    var onServerMessageEdited: ((ServerMessage) -> Void)?
    var onServerMessageDeleted: ((String) -> Void)?

    func presentAttachmentFullScreen(_ attachment: Attachment) {
        fullscreenAttachmentItem = attachment
        fullscreenAttachmentPresented = true
    }
    
    func dismissAttachmentFullScreen() {
        fullscreenAttachmentPresented = false
        fullscreenAttachmentItem = nil
    }

    func sendMessage(_ message: DraftMessage) {
        didSendMessage(message)
    }

    // Server integration methods
    func sendServerMessage(conversationId: String, batchId: String, draft: DraftMessage) {
        // Convert draft attachments to server format
        let serverAttachments = draft.medias.compactMap { media -> [String: Any]? in
            switch media.type {
            case .image:
                return [
                    "kind": "image",
                    "url": "https://example.com/image.jpg" // In practice, upload media and get actual URL
                ]
            case .video:
                return [
                    "kind": "video",
                    "url": "https://example.com/video.mp4" // In practice, upload media and get actual URL
                ]
            default:
                return nil
            }
        }
        
        SocketIOManager.shared.sendMessage(
            conversationId: conversationId,
            batchId: batchId,
            text: draft.text.isEmpty ? nil : draft.text,
            attachments: serverAttachments.isEmpty ? nil : serverAttachments,
            replyTo: draft.replyMessage?.id
        )
    }
    
    func editServerMessage(conversationId: String, batchId: String, messageId: String, newText: String) {
        SocketIOManager.shared.editMessage(
            conversationId: conversationId,
            batchId: batchId,
            messageId: messageId,
            newText: newText
        )
    }
    
    func deleteServerMessage(conversationId: String, batchId: String, messageId: String) {
        SocketIOManager.shared.deleteMessage(
            conversationId: conversationId,
            batchId: batchId,
            messageId: messageId
        )
    }
    
    func markMessageAsSeen(conversationId: String, batchId: String, userId: String) {
        SocketIOManager.shared.markAsSeen(
            conversationId: conversationId,
            batchId: batchId,
            userId: userId
        )
    }
    
    // Message conversion methods
    func convertServerMessageToChatMessage(_ serverMessage: ServerMessage) -> Message {
        // Convert SenderRef to User
        let user = User(
            id: serverMessage.sender.userId,
            name: serverMessage.sender.displayName,
            avatarURL: nil,
            avatarCacheKey: nil,
            isCurrentUser: serverMessage.sender.userId == "current-user-id" // Adjust this condition based on your current user ID
        )
        
        // Convert ServerAttachment to Attachment
        let attachments = serverMessage.attachments.compactMap { serverAttachment -> Attachment? in
            guard let urlString = serverAttachment.url,
                  let url = URL(string: urlString) else {
                return nil
            }
            
            let type: AttachmentType
            switch serverAttachment.kind {
            case .image:
                type = .image
            case .video:
                type = .video
            case .gif:
                type = .image // Treat GIFs as images
            case .file:
                type = .image // Simplified for now
            case .location:
                type = .image // Simplified for now
            }
            
            return Attachment(
                id: UUID().uuidString,
                url: url,
                type: type
            )
        }
        
        return Message(
            id: serverMessage.id,
            user: user,
            status: serverMessage.deletedAt != nil ? nil : .sent,
            createdAt: serverMessage.createdAt,
            text: serverMessage.text ?? "",
            attachments: attachments,
            recording: nil, // Server integration would handle this conversion
            replyMessage: serverMessage.replyTo != nil ? ReplyMessage(
                id: serverMessage.replyTo!,
                user: User(id: "reply-user-id", name: "Reply User", avatarURL: nil, isCurrentUser: false),
                createdAt: Date(),
                text: "Reply text"
            ) : nil
        )
    }

    func messageMenuAction() -> (Message, DefaultMessageMenuAction) -> Void {
        { [weak self] message, action in
            self?.messageMenuActionInternal(message: message, action: action)
        }
    }

    func messageMenuActionInternal(message: Message, action: DefaultMessageMenuAction) {
        switch action {
        case .copy:
            UIPasteboard.general.string = message.text
        case .reply:
            inputViewModel?.attachments.replyMessage = message.toReplyMessage()
            globalFocusState?.focus = .uuid(inputFieldId)
        case .edit(let saveClosure):
            inputViewModel?.text = message.text
            inputViewModel?.edit(saveClosure)
            globalFocusState?.focus = .uuid(inputFieldId)
        }
    }
}
