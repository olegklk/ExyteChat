import Foundation

public enum ChatAPIError: Error, LocalizedError, Sendable {
    case server(statusCode: Int, message: String)
    
    public var errorDescription: String? {
        switch self {
        case .server(_, let message): return message
        }
    }
}

public actor ChatAPIClient {
    public static let shared = ChatAPIClient()

    private var baseURL = "https://chat-back.gramatune.com"
    public func setBaseURL(_ url: String) { self.baseURL = url }
    
    private var tokenProvider: (() -> String?)?
    public func setTokenProvider(_ provider: @escaping () -> String?) {
        self.tokenProvider = provider
    }
    
    public enum Endpoint {
        case openBatch(type: String, batchId: String)
        case closeBatch(batchId: String)
        case patchMessage
        case getHistory(conversationId: String)
        case getUnreadConversations(userId: String)
        case getUnreadBatches(conversationId: String)
        case getAllConversations
        
        var path: String {
            switch self {
            case .openBatch(let type, let batchId):
                return "/chats/open/\(type)/\(batchId)"
            case .closeBatch(let batchId):
                return "/chats/close/\(batchId)"
            case .patchMessage:
                return "/chats/mongo/patch"
            case .getHistory(let conversationId):
                return "/chats/\(conversationId)/history"
            case .getUnreadConversations(let userId):
                return "/chats/unread/by-user/\(userId)"
            case .getUnreadBatches(let conversationId):
                return "/chats/\(conversationId)/unread"
            case .getAllConversations:
                return "/chats/all-chat"
            }
        }
    }
    
    private init() {}

    public struct PatchResult: Codable, Hashable, Sendable {
        public let matched: Int
        public let modified: Int
    }
    
    public func openBatch(type: ServerBatchDocument.BatchType, batchId: String, participants: [String], conversationId: String? = nil) async throws {
        var urlComponents = URLComponents(string: baseURL + Endpoint.openBatch(type: type.rawValue, batchId: batchId).path)!
        
        var body: [String: Any] = [
            "participants": participants
        ]
        
        if let conversationId = conversationId {
            body["conversationId"] = conversationId
        }
        
        try await makeRequest(urlComponents: urlComponents, method: "POST", body: body)
    }
    
    public func closeBatch(batchId: String) async throws {
        let urlComponents = URLComponents(string: baseURL + Endpoint.closeBatch(batchId: batchId).path)!
        try await makeRequest(urlComponents: urlComponents, method: "POST")
    }
    
    public func patchMessage(batchId: String, messageId: String, newText: String?) async throws -> PatchResult {
        let urlComponents = URLComponents(string: baseURL + Endpoint.patchMessage.path)!
        var body: [String: Any] = [
            "batchId": batchId,
            "messageId": messageId
        ]
        if let newText { body["newText"] = newText }
        let payload = try await makeRequest(urlComponents: urlComponents, method: "PATCH", body: body)
        let dict = payload as? [String: Any] ?? [:]
        let matched = dict["matched"] as? Int ?? 0
        let modified = dict["modified"] as? Int ?? 0
        return PatchResult(matched: matched, modified: modified)
    }
    
    //month - string($YYYY-MM)
    public func getHistory(conversationId: String, month: String?) async throws -> [ServerBatchDocument] {
        var urlComponents = URLComponents(string: baseURL + Endpoint.getHistory(conversationId: conversationId).path)!
        var q: [URLQueryItem] = []
        if let month { q.append(URLQueryItem(name: "month", value: month)) }
        urlComponents.queryItems = q.isEmpty ? nil : q
        let items = try await makeRequest(urlComponents: urlComponents, method: "GET") as? [[String: Any]]
        
        return items?.compactMap { ServerBatchDocument(from: $0) } ?? []
      
    }
    
    public func getUnreadConversations(userId: String, limit: Int?, perConv: Int?) async throws -> [ServerUnreadConversationListItem] {
        var urlComponents = URLComponents(string: baseURL + Endpoint.getUnreadConversations(userId: userId).path)!
        var q: [URLQueryItem] = []
        if let limit { q.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let perConv { q.append(URLQueryItem(name: "perConv", value: String(perConv))) }
        urlComponents.queryItems = q.isEmpty ? nil : q
        let items = try await makeRequest(urlComponents: urlComponents, method: "GET") as? [[String: Any]]
        return items?.compactMap { ServerUnreadConversationListItem(from: $0) } ?? []
    }
    
    public func getAllConversations(limit: Int?, perConv: Int?) async throws -> [ServerConversationListItem] {
        var urlComponents = URLComponents(string: baseURL + Endpoint.getAllConversations.path)!
        var q: [URLQueryItem] = []
        if let limit { q.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let perConv { q.append(URLQueryItem(name: "perConv", value: String(perConv))) }
        urlComponents.queryItems = q.isEmpty ? nil : q
        
        let items = try await makeRequest(urlComponents: urlComponents, method: "GET") as? [[String: Any]]
        return items?.compactMap { ServerConversationListItem(from: $0) } ?? []
    }
    
    private func makeRequest(urlComponents: URLComponents, method: String, body: [String: Any]? = nil) async throws -> Any {
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = tokenProvider?(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            var message: String?
            if !data.isEmpty {
                if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    message = (obj["message"] as? String) ?? (obj["error"] as? String)
                } else {
                    message = String(data: data, encoding: .utf8)
                }
            }
            throw ChatAPIError.server(
                statusCode: httpResponse.statusCode,
                message: message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
        
        if data.isEmpty { return NSNull() }
        return try JSONSerialization.jsonObject(with: data, options: [])
    }
}
