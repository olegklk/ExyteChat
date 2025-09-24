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
            didSendMessage: viewModel.send
        ) { draft in
            // Handle message sending through ChatAPIClient
            viewModel.sendServerMessage(draft)
        }
        .onAppear {
            // Load chat history when view appears
            Task {
                await viewModel.loadChatHistory()
            }
            
            // Set up Socket.IO listeners
            viewModel.setupSocketListeners()
        }
        .chatTheme(accentColor: .blue)
    }
}

class APIClientExampleViewModel: ObservableObject {
    @Published var messages: [Message] = []
    private var conversationId = "example-conversation-id"
    private var batchId = "example-batch-id"
    
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
    
    func send(_ draft: DraftMessage) {
        // Add message to UI immediately
        let tempMessage = Message(
            id: draft.id ?? UUID().uuidString,
            user: User(id: "current-user-id", name: "Current User", avatarURL: nil, isCurrentUser: true),
            status: .sending,
            createdAt: draft.createdAt,
            text: draft.text,
            attachments: [],
            recording: draft.recording,
            replyMessage: draft.replyMessage
        )
        
        self.messages.append(tempMessage)
    }
    
    func sendServerMessage(_ draft: DraftMessage) {
        // Send message through Socket.IO
        SocketIOManager.shared.sendMessage(
            conversationId: conversationId,
            batchId: batchId,
            text: draft.text.isEmpty ? nil : draft.text,
            attachments: nil, // In a real implementation, you would convert attachments
            replyTo: draft.replyMessage?.id
        )
    }
    
    func setupSocketListeners() {
        // Listen for new messages
        SocketIOManager.shared.onMessageAppended { [weak self] serverMessage in
            guard let self = self else { return }
            let chatMessage = self.convertServerMessageToChatMessage(serverMessage)
            
            DispatchQueue.main.async {
                // Remove any temporary messages with the same ID
                self.messages.removeAll { $0.id == serverMessage.id }
                // Add the confirmed message
                self.messages.append(chatMessage)
            }
        }
        
        // Listen for edited messages
        SocketIOManager.shared.onMessageEdited { [weak self] serverMessage in
            guard let self = self else { return }
            let chatMessage = self.convertServerMessageToChatMessage(serverMessage)
            
            DispatchQueue.main.async {
                if let index = self.messages.firstIndex(where: { $0.id == serverMessage.id }) {
                    self.messages[index] = chatMessage
                }
            }
        }
        
        // Listen for deleted messages
        SocketIOManager.shared.onMessageDeleted { [weak self] messageId in
            DispatchQueue.main.async {
                self?.messages.removeAll { $0.id == messageId }
            }
        }
        
        // Open a batch for this conversation
        Task {
            do {
                try await ChatAPIClient.shared.openBatch(
                    type: "direct",
                    batchId: batchId,
                    participants: ["current-user-id", "other-user-id"]
                )
            } catch {
                print("Failed to open batch: \(error)")
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
        let attachments = serverMessage.attachments.map { serverAttachment in
            // In a real implementation, you would properly convert attachments
            Attachment(
                id: UUID().uuidString,
                url: URL(string: serverAttachment.url ?? "https://example.com/placeholder.jpg")!,
                type: .image
            )
        }
        
        return Message(
            id: serverMessage.id,
            user: user,
            status: serverMessage.deletedAt != nil ? nil : .sent,
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
