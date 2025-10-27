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
    @Published var conversationURL: String?
    
    public var conversation: Conversation
    private var conversationId: String
        
    private var currentUserId: String { Store.getSelfProfile()?.id ?? "" }
    private var currentUserDisplayName: String { Store.userDisplayName() }
    
    private var isHistoryLoaded: Bool = false
    
    init(conversation: Conversation) {
        
        self.conversation = conversation
        self.conversationId = conversation.id
                
    }
    
    private func loadChatHistory() async {
        guard isHistoryLoaded == false else {return}
        
        isHistoryLoaded = true
        do {
            
            var batches = try await ChatAPIClient.shared.getHistory(conversationId: conversationId, month: nil) //current month by default
            
            conversation.clearMessages()
            
            batches = batches.sorted { $0.startedAt < $1.startedAt }
            if let lastBatch = batches.last {
                DispatchQueue.main.async {
                    self.conversation.batchId = lastBatch.id
                    self.conversationURL = self.conversation.url()
                    self.conversation.type = (lastBatch.type).rawValue
                    self.conversation.participants = lastBatch.participants
                }
            }
            
            // combine server messages from all batches into a single flat array
            let newMessages = batches.flatMap { $0.messages }
            
            await MainActor.run {
                self.updateMessages(newMessages)
            }
            
        } catch {
            print("Failed to load chat history: \(error)")
        }
    }
    
    private func updateMessages(_ serverMessages: [ServerMessage]) {
        
        conversation.mergeMessages(serverMessages)
        
        var msgs : [Message] = conversation.messages.map(self.convertServerMessageToChatMessage)
        
        // Re-init empty reply bodies
        for i in msgs.indices {
            if let reply = msgs[i].replyMessage, reply.text.isEmpty {
                msgs[i].replyMessage = self.makeReplyMessage(for: reply.id)
            }
        }
        self.messages = msgs
        
    }
    
    private func attachmentsFromDraft(_ draftMessage: DraftMessage) async -> [Attachment]? {
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
        guard let batchId = conversation.batchId else { return }
        
         let attachment = await attachmentsFromDraft(draft) ?? []
        
        let tempMessage = Message(
            id: draft.id ?? UUID().uuidString,
            user: User(id: currentUserId, name: currentUserDisplayName, avatarURL: nil, isCurrentUser: true),
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
        guard let batchId = conversation.batchId else { return }
        
        SocketIOManager.shared.editMessage(conversationId: conversationId, batchId: batchId, messageId: messageId, newText: newText)
    }

    func onAppear() {
        
        let msgs : [Message] = conversation.messages.map(self.convertServerMessageToChatMessage)
        self.messages = msgs
        
        self.conversationURL = self.conversation.url()
        
        setupSocketListeners()
        
        SocketIOManager.shared.setAuthData( participants: conversation.participants, chatType: conversation.type)
        SocketIOManager.shared.connect() // connection should trigger onConversationAssigned with conversationId
                
//        Task { await loadChatHistory() }
        
    }
    
    private func setupSocketListeners() {
        //sent after connection
        
        /////////////////////////////
        //onConversationAssigned should never happen, since it's not a new chat creation
        /////////////////////////////
        ///
//        SocketIOManager.shared.onConversationAssigned { [weak self] conversationId in
//            guard let self = self else { return }
//            
//            self.conversationId = conversationId
//            
//            conversationURL = conversation.url()
//                        
//            Task {
//                await self.loadChatHistory()
//            }
//        }
        
        SocketIOManager.shared.onBatchAssigned { [weak self] batchId, conversationId in
            guard let self = self else { return }
            guard self.conversationId == conversationId else { return }
            
            conversation.batchId = batchId
            
            conversationURL = conversation.url()
            
            Task {
                await self.loadChatHistory()
            }
        }
        
        // Listen for new messages
        SocketIOManager.shared.onMessageAppended { [weak self] serverMessage in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.updateMessages([serverMessage])
            }
        }
        
        SocketIOManager.shared.onUnreadBatches { [weak self] batches, cId in
            guard let self = self,
                  cId == self.conversationId else { return }
            let batches = batches.sorted { $0.startedAt < $1.startedAt }
            let lastBatchId = batches.last?.id
            let newMessages = batches.flatMap { $0.messages }
            
            DispatchQueue.main.async { [self] in
                if let lastBatchId {
                    self.conversation.batchId = lastBatchId
                    self.conversationURL = self.conversation.url()
                }
                if isHistoryLoaded {
                    self.updateMessages(newMessages)
                }
                else {
                    Task {
                        await self.loadChatHistory()
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
