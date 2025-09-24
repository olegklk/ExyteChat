//
//  APIClientExampleView.swift
//  ChatExample
//
//  Created by [Your Name] on [Date].
//

import SwiftUI
import ExyteChat
import ChatAPIClient

struct APIClientExampleView: View {
    @StateObject private var viewModel = APIClientExampleViewModel()
    
    var body: some View {
        ChatView(
            messages: viewModel.messages,
            didSendMessage: viewModel.handleSend
        )
        .onAppear {
            viewModel.onAppear()
        }
        .chatTheme(accentColor: .blue)
    }
}

@MainActor
class APIClientExampleViewModel: ObservableObject {
    @Published var messages: [Message] = []
    private var conversationId = "example-conversation-id"
    private var batchId = "example-batch-id"
    private let currentUserId = "current-user-id"
    private let currentUserName = "Current User"
    
    func loadChatHistory() async {
        do {
            // Fetch chat history using ChatAPIClient
            let serverBatches = try await ChatAPIClient.shared.getHistory(conversationId: conversationId)
            
            // Convert server messages to chat messages
            let newMessages = serverBatches.flatMap { batch in
                batch.messages.map { serverMessage in
                    self.convertServerMessageToChatMessage(serverMessage)
                }
            }
            
            await MainActor.run {
                self.messages = newMessages
            }
        } catch {
            print("Failed to load chat history: \(error)")
        }
    }
    
    func handleSend(_ draft: DraftMessage) {
        let tempMessage = Message(
            id: draft.id ?? UUID().uuidString,
            user: User(id: currentUserId, name: currentUserName, avatarURL: nil, isCurrentUser: true),
            status: .sending,
            createdAt: draft.createdAt,
            text: draft.text,
            attachments: [],
            recording: draft.recording,
            replyMessage: draft.replyMessage
        )
        self.messages.append(tempMessage)

        SocketIOManager.shared.sendMessage(
            conversationId: conversationId,
            batchId: batchId,
            senderId: currentUserId,
            senderName: currentUserName,
            text: draft.text.isEmpty ? nil : draft.text,
            attachments: [],
            replyTo: draft.replyMessage?.id
        )
    }

    func onAppear() {
        setupSocketListeners()
        SocketIOManager.shared.connect(
            conversationId: conversationId,
            batchId: batchId,
            userId: currentUserId,
            userName: currentUserName
        )
        Task { await loadChatHistory() }
        Task {
            do {
                try await ChatAPIClient.shared.openBatch(
                    type: .direct,
                    batchId: batchId,
                    participants: [currentUserId, "other-user-id"],
                    conversationId: conversationId
                )
            } catch {
                print("Failed to open batch: \(error)")
            }
        }
    }
    
    func setupSocketListeners() {
        // Listen for new messages
        SocketIOManager.shared.onMessageAppended { [weak self] serverMessage in
            guard let self = self else { return }
            let chatMessage = self.convertServerMessageToChatMessage(serverMessage)
            DispatchQueue.main.async {
                self.messages.removeAll { $0.id == serverMessage.id }
                self.messages.append(chatMessage)
            }
        }

        // Listen for edited messages
        SocketIOManager.shared.onMessageEdited { [weak self] messageId, newText in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                    var msg = self.messages[idx]
                    msg.text = newText ?? msg.text
                    self.messages[idx] = msg
                }
            }
        }
        
        // Listen for deleted messages
        SocketIOManager.shared.onMessageDeleted { [weak self] messageId in
            DispatchQueue.main.async {
                self?.messages.removeAll { $0.id == messageId }
            }
        }
    }
    
    private func convertServerMessageToChatMessage(_ serverMessage: ServerMessage) -> Message {
        // Convert SenderRef to User
        let user = User(
            id: serverMessage.sender.userId,
            name: serverMessage.sender.displayName,
            avatarURL: nil,
            isCurrentUser: serverMessage.sender.userId == "current-user-id"
        )
        
        // Convert ServerAttachment to Attachment
        let attachments: [Attachment] = serverMessage.attachments.compactMap { sa in
            guard sa.kind == .image, let s = sa.url, let url = URL(string: s) else { return nil }
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
            recording: nil, // In a real implementation, you would convert recordings
            replyMessage: serverMessage.replyTo != nil ? ReplyMessage(
                id: serverMessage.replyTo!,
                user: User(id: "reply-user-id", name: "Reply User", avatarURL: nil, isCurrentUser: false),
                createdAt: Date(),
                text: "Reply text"
            ) : nil
        )
    }
}

struct APIClientExampleView_Previews: PreviewProvider {
    static var previews: some View {
        APIClientExampleView()
    }
}
