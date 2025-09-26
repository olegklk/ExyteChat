//
//  APIClientExampleView.swift
//  ChatExample
//
//  Created by [Your Name] on [Date].
//

import SwiftUI
import ExyteChat
import ExyteMediaPicker
import ChatAPIClient

struct APIClientExampleView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) private var presentationMode
    
    @StateObject private var viewModel: APIClientExampleViewModel
    
    private let title: String
    
    init(viewModel: APIClientExampleViewModel, title: String) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.title = title
    }
    
    var body: some View {
        ChatView(
            messages: viewModel.messages,
            didSendMessage: { draft in
                Task { await viewModel.handleSend(draft) }
            }
        )
        .keyboardDismissMode(.interactive)
//        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    if let url = viewModel.chatCover {
                        CachedAsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Rectangle().fill(Color(hex: "AFB3B8"))
                            }
                        }
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(viewModel.chatTitle)
                            .fontWeight(.semibold)
                            .font(.headline)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                        Text(viewModel.chatStatus)
                            .font(.footnote)
                            .foregroundColor(Color(hex: "AFB3B8"))
                    }
                    Spacer()
                }
                .padding(.leading, 10)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

@MainActor
class APIClientExampleViewModel: ObservableObject {
    @Published var messages: [Message] = []
    
    @Published var chatTitle: String = ""
    @Published var chatStatus: String = ""
    @Published var chatCover: URL?
    
    private var conversationId: String? //"81bdd94b-c8d7-47a5-ad24-ce58e0a7f533"
    private var batchId: String? //"6cbd16b1-5302-4f47-aa19-829ae19ab6bc"
    private var currentUserId: String { defaults.string(forKey: userIdKey) ?? "" }
    private var currentUserName: String { defaults.string(forKey: userNameKey) ?? "" }
    private let defaults = UserDefaults.standard
    private let conversationIdKey = "APIClientExample.conversationId"
    private let batchIdKey = "APIClientExample.batchId"
    private let userIdKey = "UserSettings.userId"
    private let userNameKey = "UserSettings.userName"
    
    func loadChatHistory() async {
        guard let conversationId = conversationId else { return }
        
        do {
            let serverBatches = try await ChatAPIClient.shared.getHistory(conversationId: conversationId)
            
            // Convert server messages to chat messages and sort by createdAt
            let newMessages = serverBatches
                .flatMap { $0.messages.map(self.convertServerMessageToChatMessage) }
                .sorted { $0.createdAt < $1.createdAt }
            
            await MainActor.run {
                self.messages = newMessages
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
        guard let conversationId = conversationId, let batchId = batchId else { return }
        
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

    func onAppear() {
        setupSocketListeners()
        loadPersistedIds()
        SocketIOManager.shared.setAuthData(buildAuthData())
        SocketIOManager.shared.connect() // connection should trigger onConversationAssigned with conversationId
        
        
//        Task { await loadChatHistory() }
//        Task {
//            do {
//                try await ChatAPIClient.shared.openBatch(
//                    type: .direct,
//                    batchId: batchId,
//                    participants: [currentUserId, "other-user-id"],
//                    conversationId: conversationId
//                )
//            } catch {
//                print("Failed to open batch: \(error)")
//            }
//        }
        
        
    }
    
    func setupSocketListeners() {
        //sent after connection
        SocketIOManager.shared.onConversationAssigned { [weak self] conversationId in
            guard let self = self else { return }
            self.conversationId = conversationId
            self.persistConversationId(conversationId)
            Task {
                await self.loadChatHistory()
            }
        }
        
        SocketIOManager.shared.onBatchAssigned { [weak self] batchId, conversationId in
            guard let self = self else { return }
            self.conversationId = conversationId
            self.batchId = batchId
            self.persistConversationId(conversationId)
            self.persistBatchId(batchId)
            Task {
                await self.loadChatHistory()
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
            replyMessage: serverMessage.replyTo != nil ? ReplyMessage(
                id: serverMessage.replyTo!,
                user: User(id: "reply-user-id", name: "Reply User", avatarURL: nil, isCurrentUser: false),
                createdAt: Date(),
                text: "Reply text"
            ) : nil
        )
    }

    private func loadPersistedIds() {
        self.conversationId = defaults.string(forKey: conversationIdKey)
        //uncomment the following only when the batches are persisted so no need to load previous ones, until then all th ebatches will be refreshed as new
//        self.batchId = defaults.string(forKey: batchIdKey)
    }

    private func persistConversationId(_ id: String?) {
        if let id { defaults.set(id, forKey: conversationIdKey) } else { defaults.removeObject(forKey: conversationIdKey) }
    }

    private func persistBatchId(_ id: String?) {
        if let id { defaults.set(id, forKey: batchIdKey) } else { defaults.removeObject(forKey: batchIdKey) }
    }

    private func buildAuthData() -> [String: Any] {
        var auth: [String: Any] = [
            "chatType": "direct",
            "participants": [currentUserId, "u_98b2efd3"],
            "userId": currentUserId
        ]
        if let conversationId { auth["conversationId"] = conversationId }
        if let batchId { auth["batchId"] = batchId }
        return auth
    }

    func setConversationId(_ id: String?) {
        self.conversationId = id
        persistConversationId(id)
    }

    func setBatchId(_ id: String?) {
        self.batchId = id
        persistBatchId(id)
    }
}

struct APIClientExampleView_Previews: PreviewProvider {
    static var previews: some View {
        APIClientExampleView(viewModel: APIClientExampleViewModel(), title: "Gramatune chat (demo)")
    }
}
