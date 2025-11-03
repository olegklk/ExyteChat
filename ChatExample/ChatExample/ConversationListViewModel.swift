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

enum ConversationInitError: Error {
    case generalError
    case notEnoughParticipants
    case emptyConversation
    
    var errorDescription: String? {
            switch self {
            case .generalError:
                return "Unknown error"
            case .notEnoughParticipants:
                return "There should be at least 2 participants in a chat"
            case .emptyConversation:
                return "There is no data for the given month"
            }
        }
}

@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var conversationItems: [ServerConversationListItem] = []
    @Published var isLoading = false
        
    func loadConversationList() async {
        
        do {
            isLoading = true
            let items = try await ChatAPIClient.shared.getAllConversations(limit: nil, perConv: 1)
            
            for item in items {
                await populateConversation(item)
            }
            self.conversationItems = items
            
            isLoading = false
            
        } catch {
            print("Failed to load conversation list: \(error)")
            isLoading = false
        }
    }
    
    func populateConversation(_ item: ServerConversationListItem) async {
                
        switch await findNonEmptyBatchRecurcively(for:item, month:0) {
            case .success(let (batch,participants)):
                var conversation = Store.ensureConversation(item.conversationId)
                if let batch = batch {
                    conversation.batchId = batch.id
                    conversation.type = (batch.type).rawValue
                    conversation.participants = participants
                }
                
                let newMessages = batch.flatMap { $0.messages }
                
                conversation.mergeMessages(newMessages ?? [])
                    
                Store.upsertConversation(conversation)
                
            case .failure(let error):
                print("Couldn't find non-empty month history in all scannable periods. Error: \(error)")
                return
        }
            
        
        
    }
    
    func findNonEmptyBatchRecurcively(for c: ServerConversationListItem, month: Int) async -> Result<(batch:ServerBatchDocument?,participants:[String]),Error>{
        
        guard month < 24 else {
            return .failure(ConversationInitError.emptyConversation)
        }
        
        do {
            var batches = try await ChatAPIClient.shared.getHistory(conversationId: c.conversationId, month: Date.yyyyMM(monthsAgo: month))
                        
            if batches.isEmpty {
//                try await Task.sleep(until: .now + .seconds(2), clock: .suspending)
                return await findNonEmptyBatchRecurcively(for: c, month: month+1)
            }
            
            batches = batches.sorted { $0.startedAt > $1.startedAt }
            
            let conversation = Store.ensureConversation(c.conversationId)
            let batch = batches.first(where: { !$0.participants.isEmpty })
            
            let nonEmptyParticipants = batch?.participants ?? conversation.participants
            
            guard nonEmptyParticipants.count > 1 else  {
                return .failure(ConversationInitError.notEnoughParticipants)
            }
            
            return .success((batch: batch, participants: nonEmptyParticipants))
        } catch {
            return .failure(ConversationInitError.generalError)
        }
    }
        
    func onAppear() {
        Task {
            await loadConversationList()
        }
    }
        
}
