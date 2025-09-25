import Foundation
import SocketIO

@MainActor
public class SocketIOManager: ObservableObject {
    public static let shared = SocketIOManager()

    public var socketURLString: String = "https://chat-back.gramatune.com"
    public func setSocketURL(_ url: String) { self.socketURLString = url }

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var authPayload: [String: Any] = [:]
    
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
    
    public func connect(to url: String = "https://chat-back.gramatune.com") {
        guard let url = URL(string: url) else {
            connectionError = "Invalid URL"
            return
        }
        
        manager = SocketManager(socketURL: url, config: [.log(true), .compress, .secure(true)])
        socket = manager?.defaultSocket
        
        setupSocketHandlers()
        
        socket?.connect(withPayload: authPayload.isEmpty ? nil : authPayload)
    }
    
    public func disconnect() {
        socket?.disconnect()
        manager = nil
        socket = nil
        isConnected = false
        authPayload = [:]
    }

    public func connect(conversationId: String? = nil, batchId: String? = nil, userId: String? = nil, userName: String? = nil) {
        guard let url = URL(string: socketURLString) else {
            connectionError = "Invalid URL"
            return
        }
        var cfg: SocketIOClientConfiguration = [.log(false), .compress, .secure(true)]
        manager = SocketManager(socketURL: url, config: cfg)
        socket = manager?.defaultSocket

        var auth: [String: Any] = [:]
        if let conversationId { auth["conversationId"] = conversationId }
        if let batchId { auth["batchId"] = batchId }
        if let userId { auth["userId"] = userId }
        if let userName { auth["userName"] = userName }
        self.authPayload = ["auth": auth]

        setupSocketHandlers()
        socket?.connect(withPayload: self.authPayload)
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
        socket?.on("chat.appended") { [weak self] data, _ in
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
        
        socket?.on("chat.edited") { [weak self] data, _ in
            guard let self = self,
                  let handler = self.messageEditedHandler,
                  let dict = data.first as? [String: Any],
                  let messageId = dict["messageId"] as? String else { return }
            let newText = dict["newText"] as? String
            handler(messageId, newText)
        }
        
        socket?.on("chat.deleted") { [weak self] data, _ in
            guard let self = self,
                  let handler = self.messageDeletedHandler,
                  let dict = data.first as? [String: Any],
                  let messageId = dict["messageId"] as? String else { return }
            
            handler(messageId)
        }
        
        socket?.on("chat.batch-assigned") { [weak self] data, ack in
            guard let self = self,
                  let handler = self.batchAssignedHandler,
                  let dict = data.first as? [String: Any],
                  let batchId = dict["batchId"] as? String else { return }
            
            let conversationId = dict["conversationId"] as? String
            handler(batchId, conversationId)
        }
        
        socket?.on("chat.conversation-assigned") { [weak self] data, ack in
            guard let self = self,
                  let handler = self.conversationAssignedHandler,
                  let dict = data.first as? [String: Any],
                  let conversationId = dict["conversationId"] as? String else { return }
            
            handler(conversationId)
        }
        
        socket?.on("chat.unread-batches") { [weak self] data, ack in
            guard let self = self,
                  let handler = self.unreadBatchesHandler,
                  let dict = data.first as? [String: Any],
                  let items = dict["items"] as? [[String: Any]] else { return }
            
            let batches = items.compactMap { ServerBatchDocument(from: $0) }
            handler(batches)
        }
        
        socket?.on("chat.error") { [weak self] data, ack in
            guard let self = self,
                  let handler = self.errorHandler,
                  let dict = data.first as? [String: Any],
                  let code = dict["code"] as? String,
                  let message = dict["message"] as? String else { return }
            
            handler(code, message)
        }
    }
    
    // MARK: - Client Events
    
    public func sendMessage(conversationId: String, batchId: String, senderId: String, senderName: String? = nil, text: String? = nil, attachments: [ServerAttachment] = [], replyTo: String? = nil, expiresInMs: Int? = nil, expiresAt: Date? = nil) {
        var payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "senderId": senderId
        ]
        if let senderName { payload["senderName"] = senderName }
        if let text { payload["text"] = text }
        if !attachments.isEmpty {
            payload["attachments"] = attachments.map { $0.toDictionary() }
        }
        if let replyTo { payload["replyTo"] = replyTo }
        if let expiresInMs { payload["expiresInMs"] = expiresInMs }
        if let expiresAt { payload["expiresAt"] = ISO8601DateFormatter().string(from: expiresAt) }
        socket?.emit("chat.append", payload)
    }
    
    public func editMessage(conversationId: String, batchId: String, messageId: String, newText: String?) {
        var payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "messageId": messageId
        ]
        if let newText { payload["newText"] = newText }
        socket?.emit("chat.edit", payload)
    }
    
    public func deleteMessage(conversationId: String, batchId: String, messageId: String) {
        let payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "messageId": messageId
        ]
        
        socket?.emit("chat.delete", payload)
    }
    
    public func markAsSeen(conversationId: String, batchId: String, userId: String) {
        let payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "userId": userId
        ]
        
        socket?.emit("chat.seen", payload)
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
