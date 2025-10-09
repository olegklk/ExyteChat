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

struct ConversationNavTarget: Identifiable, Hashable {
    let id: String
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
            
    func loadChatHistory() async { //we need this in case this user already has conversation with the same participants, so we need to fetch the latest batchId and use it further on
        guard isHistoryLoaded == false else {return}
        guard conversationId != nil else {return}
        
        isHistoryLoaded = true
        do {
            var batches = try await ChatAPIClient.shared.getHistory(conversationId: conversationId!, month: nil)
            if batches.isEmpty {
                self.finish()
            }
            else {
                batches = batches.sorted { $0.startedAt < $1.startedAt }
                if let lastBatch = batches.last, var conversation = self.conversation {
                    DispatchQueue.main.async {
                        conversation.batchId = lastBatch.id
                        conversation.type = (lastBatch.type).rawValue
                        conversation.participants = lastBatch.participants
                        Store.upsertConversation(conversation)
                        
                        self.finish()
                    }
                }
            }
        } catch {
            print("Failed to load chat history: \(error)")
            self.error = error
            finish()
            
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
            
            if isHistoryLoaded {
                finish()
            } else {
                Task {
                    await self.loadChatHistory()
                }
            }
            
        }
    }
    
    private func finish() {
        
        isLoading = false
        
        //let's end this socket connection to reconnect later with the proper batchId (that we fetched with loadHistory() if any)
        SocketIOManager.shared.disconnect()
        
        navigationTarget = ConversationNavTarget(id: conversationId!)
    }
    
    private func buildAuthData() -> [String: Any] {
        
        let auth: [String: Any] = [
            "chatType": chatType!,
            "participants": participants!,
            "userId": currentUserId
        ]
        
        return auth
    }
    
}

