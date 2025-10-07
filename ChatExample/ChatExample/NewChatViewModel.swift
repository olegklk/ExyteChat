//
//  NewChatViewModel.swift
//  ChatExample
//
//  Created by Oleg Kolokolov on 30.09.2025.
//

import Foundation
import ExyteChat
import ExyteMediaPicker
import ChatAPIClient


// Минимальный вариант только для успешного перехода
enum ChatDestination: Identifiable, Hashable {
    
    case chat(conversationId: String)
    
    var id: String { conversationId }
    
    private var conversationId: String {
        switch self {
        case .chat(let conversationId):
            return conversationId
        }
    }
}

@MainActor
class NewChatViewModel: ObservableObject {
    
    private var currentUserId: String { Store.userId() }
    private var conversation: Conversation?
    private var conversationId: String?
    private var chatType: String?
    private var participants: [String]?
    
    @Published var isLoading = false
    @Published var navigationTarget: ConversationNavTarget?
    @Published var error: Error?
    
    private var isHistoryLoaded: Bool = false
            
    func loadChatHistory() async {
        guard isHistoryLoaded == false else {return}
        guard conversationId != nil else {return}
        
        isHistoryLoaded = true
        do {
            let serverBatches = try await ChatAPIClient.shared.getHistory(conversationId: conversationId!, month: nil)
            
            if let batch = serverBatches.first {
                initConversation(batch: batch)
                
                
                isLoading = false
                navigationTarget = ConversationNavTarget(id: conversationId!)
                                
            }
            
        } catch {
            print("Failed to load chat history: \(error)")
            self.error = error
            isLoading = false
            
        }
    }
    
    func initConversation(batch: ServerBatchDocument) {
        if var conversation {
            conversation.type = (batch.type).rawValue
            conversation.participants = batch.participants
            conversation.startedAt = batch.startedAt
            
            Store.upsertConversation(conversation)
                        
        }
    }
    
    func start(chatType: String, participants: [String]) async {
        
        self.chatType = chatType
        self.participants = participants
        
        isLoading = true
        error = nil
        
        setupSocketListeners()
        SocketIOManager.shared.setAuthData(buildAuthData())
        SocketIOManager.shared.connect() // connection should trigger onConversationAssigned with conversationId
    }
    
    func setupSocketListeners() {
        //sent after connection
        SocketIOManager.shared.onConversationAssigned { [weak self] conversationId in
            guard let self = self else { return }
            
            self.conversationId = conversationId
            if self.conversation == nil {
                self.conversation = Store.createConversation(conversationId, type: chatType!, participants: participants, title: nil)
            }
                        
            
        }
        
        SocketIOManager.shared.onBatchAssigned { [weak self] batchId, conversationId in
            guard let self = self else { return }
            if let conversationId  {
                self.conversationId = conversationId
            }
            
            if self.conversation == nil {
                self.conversation = Store.createConversation(conversationId!, type: chatType!, participants: participants, title: nil)
                
            } else {
                self.conversation = Store.conversation(for: conversationId!)
            }
                        
            self.conversation?.batchId = batchId
            
            Task {
                await self.loadChatHistory()
            }
        }
    }
    
    private func buildAuthData() -> [String: Any] {
        
        var auth: [String: Any] = [
            "chatType": chatType!,
            "participants": participants!,
            "userId": currentUserId
        ]
        
        return auth
    }
    
}
