//
//  ConversationViewModel.swift
//  ChatExample
//
//  Created by Oleg Kolokolov on 30.09.2025.
//

import Foundation
import ExyteChat
import ExyteMediaPicker
import ChatAPIClient

@MainActor
class ConversationViewModel: ObservableObject {
    @Published var messages: [Message] = []
    
    @Published var chatTitle: String = ""
    @Published var chatStatus: String = ""
    @Published var chatCover: URL?
    
    private var conversationId: String 
    private var batchId: String?
    private var currentUserId: String { Store.userId() }
    private var currentUserName: String { Store.userName() }
    
    private var isHistoryLoaded: Bool = false
    
    init(conversationId: String) {
        self.conversationId = conversationId
    }
    
    func loadChatHistory() async {
        
        do {
            let serverBatches = try await ChatAPIClient.shared.getHistory(conversationId: conversationId, month: nil) //current month by default
            
            // Convert server messages to chat messages and sort by createdAt
            let newMessages = serverBatches
                .flatMap { $0.messages.map(self.convertServerMessageToChatMessage) }
                .sorted { $0.createdAt < $1.createdAt }
            
            await MainActor.run {
                self.messages = newMessages
                // Re-init empty reply bodies
                for i in self.messages.indices {
                    if let reply = self.messages[i].replyMessage, reply.text.isEmpty {
                        self.messages[i].replyMessage = self.makeReplyMessage(for: reply.id)
                    }
                }
            }
        } catch {
            print("Failed to load chat history: \(error)")
        }
    }
    
    func attachmentsFromDraft(_ draftMessage: DraftMessage) async -> [Attachment]? {
        var result: [Attachment] = []
        for media in draftMessage.medias where media.type == .image {
            let thumb = await media.getThumbnailURL()
            let full = await media.getURL()
            if let thumb, let full {
                result.append(
                    Attachment(
                        id: media.id.uuidString,
                        thumbnail: thumb,
                        full: full,
                        type: .image
                    )
                )
            }
        }
        return result.isEmpty ? nil : result
    }
    
    func handleSend(_ draft: DraftMessage) async {
        guard let batchId = batchId else { return }
        
         let attachment = await attachmentsFromDraft(draft) ?? []
        
        let tempMessage = Message(
            id: draft.id ?? UUID().uuidString,
            user: User(id: currentUserId, name: currentUserName, avatarURL: nil, isCurrentUser: true),
            status: .sending,
            createdAt: draft.createdAt,
            text: draft.text,
            attachments: attachment,
            recording: draft.recording,
            replyMessage: draft.replyMessage
        )
        self.messages.append(tempMessage)

        let serverMessage = tempMessage.toServerMessage()
        SocketIOManager.shared.sendMessage(conversationId: conversationId, batchId: batchId, message: serverMessage)
    }
    
    func handleEdit(_ messageId: String, _ newText: String) {
        guard let batchId = batchId else { return }
        
        SocketIOManager.shared.editMessage(conversationId: conversationId, batchId: batchId, messageId: messageId, newText: newText)
    }

    func onAppear() {
        setupSocketListeners()
        SocketIOManager.shared.setAuthData(buildAuthData())
        SocketIOManager.shared.connect() // connection should trigger onConversationAssigned with conversationId
                
//        Task { await loadChatHistory() }
        
    }
    
    func setupSocketListeners() {
        //sent after connection
        SocketIOManager.shared.onConversationAssigned { [weak self] conversationId in
            guard let self = self else { return }
            self.conversationId = conversationId
            Store.setActiveConversationId(conversationId)
            if !isHistoryLoaded {
                Task {
                    await self.loadChatHistory()
                }
            }
        }
        
        SocketIOManager.shared.onBatchAssigned { [weak self] batchId, conversationId in
            guard let self = self else { return }
            if let conversationId  {
                self.conversationId = conversationId
            }
            self.batchId = batchId
            Store.setActiveConversationId(conversationId)
            Store.setBatchId(batchId)
            if !isHistoryLoaded {
                Task {
                    await self.loadChatHistory()
                }
            }
        }
        
        // Listen for new messages
        SocketIOManager.shared.onMessageAppended { [weak self] serverMessage in
            guard let self = self else { return }
            let chatMessage = self.convertServerMessageToChatMessage(serverMessage)
            DispatchQueue.main.async {
                self.messages.removeAll { $0.id == serverMessage.id }
                self.messages.append(chatMessage)
            }
        }
        
        SocketIOManager.shared.onUnreadBatches { [weak self] batches, cId in
            guard let self = self,
            cId == self.conversationId else { return }
            
            let newMessages = batches
                .flatMap { $0.messages.map(self.convertServerMessageToChatMessage) }
            
            Task { @MainActor in
                // merge newMessages into messages, replacing items with the same id
                for msg in newMessages {
                    if let idx = self.messages.firstIndex(where: { $0.id == msg.id }) {
                        self.messages[idx] = msg
                    } else {
                        self.messages.append(msg)
                    }
                }
                
                self.messages.sort { $0.createdAt < $1.createdAt }
                
                // Re-init empty reply bodies
                for i in self.messages.indices {
                    if let reply = self.messages[i].replyMessage, reply.text.isEmpty {
                        self.messages[i].replyMessage = self.makeReplyMessage(for: reply.id)
                    }
                }
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
            isCurrentUser: serverMessage.sender.userId == currentUserId
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
            replyMessage: makeReplyMessage(for: serverMessage.replyTo)
        )
    }

    private func buildAuthData() -> [String: Any] {
        var auth: [String: Any] = [
            "chatType": "group",
            "participants": [currentUserId],
            "userId": currentUserId
        ]
        auth["conversationId"] = conversationId
        if let batchId { auth["batchId"] = batchId }
        return auth
    }

    private func makeReplyMessage(for replyTo: String?) -> ReplyMessage? {
        guard let replyId = replyTo else { return nil }
        guard let ref = messages.first(where: { $0.id == replyId }) else {
            return ReplyMessage(
                id: replyTo!,
                user: User(id: "reply-user-id", name: "Reply User", avatarURL: nil, isCurrentUser: false),
                createdAt: Date(),
                text: ""
            )
        }
        return ref.toReplyMessage()
    }
}
