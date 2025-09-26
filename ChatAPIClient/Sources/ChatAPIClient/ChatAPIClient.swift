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
        let dict = try await makeRequest(urlComponents: urlComponents, method: "PATCH", body: body)
        let matched = dict["matched"] as? Int ?? 0
        let modified = dict["modified"] as? Int ?? 0
        return PatchResult(matched: matched, modified: modified)
    }
    
    public func getHistory(conversationId: String) async throws -> [ServerBatchDocument] {
        let urlComponents = URLComponents(string: baseURL + Endpoint.getHistory(conversationId: conversationId).path)!
        let data = try await makeRequest(urlComponents: urlComponents, method: "GET")
        
        guard let items = data["items"] as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { ServerBatchDocument(from: $0) }
    }
    
    private func makeRequest(urlComponents: URLComponents, method: String, body: [String: Any]? = nil) async throws -> [String: Any] {
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
        
        if data.isEmpty { return [:] }
        let jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
        return jsonObj as? [String: Any] ?? [:] //измени эту строку так как json объект это массив (jsonObj    __NSArrayI    10 elements    0x0000600002694720) AI!
    }
}
