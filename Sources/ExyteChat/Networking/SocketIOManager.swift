import Foundation
import SocketIO

public class SocketIOManager: ObservableObject {
    public static let shared = SocketIOManager()
    
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    @Published public var isConnected = false
    @Published public var connectionError: String?
    
    private init() {
        // Initialize with your server URL
        manager = SocketManager(socketURL: URL(string: "https://chat-back.gramatune.com")!, config: [
            .log(true),
            .compress
        ])
        socket = manager?.defaultSocket
    }
    
    public func connect() {
        socket?.connect()
        
        socket?.on(clientEvent: .connect) { data, ack in
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionError = nil
            }
        }
        
        socket?.on(clientEvent: .disconnect) { data, ack in
            DispatchQueue.main.async {
                self.isConnected = false
            }
        }
        
        socket?.on(clientEvent: .error) { data, ack in
            DispatchQueue.main.async {
                self.connectionError = data.first as? String ?? "Unknown error"
            }
        }
    }
    
    public func disconnect() {
        socket?.disconnect()
    }
    
    public func sendMessage(conversationId: String, batchId: String, text: String?, attachments: [ServerAttachment]?, replyTo: String?) {
        var payload: [String: Any] = [
            "conversationId": conversationId,
            "batchId": batchId,
            "senderId": "current-user-id" // Replace with actual user ID
        ]
        
        if let text = text {
            payload["text"] = text
        }
        
        if let attachments = attachments {
            payload["attachments"] = attachments.map { $0.toDict() }
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
    
    // MARK: - Event Listeners
    
    public func onMessageAppended(handler: @escaping (ServerMessage) -> Void) {
        socket?.on("chat.appended") { data, ack in
            guard let dict = data.first as? [String: Any],
                  let message = ServerMessage(from: dict) else {
                return
            }
            DispatchQueue.main.async {
                handler(message)
            }
        }
    }
    
    public func onMessageEdited(handler: @escaping (ServerMessage) -> Void) {
        socket?.on("chat.edited") { data, ack in
            guard let dict = data.first as? [String: Any],
                  let message = ServerMessage(from: dict) else {
                return
            }
            DispatchQueue.main.async {
                handler(message)
            }
        }
    }
    
    public func onMessageDeleted(handler: @escaping (String) -> Void) {
        socket?.on("chat.deleted") { data, ack in
            guard let dict = data.first as? [String: Any],
                  let messageId = dict["messageId"] as? String else {
                return
            }
            DispatchQueue.main.async {
                handler(messageId)
            }
        }
    }
    
    public func onBatchAssigned(handler: @escaping (String, String?) -> Void) {
        socket?.on("chat.batch-assigned") { data, ack in
            guard let dict = data.first as? [String: Any],
                  let batchId = dict["batchId"] as? String else {
                return
            }
            let conversationId = dict["conversationId"] as? String
            DispatchQueue.main.async {
                handler(batchId, conversationId)
            }
        }
    }
}
