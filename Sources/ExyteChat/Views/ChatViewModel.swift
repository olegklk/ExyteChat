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
    private let defaults = UserDefaults.standard
    private let userIdKey = "UserSettings.userId"
    private let userNameKey = "UserSettings.userName"
    private var currentUserId: String { defaults.string(forKey: userIdKey) ?? "" }
    private var currentUserName: String { defaults.string(forKey: userNameKey) ?? "" }

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
    func sendServerMessage(conversationId: String, batchId: String, draft: DraftMessage) async {
        // Convert draft attachments to server format
        var serverAttachments: [ServerAttachment] = []
        for media in draft.medias {
            switch media.type {
            case .image:
                if let urlStr = await media.getURL()?.absoluteString {
                    serverAttachments.append(
                        ServerAttachment(
                            kind: .image,
                            url: urlStr,
                            href: nil,
                            lat: nil,
                            lng: nil,
                            meta: nil
                        )
                    )
                }
            default:
                break
            }
        }
        
        
        let serverMessage = ServerMessage(
            id: draft.id ?? UUID().uuidString,
            sender: SenderRef(userId: currentUserId, displayName: currentUserName),
            text: draft.text.isEmpty ? nil : draft.text,
            attachments: serverAttachments,
            replyTo: draft.replyMessage?.id,
            expiresAt: nil,
            createdAt: draft.createdAt,
            editedAt: nil,
            deletedAt: nil
        )
        
        SocketIOManager.shared.sendMessage(conversationId: conversationId, batchId: batchId, message: serverMessage)
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
        let userType: UserType = (serverMessage.sender.userId == currentUserId) ? .current : .other
        let user = User(
            id: serverMessage.sender.userId,
            name: serverMessage.sender.displayName,
            avatarURL: nil,
            type: userType
        )
        
        // Convert ServerAttachment to Attachment
        let attachments: [Attachment] = serverMessage.attachments.compactMap { sa in
            guard (sa.kind == .image || sa.kind == .gif),
                  let s = sa.url,
                  let url = URL(string: s) else { return nil }
            return Attachment(
                id: UUID().uuidString,
                thumbnail: url,
                full: url,
                type: .image,
                thumbnailCacheKey: nil,
                fullCacheKey: nil
            )
        }
        
        return Message(
            id: serverMessage.id,
            user: user,
            status: .sent,
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
