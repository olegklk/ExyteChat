//
//  ConversationListViewModel.swift
//  ChatExample
//
//  Created by Oleg Kolokolov on 30.09.2025.
//

import Foundation
import SwiftUI
import ExyteChat
import ExyteMediaPicker
import ChatAPIClient

@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var conversationItems: [ServerConversationListItem] = []
    @Published var isLoading = false
        
    func loadConversationList() async {
        
        do {
            isLoading = true
            let items = try await ChatAPIClient.shared.getAllConversations(limit: nil, perConv: 1)
            
            for item in items {
                await loadChatHistory(item)
            }
            self.conversationItems = items
            
            isLoading = false
            
        } catch {
            print("Failed to load conversation list: \(error)")
            isLoading = false
        }
    }
    
    func loadChatHistory(_ item: ServerConversationListItem) async {
        
        do {
            var batches = try await ChatAPIClient.shared.getHistory(conversationId: item.conversationId, month: nil)
            
            batches = batches.sorted { $0.startedAt < $1.startedAt }
            
            var conversation = Store.ensureConversation(item.conversationId)
            let nonEmptyParticipants = batches.reversed().first(where: { !$0.participants.isEmpty })?.participants ?? conversation.participants
            if let lastBatch = batches.last {
                conversation.batchId = lastBatch.id
                conversation.type = (lastBatch.type).rawValue
                conversation.participants = nonEmptyParticipants
            }
            
            let newMessages = batches.flatMap { $0.messages }
            
            conversation.mergeMessages(newMessages)
                
            Store.upsertConversation(conversation)

            
        } catch {
            print("Failed to load details(unread history) for chat:\(item.conversationId) error: \(error)")
            isLoading = false
        }
    }
        
    func onAppear() {
        Task {
            await loadConversationList()
        }
    }
        
}
