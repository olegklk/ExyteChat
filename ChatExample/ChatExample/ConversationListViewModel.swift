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
            let items = try await ChatAPIClient.shared.getAllConversations(userId: Store.userId(), limit: nil, perConv: 1)
            
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
            let serverBatches = try await ChatAPIClient.shared.getHistory(conversationId: item.conversationId, month: nil)
            
            if let batch = serverBatches.first {
                
                var conversation = Store.ensureConversation(item.conversationId)
                
                conversation.type = (batch.type).rawValue
                conversation.participants = batch.participants
                conversation.messages = batch.messages
                
                Store.upsertConversation(conversation)
            }
            
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
