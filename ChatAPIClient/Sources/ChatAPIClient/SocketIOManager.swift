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
    public func setAuthData(_ data: [String: Any]) {
        self.authData = data
    }
    
    private enum EventKey {
        case append, appended, edit, edited, delete, deleted, seen
        case batchAssigned, conversationAssigned, unreadBatches, error
    }
    
    private func eventName(_ key: EventKey) -> String {
        switch key {
        case .append: return "chat_append"
        case .appended: return "chat_appended"
        case .edit: return "chat_edit"
        case .edited: return "chat_edited"
        case .delete: return "chat_delete"
        case .deleted: return "chat_deleted"
        case .seen: return "chat_seen"
        case .batchAssigned: return "chat_batch_assigned"
        case .conversationAssigned: return "chat_conversation_assigned"
        case .unreadBatches: return "chat_unread_batches"
        case .error: return "chat_error"
        }
    }
    
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionError: String?
    
    private var messageAppendedHandler: ((ServerMessage) -> Void)?
    private var messageEditedHandler: ((String, String?) -> Void)?
    private var messageDeletedHandler: ((String) -> Void)?
    private var batchAssignedHandler: ((String, String?) -> Void)?
    private var conversationAssignedHandler: ((String) -> Void)?
    private var unreadBatchesHandler: (([ServerBatchDocument]) -> Void)?
    private var errorHandler: ((String, String) -> Void)?
    
    private init() {}
    
    public func connect() {
        guard let url = URL(string: socketURLString) else {
            connectionError = "Invalid URL"
            return
        }
        
        var cfg: SocketIOClientConfiguration = [.log(false), .compress, .secure(true)]
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
                self.messageAppendedHandler?(message)
            }
        }
        
        let edited = eventName(.edited)
        socket?.on(edited) { [weak self] data, _ in
            guard let self = self,
                  let handler = self.messageEditedHandler,
                  let dict = data.first as? [String: Any],
                  let messageId = dict["messageId"] as? String else { return }
            let newText = dict["newText"] as? String
            handler(messageId, newText)
        }
        
        let deleted = eventName(.deleted)
        socket?.on(deleted) { [weak self] data, _ in
            guard let self = self,
                  let handler = self.messageDeletedHandler,
                  let dict = data.first as? [String: Any],
                  let messageId = dict["messageId"] as? String else { return }

            handler(messageId)
        }
        
        let batchAssigned = eventName(.batchAssigned)
        socket?.on(batchAssigned) { [weak self] data, ack in
            guard let self = self,
                  let handler = self.batchAssignedHandler,
                  let dict = data.first as? [String: Any],
                  let batchId = dict["batchId"] as? String else { return }

            let conversationId = dict["conversationId"] as? String
            handler(batchId, conversationId)
        }
        
        let convAssigned = eventName(.conversationAssigned)
        socket?.on(convAssigned) { [weak self] data, ack in
            guard let self = self,
                  let handler = self.conversationAssignedHandler,
                  let dict = data.first as? [String: Any],
                  let conversationId = dict["conversationId"] as? String else { return }

            handler(conversationId)
        }
        
        let unread = eventName(.unreadBatches)
        socket?.on(unread) { [weak self] data, ack in
            guard let self = self,
                  let handler = self.unreadBatchesHandler,
                  let dict = data.first as? [String: Any],
                  let items = dict["items"] as? [[String: Any]] else { return }

            let batches = items.compactMap { ServerBatchDocument(from: $0) }
            handler(batches)
        }
        
        let errEv = eventName(.error)
        socket?.on(errEv) { [weak self] data, ack in
            guard let self = self,
                  let handler = self.errorHandler,
                  let dict = data.first as? [String: Any],
                  let code = dict["code"] as? String,
                  let message = dict["message"] as? String else { return }

            handler(code, message)
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
    
    // MARK: - Server Events
    
    public func onMessageAppended(handler: @escaping (ServerMessage) -> Void) {
        messageAppendedHandler = handler
    }
    
    public func onMessageEdited(handler: @escaping (String, String?) -> Void) {
        messageEditedHandler = handler
    }
    
    public func onMessageDeleted(handler: @escaping (String) -> Void) {
        messageDeletedHandler = handler
    }
    
    public func onBatchAssigned(handler: @escaping (String, String?) -> Void) {
        batchAssignedHandler = handler
    }
    
    public func onConversationAssigned(handler: @escaping (String) -> Void) { 
        conversationAssignedHandler = handler
    }
    
    public func onUnreadBatches(handler: @escaping ([ServerBatchDocument]) -> Void) {
        unreadBatchesHandler = handler
    }
    
    public func onError(handler: @escaping (String, String) -> Void) {
        errorHandler = handler
    }
}
