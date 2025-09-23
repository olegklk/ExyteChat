import Foundation

public class ChatAPIManager {
    public static let shared = ChatAPIManager()
    
    private let baseURL = "https://chat-back.gramatune.com" // Replace with your actual base URL
    
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
                return "/history/\(conversationId)"
            }
        }
    }
    
    private init() {}
    
    public func openBatch(type: String, batchId: String, participants: [String], conversationId: String? = nil) async throws {
        var urlComponents = URLComponents(string: baseURL + Endpoint.openBatch(type: type, batchId: batchId).path)!
        
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
    
    public func patchMessage(batchId: String, messageId: String, newText: String) async throws -> [String: Any] {
        let urlComponents = URLComponents(string: baseURL + Endpoint.patchMessage.path)!
        let body: [String: Any] = [
            "batchId": batchId,
            "messageId": messageId,
            "newText": newText
        ]
        
        return try await makeRequest(urlComponents: urlComponents, method: "PATCH", body: body)
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
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json
    }
}
