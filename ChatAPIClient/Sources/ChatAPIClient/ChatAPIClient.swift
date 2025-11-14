import Foundation
import os
import Alamofire

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
    
    private var tokenProvider: (@Sendable () -> String?)?
    public func setTokenProvider(_ provider: @escaping @Sendable () -> String?) {
        self.tokenProvider = provider
        // Re-create the session with the new provider
        self.session = Session(interceptor: APIRequestInterceptor(tokenProvider: provider), eventMonitors: [APIEventMonitor()])
    }
    
    private var session: Session = Session() // default session initially

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
    
//    public func openBatch(type: ServerBatchDocument.BatchType, batchId: String, participants: [String], conversationId: String? = nil) async throws {
//        let urlComponents = URLComponents(string: baseURL + Endpoint.openBatch(type: type.rawValue, batchId: batchId).path)!
//        
//        var body: Parameters = [
//            "participants": participants
//        ]
//        
//        if let conversationId = conversationId {
//            body["conversationId"] = conversationId
//        }
//        
//        try await makeRequest(urlComponents: urlComponents, method: "POST", body: body)
//    }
    
//    public func closeBatch(batchId: String) async throws {
//        let urlComponents = URLComponents(string: baseURL + Endpoint.closeBatch(batchId: batchId).path)!
//        try await makeRequest(urlComponents: urlComponents, method: "POST")
//    }
    
    public func patchMessage(batchId: String, messageId: String, newText: String?) async throws -> PatchResult {
        let urlComponents = URLComponents(string: baseURL + Endpoint.patchMessage.path)!
        var body: Parameters = [
            "batchId": batchId,
            "messageId": messageId
        ]
        if let newText { body["newText"] = newText }
        return try await makeRequest(urlComponents: urlComponents, method: "PATCH", body: body)
    }
    
    //month - string($YYYY-MM)
    public func getHistory(conversationId: String, month: String?) async throws -> [ServerBatchDocument] {
        var urlComponents = URLComponents(string: baseURL + Endpoint.getHistory(conversationId: conversationId).path)!
        var q: [URLQueryItem] = []
        if let month { q.append(URLQueryItem(name: "month", value: month)) }
        urlComponents.queryItems = q.isEmpty ? nil : q
        return try await makeRequest(urlComponents: urlComponents, method: "GET")
    }
    
    public func getUnreadConversations(userId: String, limit: Int?, perConv: Int?) async throws -> [ServerUnreadConversationListItem] {
        var urlComponents = URLComponents(string: baseURL + Endpoint.getUnreadConversations(userId: userId).path)!
        var q: [URLQueryItem] = []
        if let limit { q.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let perConv { q.append(URLQueryItem(name: "perConv", value: String(perConv))) }
        urlComponents.queryItems = q.isEmpty ? nil : q
        return try await makeRequest(urlComponents: urlComponents, method: "GET")
    }
    
    public func getAllConversations(limit: Int?, perConv: Int?) async throws -> [ServerConversationListItem] {
        var urlComponents = URLComponents(string: baseURL + Endpoint.getAllConversations.path)!
        var q: [URLQueryItem] = []
        if let limit { q.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let perConv { q.append(URLQueryItem(name: "perConv", value: String(perConv))) }
        urlComponents.queryItems = q.isEmpty ? nil : q
        
        return try await makeRequest(urlComponents: urlComponents, method: "GET")
    }
    
    private func makeRequest<T: Codable & Sendable>(urlComponents: URLComponents, method: String, body: Parameters? = nil) async throws -> T {
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try await withCheckedThrowingContinuation { continuation in
            let alamofireMethod = HTTPMethod(rawValue: method)
            
            session.request(
                url,
                method: alamofireMethod,
                parameters: body,
                encoding: JSONEncoding.default
            )
            .validate()
            .responseDecodable(of: T.self, decoder: decoder) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    if let afError = error.asAFError {
                        switch afError {
                        case .responseValidationFailed(let reason):
                            if case .unacceptableStatusCode(let code) = reason {
                                var message: String?
                                if let data = response.data,
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    message = (json["message"] as? String) ?? (json["error"] as? String)
                                }
                                continuation.resume(throwing: ChatAPIError.server(statusCode: code, message: message ?? HTTPURLResponse.localizedString(forStatusCode: code)))
                            } else {
                                continuation.resume(throwing: ChatAPIError.server(statusCode: -1, message: afError.localizedDescription))
                            }
                        default:
                            continuation.resume(throwing: ChatAPIError.server(statusCode: -1, message: afError.localizedDescription))
                        }
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

// MARK: - Alamofire Interceptors

private final class APIRequestInterceptor: RequestInterceptor {
    private let tokenProvider: (@Sendable () -> String?)?

    init(tokenProvider: @escaping @Sendable () -> String?) {
        self.tokenProvider = tokenProvider
    }

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest
        
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        if let token = tokenProvider?(), !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        completion(.success(urlRequest))
    }
}

private final class APIEventMonitor: EventMonitor, Sendable {
    #if DEBUG
    let logger = Logger(subsystem: "ExyteChat.ChatAPIClient", category: "network")
    #endif
    
    func requestDidResume(_ request: Request) {
        #if DEBUG
        guard let urlRequest = request.request else { return }
        
        let redactedHeaders: [String: String] = {
            var h = urlRequest.allHTTPHeaderFields ?? [:]
            if h.keys.contains("Authorization") { h["Authorization"] = "Bearer <redacted>" }
            return h
        }()
        
        let httpMethod = urlRequest.httpMethod ?? "UNKNOWN"
        let url = urlRequest.url?.absoluteString ?? "UNKNOWN"
        
        logger.debug("➡️ Request: \(httpMethod) \(url)")
        logger.debug("Headers: \(String(describing: redactedHeaders))")
        
        if let parameters = request.request?.httpBody,
           let jsonObject = try? JSONSerialization.jsonObject(with: parameters),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            logger.debug("Body: \(prettyString)")
        } else {
            logger.debug("Body: <empty or binary>")
        }
        #endif
    }
    
    func request(_ request: Request, didParseResponse response: DataResponse<Data?, AFError>) {
        #if DEBUG
        let httpMethod = request.request?.httpMethod ?? "UNKNOWN"
        let url = request.request?.url?.absoluteString ?? "UNKNOWN"
        
        if let httpResponse = response.response {
            logger.debug("⬅️ Response: \(httpResponse.statusCode) \(httpMethod) \(url)")
        } else {
            logger.debug("⬅️ Response: No HTTP Status Code \(httpMethod) \(url)")
        }
        
        if let data = response.data {
            let responseBodyString: String
            if data.isEmpty {
                responseBodyString = "<empty>"
            } else if let obj = try? JSONSerialization.jsonObject(with: data),
                      let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
                      let str = String(data: pretty, encoding: .utf8) {
                responseBodyString = str
            } else {
                responseBodyString = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
            }
            logger.debug("Body: \(responseBodyString)")
        } else {
            logger.debug("Body: <unavailable>")
        }
        #endif
    }
}
