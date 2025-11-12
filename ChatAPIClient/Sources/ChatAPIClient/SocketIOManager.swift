import Foundation
import SocketIO

@MainActor
public class SocketIOManager: ObservableObject {
    public static let shared = SocketIOManager()

    public var socketURLString: String = "https://chat-back.gramatune.com"
    public func setSocketURL(_ url: String) { self.socketURLString = url }

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var authData: [String: Any] = [:]
    private var tokenProvider: (() -> String?)?
    public func setTokenProvider(_ provider: @escaping () -> String?) {
        self.tokenProvider = provider
    }
    
    public func setAuthData(participants: [String],
                            chatType: String? ,
                            conversationId: String?) {
        var data: [String: Any] = [
            "participants": participants,
        ]
        if let chatType { data["chatType"] =  chatType }        
        if let conversationId { data["conversationId"] =  conversationId }
        
        if let token = tokenProvider?(), !token.isEmpty {
            data["token"] = token
        }
        self.authData = data
    }
    
    private enum EventKey {
        case append, appended, edit, edited, delete, deleted, seen
        case batchAssigned, conversationAssigned, unreadBatches, error
    }
    
    private func eventName(_ key: EventKey) -> String {
        switch key {
        case .append: return "chat:append"
        case .appended: return "chat:appended"
        case .edit: return "chat:edit"
        case .edited: return "chat:edited"
        case .delete: return "chat:delete"
        case .deleted: return "chat:deleted"
        case .seen: return "chat:seen"
        case .batchAssigned: return "chat:batch-assigned"
        case .conversationAssigned: return "chat:conversation-assigned"
        case .unreadBatches: return "chat:unread-batches"
        case .error: return "chat:error"
        }
    }
    
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionError: String?
    
    // MARK: - New Handler Storage
    private var messageAppendedHandlers: [UUID: (ServerMessage) -> Void] = [:]
    private var messageEditedHandlers: [UUID: (String, String?) -> Void] = [:]
    private var messageDeletedHandlers: [UUID: (String) -> Void] = [:]
    private var batchAssignedHandlers: [UUID: (String, String?) -> Void] = [:]
    private var conversationAssignedHandlers: [UUID: (String) -> Void] = [:]
    private var unreadBatchesHandlers: [UUID: ([ServerBatchDocument], String?) -> Void] = [:]
    private var errorHandlers: [UUID: (String, String) -> Void] = [:]
    
    private init() {}
    
    public func connect() {
        // Prevent reconnecting if already connected with the same auth data
        if isConnected { return }
        
        guard let url = URL(string: socketURLString) else {
            connectionError = "Invalid URL"
            return
        }
        
        var cfg: SocketIOClientConfiguration = [.log(true), .compress, .secure(true)]
        manager = SocketManager(socketURL: url, config: cfg)
        socket = manager?.defaultSocket
        
        setupSocketHandlers()
        
        socket?.connect(withPayload: authData.isEmpty ? nil : authData)
    }
    
    public func disconnect() {
        socket?.disconnect()
        manager = nil
        socket = nil
        isConnected = false
        authData = [:]
        // Clear all handlers on full disconnect
        messageAppendedHandlers.removeAll()
        messageEditedHandlers.removeAll()
        messageDeletedHandlers.removeAll()
        batchAssignedHandlers.removeAll()
        conversationAssignedHandlers.removeAll()
        unreadBatchesHandlers.removeAll()
        errorHandlers.removeAll()
    }
    
