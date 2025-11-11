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

@MainActor
class NewChatViewModel: ObservableObject {
    
    private var currentUserId: String { Store.getSelfProfile()?.id ?? "" }
    private var conversation: Conversation?
    private var conversationId: String?
    private var chatType: String?
    private var participants: [String]?
    
    @Published var isLoading = false
    @Published var navigationItem: NavigationItem?
    @Published var error: Error?
    
    private var isHistoryLoaded: Bool = false
    private var hasStarted = false // Флаг для предотвращения повторного запуска

    // Идентификаторы для удаления слушателей сокета
    // Предполагается, что методы SocketIOManager.on... возвращают UUID или подобный идентификатор
    private var conversationAssignedHandlerId: UUID?
    private var batchAssignedHandlerId: UUID?
            
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
                    await MainActor.run {
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
        // Предотвращаем повторный запуск на том же экземпляре
        guard !hasStarted else { return }
        hasStarted = true
        
        self.chatType = chatType
        self.participants = participants
        
        isLoading = true
        error = nil
        
        setupSocketListeners()
        
        SocketIOManager.shared.setAuthData(participants: participants, chatType: chatType)
        SocketIOManager.shared.connect() // connection should trigger onConversationAssigned with conversationId
    }
    
    func setupSocketListeners() {
        // Сначала удаляем старые слушатели, если они есть
        removeSocketListeners()
        
        //sent after connection
        // Предполагается, что onConversationAssigned возвращает UUID
        conversationAssignedHandlerId = SocketIOManager.shared.onConversationAssigned { [weak self] conversationId in
            guard let self = self else { return }
            
            self.conversationId = conversationId
            if self.conversation == nil {
                self.conversation = Store.createConversation(conversationId, type: chatType!, participants: participants, title: nil)
            }
                        
            
        }
        
        //sent after connection
        // Предполагается, что onBatchAssigned возвращает UUID
        batchAssignedHandlerId = SocketIOManager.shared.onBatchAssigned { [weak self] batchId, conversationId in
            guard let self = self else { return }
            if let conversationId  {
                self.conversationId = conversationId
            }
            
            if self.conversation == nil {
                self.conversation = Store.createConversation(conversationId!, type: chatType!, participants: participants, title: nil)
                
            } else {
                self.conversation = Store.conversation(conversationId!)
            }
            
            self.conversation?.batchId = batchId
            Store.upsertConversation(self.conversation!)
            
            
            if isHistoryLoaded {
                self.finish()
            } else {
                Task {
                    await self.loadChatHistory()
                }
            }
            
        }
    }
    
    private func removeSocketListeners() {
        // ВНИМАНИЕ: Этот код предполагает, что у SocketIOManager есть методы
        // для удаления слушателей по их идентификатору, например:
        // SocketIOManager.shared.offConversationAssigned(handlerId)
        // Если API отличается, этот блок нужно адаптировать.
        
        if let handlerId = conversationAssignedHandlerId {
            // SocketIOManager.shared.offConversationAssigned(handlerId)
            conversationAssignedHandlerId = nil
        }
        
        if let handlerId = batchAssignedHandlerId {
            // SocketIOManager.shared.offBatchAssigned(handlerId)
            batchAssignedHandlerId = nil
        }
    }
    
    private func finish() {
        // Важно очищаем слушателей, чтобы они не "висели" в общем менеджере
        removeSocketListeners()
        
        isLoading = false
        isHistoryLoaded = false
        hasStarted = false // Сбрасываем флаг на случай переиспользования
        
        //let's end this socket connection to reconnect later with the proper batchId (that we fetched with loadHistory() if any)
        SocketIOManager.shared.disconnect()
        
        if let conversationId = self.conversationId {
            Task {
                let conversation = await Store.ensureConversation(conversationId)
                let navigationItem = NavigationItem(
                    screenType: .chat,
                    conversation: conversation)
                DispatchQueue.main.async { [self] in
                    self.navigationItem = navigationItem
                }
            }
        }
        
    }
    
    
    
}
