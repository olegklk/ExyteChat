import Foundation
import SocketIO

public class SocketIOManager: ObservableObject {
    public static let shared = SocketIOManager()
    
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionError: String?
    
    private var messageAppendedHandler: ((ServerMessage) -> Void)?
    private var messageEditedHandler: ((ServerMessage) -> Void)?
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
        
        manager = SocketManager(socketURL: url, config: [.log(true), .compress])
        socket = manager?.defaultSocket
        
        setupSocketHandlers()
        
        socket?.connect()
    }
    
    public func disconnect() {
        socket?.disconnect()
        manager = nil
        socket = nil
        isConnected = false
    }
    
    private func setupSocketHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            self?.isConnected = true
            self?.connectionError = nil
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            self?.isConnected = false
        }
        
        socket?.on(clientEvent: .error) { [weak self] data, ack in
            if let error = data.first as? String {
                self?.connectionError = error
            }
        }
        
        // Server events
        socket?.on("chat.appended") { [weak self] data, ack in
            guard let self = self,
                  let handler = self.messageAppendedHandler,
                  let dict = data.first as? [String: Any],
                  let message = ServerMessage(from: dict) else { return }
            
            handler(message)
        }
        
        socket?.on("chat.edited") { [weak self] data, ack in
            guard let self = self,
                  let handler = self.messageEditedHandler,
                  let dict = data.first as? [String: Any],
                  let message = ServerMessage(from: dict) else { return }
            
            handler(message)
        }
        
        socket?.on("chat.deleted") { [weak self] data, ack in
            guard let self = self,
                  let handler = self.messageDeletedHandler,
                  let messageId = data.first as? String else { return }
            
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
    
    public func sendMessage(conversationId: String, batchId: String, text: String?, attachments: [[String: Any]]?, replyTo: String?) {
        var payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "senderId": "" // This should be filled with actual sender ID
        ]
        
        if let text = text {
            payload["text"] = text
        }
        
        if let attachments = attachments {
            payload["attachments"] = attachments
        }
        
        if let replyTo = replyTo {
            payload["replyTo"] = replyTo
        }
        
        socket?.emit("chat.append", payload)
    }
    
    public func editMessage(conversationId: String, batchId: String, messageId: String, newText: String) {
        let payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "messageId": messageId,
            "newText": newText
        ]
        
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
    
    public func onMessageEdited(handler: @escaping (ServerMessage) -> Void) {
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
