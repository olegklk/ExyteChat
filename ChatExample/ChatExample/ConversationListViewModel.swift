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
    @Published private var conversationItems: [ServerConversationListItem]?
        
    func loadConversationList() async {
        
        do {
            conversationItems = try await ChatAPIClient.shared.getConversations(userId: Store.userId(), limit: nil, perConv: nil)
            
        } catch {
            print("Failed to load conversation list: \(error)")
        }
    }
    
    func onAppear() {
        Task {
            await loadConversationList()
        }
    }
        
}
