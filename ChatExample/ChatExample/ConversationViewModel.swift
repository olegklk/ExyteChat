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
        
    private var selfProfile: SelfProfile? { Store.getSelfProfile() }
    
    private var isHistoryLoaded: Bool = false
    
    init(conversation: Conversation) {
        
        self.conversation = conversation
        self.conversationId = conversation.id
                
    }
    
    private func loadChatHistory() async {
        guard isHistoryLoaded == false else {return}
        
        isHistoryLoaded = true
        switch await findNonEmptyMonthRecurcively(for:conversationId, month:0) {
            case .success(let batches):
                conversation.clearMessages()
                let batches = batches.sorted { $0.startedAt < $1.startedAt }
                if let lastBatch = batches.last {
                    DispatchQueue.main.async {
                        self.conversation.batchId = lastBatch.id
                        self.conversationURL = self.conversation.url()
                        self.conversation.type = (lastBatch.type).rawValue
                        if lastBatch.participants.count > 1 { self.conversation.participants = lastBatch.participants
                        }
                    }
                }
                
                // combine server messages from all batches into a single flat array
                let newMessages = batches.flatMap { $0.messages }
                
                await MainActor.run {
                    self.updateMessages(newMessages)
                }
                
            case .failure(let error):
                print("Couldn't find non-empty month history in all scannable periods. Error: \(error)")
                return
        }
                    
    }
    
    func findNonEmptyMonthRecurcively(for cId: String, month: Int) async -> Result<[ServerBatchDocument],Error>{
        
        //
        guard month < 12 else { //maximum scan for year ago
            return .failure(ConversationInitError.emptyConversation)
        }
        
        do {
            var batches = try await ChatAPIClient.shared.getHistory(conversationId: cId, month: Date.yyyyMM(monthsAgo: month))
                        
            if batches.isEmpty {
//                try await Task.sleep(until: .now + .seconds(2), clock: .suspending)
                return await findNonEmptyMonthRecurcively(for: cId, month: month+1)
            }
            
//            let conversation = await Store.ensureConversation(cId)
            
            return .success(batches)
        } catch {
            return .failure(ConversationInitError.generalError)
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
    
    //returns list of failed attachment IDs
    private func uploadAttachmentsFromDraft(_ draftMessage: DraftMessage) async -> [String] {
        var result: [String] = []
        
        for media in draftMessage.medias {
            
            switch media.type {
                case .image:
                    switch await UploadingManager.uploadImageMedia(media) {
                        case .success(let url):
                            break
                        case .failure(let error):
                            print("Image upload failed: \(error)")
                            result.append(media.id.uuidString)
                    }
                case .video:
                    switch await UploadingManager.uploadVideoMedia(media) {
                        case .success(let pair):
                            break
                        case .failure(let error):
                            print("Video upload failed: \(error)")
                            result.append(media.id.uuidString)
                    }
                    
            }
        }
            
        return result
    }
        
    private func attachmentsFromDraft(_ draftMessage: DraftMessage) async -> [Attachment]? {
        var result: [Attachment] = []
        
        for media in draftMessage.medias {
            
            if let fullURL = await media.getURL()  {
                let thumbURL = await media.getThumbnailURL() ?? fullURL
                
                result.append(
                    Attachment(
                        id: media.id.uuidString,
                        thumbnail: thumbURL,
                        full: fullURL,
                        type: media.type == .video ? AttachmentType.video : AttachmentType.image,
                        status: .uploading
                    )
                )
            }
        }
        
        return result
    }
        
    func handleSend(_ draft: DraftMessage) async {
        
        var draft = draft
        
        if  draft.id == nil {
            draft.id = UUID().uuidString
        }
        
        guard let batchId = conversation.batchId else { return }
        
        guard let selfProfile = selfProfile else { return }
        
        let attachments = await attachmentsFromDraft(draft) ?? []
        
        let tempMessage = Message(
            id: draft.id!,
            user: User(id: selfProfile.id, name: Store.selfDisplayName(), avatarURL: selfProfile.picture != nil ? URL(string:selfProfile.picture!) : nil, isCurrentUser: true),
            status: .sending,
            createdAt: draft.createdAt,
            text: draft.text,
            attachments: attachments,
            recording: draft.recording,
            replyMessage: draft.replyMessage
        )
        if let index = self.messages.firstIndex(where: { $0.id == draft.id! }) {
            self.messages[index] = tempMessage
        } else {
            self.messages.append(tempMessage)
        }
        
        let failedAttachments = await uploadAttachmentsFromDraft(draft)
        let hasFailed = failedAttachments.count > 0
        
        if !hasFailed { //all attachments uploaded successfully
            let serverMessage = tempMessage.toServerMessage()
            SocketIOManager.shared.sendMessage(conversationId: conversationId, batchId: batchId, message: serverMessage)
        } else {
            
            var updatedAttachments = attachments
            for i in updatedAttachments.indices {
                if failedAttachments.contains(where: { $0 == updatedAttachments[i].id }) {
                    updatedAttachments[i].status = .failed
                } else {
                    updatedAttachments[i].status = .uploaded
                }
            }
            
            let failedMessage = Message(
                id: draft.id!,
                user: User(id: selfProfile.id, name: Store.selfDisplayName(), avatarURL: selfProfile.picture != nil ? URL(string:selfProfile.picture!) : nil, isCurrentUser: true),
                status: .error(draft),
                createdAt: draft.createdAt,
                text: draft.text,
                attachments: updatedAttachments,
                recording: draft.recording,
                replyMessage: draft.replyMessage
            )
            
            if let index = self.messages.firstIndex(where: { $0.id == draft.id! }) {
                self.messages[index] = failedMessage
            }
        }
    }
    
    func handleEdit(_ messageId: String, _ newText: String) {
        guard let batchId = conversation.batchId else { return }
        
        SocketIOManager.shared.editMessage(conversationId: conversationId, batchId: batchId, messageId: messageId, newText: newText)
    }
    
    func handleDelete(_ message: Message) {
        guard let batchId = conversation.batchId else { return }
        
        SocketIOManager.shared.deleteMessage(conversationId: conversationId, batchId: batchId, messageId: message.id)
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
        var user = User(
            id: serverMessage.sender.userId,
            name: serverMessage.sender.displayName,
            avatarURL: nil,
            type: .other,
        )
        
        if let selfProfile = selfProfile {
            if serverMessage.sender.userId == selfProfile.id {
                user = User(
                    id: selfProfile.id,
                    name: Store.selfDisplayName(),
                    avatarURL: selfProfile.picture != nil ? URL(string:selfProfile.picture!) : nil,
                    type: .current)
            }
        }
        
        
        // Convert ServerAttachment to Attachment
        let attachments: [Attachment] = serverMessage.attachments.compactMap { sa in
            guard let url = sa.url, let urlObj = URL(string: url) else { return nil }
            return Attachment(
                id: UUID().uuidString,
                thumbnail: urlObj,
                full: urlObj,
                type: .image,
                status: .uploaded,
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