    private func setupSocketHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.isConnected = true
                self?.connectionError = nil
            }
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }
        
        socket?.on(clientEvent: .error) { [weak self] data, ack in
            if let error = data.first as? String {
                DispatchQueue.main.async {
                    self?.connectionError = error
                }
            }
        }
        
        // Server events
        let appended = eventName(.appended)
        socket?.on(appended) { [weak self] data, _ in
            guard let self = self,
                  let dict = data.first as? [String: Any] else { return }

            var m = dict
            // нормализуем id/sender
            if m["_id"] == nil, let mid = m["messageId"] { m["_id"] = mid }
            if m["sender"] == nil, let sid = m["senderId"] as? String {
                m["sender"] = ["userId": sid, "displayName": (m["senderName"] as? String) ?? ""]
            }
            // нормализуем createdAt в ISO (если придёт epoch/отсутствует)
            if m["createdAt"] == nil {
                m["createdAt"] = ISO8601DateFormatter().string(from: Date())
            }

            if let message = ServerMessage(from: m) {
                // Notify all registered handlers
                for handler in self.messageAppendedHandlers.values {
                    handler(message)
                }
            }
        }
        
        let edited:String = eventName(.edited)
        socket?.on(edited) { [weak self] data, _ in
            guard let self = self,
                  let dict = data.first as? [String: Any],
                  let messageId = dict["messageId"] as? String else { return }
            let newText = dict["newText"] as? String
            
            // Notify all registered handlers
            for handler in self.messageEditedHandlers.values {
                handler(messageId, newText)
            }
        }
        
        let deleted = eventName(.deleted)
        socket?.on(deleted) { [weak self] data, _ in
            guard let self = self,
                  let dict = data.first as? [String: Any],
                  let messageId = dict["messageId"] as? String else { return }

            // Notify all registered handlers
            for handler in self.messageDeletedHandlers.values {
                handler(messageId)
            }
        }
        
        let batchAssigned = eventName(.batchAssigned)
        socket?.on(batchAssigned) { [weak self] data, ack in
            guard let self = self,
                  let dict = data.first as? [String: Any],
                  let batchId = dict["batchId"] as? String else { return }

            let conversationId = dict["conversationId"] as? String
            
            // Notify all registered handlers
            for handler in self.batchAssignedHandlers.values {
                handler(batchId, conversationId)
            }
        }
        
        let convAssigned = eventName(.conversationAssigned)
        
        socket?.on(convAssigned) { [weak self] data, ack in
            guard let self = self,
                  let dict = data.first as? [String: Any],
                  let conversationId = dict["conversationId"] as? String else { return }

            // Notify all registered handlers
            for handler in self.conversationAssignedHandlers.values {
                handler(conversationId)
            }
        }
        
        let unread = eventName(.unreadBatches)
        socket?.on(unread) { [weak self] data, ack in
            guard let self = self,
                  let dict = data.first as? [String: Any],
                  let items = dict["items"] as? [[String: Any]] else { return }
                  
            let cId = dict["conversationId"] as? String

            let batches = items.compactMap { ServerBatchDocument(from: $0) }
            
            // Notify all registered handlers
            for handler in self.unreadBatchesHandlers.values {
                handler(batches, cId)
            }
        }
        
        let errEv = eventName(.error)
        socket?.on(errEv) { [weak self] data, ack in
            guard let self = self,
                  let dict = data.first as? [String: Any],
                  let code = dict["code"] as? String,
                  let message = dict["message"] as? String else { return }

            // Notify all registered handlers
            for handler in self.errorHandlers.values {
                handler(code, message)
            }
        }
    }
    
    // MARK: - Client Events
    
    public func sendMessage(conversationId: String, batchId: String, message: ServerMessage) {
        var payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "senderId": message.sender.userId
        ]
        payload["senderName"] = message.sender.displayName
        if let text = message.text { payload["text"] = text }
        if !message.attachments.isEmpty {
            payload["attachments"] = message.attachments.map { $0.toDictionary() }
        }
        if let replyTo = message.replyTo { payload["replyTo"] = replyTo }
        if let expiresAt = message.expiresAt {
            payload["expiresAt"] = ISO8601DateFormatter().string(from: expiresAt)
        }
        // По спецификации messageId опционален; если есть — отправим
        payload["messageId"] = message.id
        socket?.emit(eventName(.append), payload)
    }
    
    public func editMessage(conversationId: String, batchId: String, messageId: String, newText: String?) {
        var payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "messageId": messageId
        ]
        if let newText { payload["newText"] = newText }
        socket?.emit(eventName(.edit), payload)
    }
    
    public func deleteMessage(conversationId: String, batchId: String, messageId: String) {
        let payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "messageId": messageId
        ]
        
        socket?.emit(eventName(.delete), payload)
    }
    
    public func markAsSeen(conversationId: String, batchId: String, userId: String) {
        let payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "userId": userId
        ]
        
        socket?.emit(eventName(.seen), payload)
    }
    
    // MARK: - Server Event Listeners (New API)
    
    public func onMessageAppended(handler: @escaping (ServerMessage) -> Void) -> UUID {
        let id = UUID()
        messageAppendedHandlers[id] = handler
        return id
    }
    
    public func offMessageAppended(id: UUID) {
        messageAppendedHandlers.removeValue(forKey: id)
    }
    
    public func onMessageEdited(handler: @escaping (String, String?) -> Void) -> UUID {
        let id = UUID()
        messageEditedHandlers[id] = handler
        return id
    }
    
    public func offMessageEdited(id: UUID) {
        messageEditedHandlers.removeValue(forKey: id)
    }
    
    public func onMessageDeleted(handler: @escaping (String) -> Void) -> UUID {
        let id = UUID()
        messageDeletedHandlers[id] = handler
        return id
    }
    
    public func offMessageDeleted(id: UUID) {
        messageDeletedHandlers.removeValue(forKey: id)
    }
    
    public func onBatchAssigned(handler: @escaping (String, String?) -> Void) -> UUID {
        let id = UUID()
        batchAssignedHandlers[id] = handler
        return id
    }
    
    public func offBatchAssigned(id: UUID) {
        batchAssignedHandlers.removeValue(forKey: id)
    }
    
    public func onConversationAssigned(handler: @escaping (String) -> Void) -> UUID { 
        let id = UUID()
        conversationAssignedHandlers[id] = handler
        return id
    }
    
    public func offConversationAssigned(id: UUID) {
        conversationAssignedHandlers.removeValue(forKey: id)
    }
    
    public func onUnreadBatches(handler: @escaping ([ServerBatchDocument], String?) -> Void) -> UUID {
        let id = UUID()
        unreadBatchesHandlers[id] = handler
        return id
    }
    
    public func offUnreadBatches(id: UUID) {
        unreadBatchesHandlers.removeValue(forKey: id)
    }
    
    public func onError(handler: @escaping (String, String) -> Void) -> UUID {
        let id = UUID()
        errorHandlers[id] = handler
        return id
    }
    
    public func offError(id: UUID) {
        errorHandlers.removeValue(forKey: id)
    }
}
