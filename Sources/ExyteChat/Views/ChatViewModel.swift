//
//  Created by Alex.M on 20.06.2022.
//

import Foundation
import Combine
import UIKit

@MainActor
final class ChatViewModel: ObservableObject {

    // Add server-related properties
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

    // Add server integration methods
    func sendServerMessage(conversationId: String, batchId: String, draft: DraftMessage) {
        // Convert draft to server format and send via SocketIO
        // Note: This would require access to SocketIOManager which should be implemented in the project
        /*
        let attachments = draft.medias.compactMap { media -> ServerAttachment? in
            // Convert media to server attachment
            return nil // Implement conversion
        }
        
        SocketIOManager.shared.sendMessage(
            conversationId: conversationId,
            batchId: batchId,
            text: draft.text.isEmpty ? nil : draft.text,
            attachments: attachments,
            replyTo: draft.replyMessage?.id
        )
        */
    }
    
    func editServerMessage(conversationId: String, batchId: String, messageId: String, newText: String) {
        // Note: This would require access to SocketIOManager which should be implemented in the project
        /*
        SocketIOManager.shared.editMessage(
            conversationId: conversationId,
            batchId: batchId,
            messageId: messageId,
            newText: newText
        )
        */
    }
    
    func deleteServerMessage(conversationId: String, batchId: String, messageId: String) {
        // Note: This would require access to SocketIOManager which should be implemented in the project
        /*
        SocketIOManager.shared.deleteMessage(
            conversationId: conversationId,
            batchId: batchId,
            messageId: messageId
        )
        */
    }
    
    func markMessageAsSeen(conversationId: String, batchId: String, userId: String) {
        // Note: This would require access to SocketIOManager which should be implemented in the project
        /*
        SocketIOManager.shared.markAsSeen(
            conversationId: conversationId,
            batchId: batchId,
            userId: userId
        )
        */
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
