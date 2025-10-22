//
//  Utils.swift
//  ChatExample
//
//  Created by Oleg Kolokolov on 30.09.2025.
//

import Foundation

public final class ChatUtils {
    
    @MainActor public static func idsFromURLString(_ urlString: String) -> (String?, String?){
        var conversationId: String?
        var batchId: String?
    
        if let url = URL(string: urlString) {
            // 1) пробуем фрагмент после "#"
            if let fragment = url.fragment, !fragment.isEmpty {
                let dict = parseQuery(fragment)
                conversationId = dict["conversation"] ?? dict["conversationId"] ?? dict["c"]
                batchId = dict["batch"] ?? dict["batchId"] ?? dict["b"]
            }
            // 2) если во фрагменте ничего, пробуем query ?a=b&...
            if conversationId == nil || batchId == nil {
                if let comps = URLComponents(string: urlString), let items = comps.queryItems {
                    let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
                    if conversationId == nil {
                        conversationId = dict["conversation"] ?? dict["conversationId"] ?? dict["c"]
                    }
                    if batchId == nil {
                        batchId = dict["batch"] ?? dict["batchId"] ?? dict["b"]
                    }
                }
            }
        } else {
            // На случай передачи только фрагмента/сырой строки
            let fragment = urlString.replacingOccurrences(of: "#", with: "")
            let dict = parseQuery(fragment)
            conversationId = dict["conversation"] ?? dict["conversationId"] ?? dict["c"]
            batchId = dict["batch"] ?? dict["batchId"] ?? dict["b"]
        }
    
        
        return (conversationId, batchId)
        
    }
    
    private static func parseQuery(_ s: String) -> [String: String] {
        var res: [String: String] = [:]
        for pair in s.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard !parts.isEmpty else { continue }
            let name = parts[0].removingPercentEncoding ?? parts[0]
            let value = parts.count == 2 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
            res[name] = value
        }
        return res
    }
    
    private static func generateRandomPart() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let randomPart = String((0..<3).compactMap { _ in alphabet.randomElement() })
        return randomPart
    }
    
    public static func generateRandomUserId() -> String {
        return "u" + generateRandomPart()
    }
    
    public static func generateRandomConversationId() -> String {
        return "c" + generateRandomPart()//UUID().uuidString
    }
    
    
}

//  UUID from Data
extension UUID {
    init?(data: Data) {
        guard data.count == 16 else { return nil }
        self.init(uuid: data.withUnsafeBytes { $0.load(as: uuid_t.self) })
    }
}

public enum AppKeys {
    public enum UserDefaults {
        public static let conversationId = "UserSettings.conversationId"
    }
}
