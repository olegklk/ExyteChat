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
    
//    public static func combineUUIDs(_ uuid1: UUID, _ uuid2: UUID) -> String {
//        var uuid1Bytes = [UInt8](repeating: 0, count: 16)
//        var uuid2Bytes = [UInt8](repeating: 0, count: 16)
//        
//        uuid1.uuid.withUnsafeBytes { ptr in
//            _ = ptr.copyBytes(to: &uuid1Bytes)
//        }
//        uuid2.uuid.withUnsafeBytes { ptr in
//            _ = ptr.copyBytes(to: &uuid2Bytes)
//        }
//        
//        let combinedBytes = uuid1Bytes + uuid2Bytes
//        let combinedData = Data(combinedBytes)
//        return combinedData.base64EncodedString()
//            .replacingOccurrences(of: "+", with: "-")
//            .replacingOccurrences(of: "/", with: "_")
//            .replacingOccurrences(of: "=", with: "")
//    }
//    
//    public static func splitUUIDs(_ combinedString: String) -> (UUID, UUID)? {
//        var base64String = combinedString
//            .replacingOccurrences(of: "-", with: "+")
//            .replacingOccurrences(of: "_", with: "/")
//        
//        let padding = base64String.count % 4
//        if padding > 0 {
//            base64String += String(repeating: "=", count: 4 - padding)
//        }
//        
//        guard let combinedData = Data(base64Encoded: base64String),
//              combinedData.count == 32 else {
//            return nil
//        }
//        
//        let uuid1Data = combinedData[0..<16]
//        let uuid2Data = combinedData[16..<32]
//        
//        guard let uuid1 = UUID(data: uuid1Data),
//              let uuid2 = UUID(data: uuid2Data) else {
//            return nil
//        }
//        
//        return (uuid1, uuid2)
//    }
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
