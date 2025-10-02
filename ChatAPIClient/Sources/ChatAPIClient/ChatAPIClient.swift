import Foundation

public actor ChatAPIClient {
    public static let shared = ChatAPIClient()

    private var baseURL = "https://chat-back.gramatune.com"
    public func setBaseURL(_ url: String) { self.baseURL = url }
    
    public enum Endpoint {
        case openBatch(type: String, batchId: String)
        case closeBatch(batchId: String)
        case patchMessage
        case getHistory(conversationId: String)
        case getConversations(userId: String)
        case getUnreadBatches(conversationId: String)
        
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
            case .getConversations(let userId):
                return "/chats/unread/by-user/\(userId)"
            case .getUnreadBatches(let conversationId):
                return "/chats/\(conversationId)/unread"
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
    
    public func getHistory(conversationId: String) async throws -> [ServerBatchDocument] {
        let urlComponents = URLComponents(string: baseURL + Endpoint.getHistory(conversationId: conversationId).path)!
        let items = try await makeRequest(urlComponents: urlComponents, method: "GET") as? [[String: Any]]
        
        return items?.compactMap { ServerBatchDocument(from: $0) } ?? []
      
    }
    
    public func getConversations(userId: String, limit: Int?, perConv: Int?) async throws -> [ServerConversationListItem] {
        var urlComponents = URLComponents(string: baseURL + Endpoint.getConversations(userId: userId).path)!
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
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        if data.isEmpty { return NSNull() }
        return try JSONSerialization.jsonObject(with: data, options: [])
    }
}
