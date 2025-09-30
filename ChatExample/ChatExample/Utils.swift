//
//  Utils.swift
//  ChatExample
//
//  Created by Oleg Kolokolov on 30.09.2025.
//

import Foundation

public final class ChatUtils {
    public static func combineUUIDs(_ uuid1: UUID, _ uuid2: UUID) -> String {
        var uuid1Bytes = [UInt8](repeating: 0, count: 16)
        var uuid2Bytes = [UInt8](repeating: 0, count: 16)
        
        uuid1.uuid.withUnsafeBytes { ptr in
            _ = ptr.copyBytes(to: &uuid1Bytes)
        }
        uuid2.uuid.withUnsafeBytes { ptr in
            _ = ptr.copyBytes(to: &uuid2Bytes)
        }
        
        let combinedBytes = uuid1Bytes + uuid2Bytes
        let combinedData = Data(combinedBytes)
        return combinedData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    public static func splitUUIDs(_ combinedString: String) -> (UUID, UUID)? {
        var base64String = combinedString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let padding = base64String.count % 4
        if padding > 0 {
            base64String += String(repeating: "=", count: 4 - padding)
        }
        
        guard let combinedData = Data(base64Encoded: base64String),
              combinedData.count == 32 else {
            return nil
        }
        
        let uuid1Data = combinedData[0..<16]
        let uuid2Data = combinedData[16..<32]
        
        guard let uuid1 = UUID(data: uuid1Data),
              let uuid2 = UUID(data: uuid2Data) else {
            return nil
        }
        
        return (uuid1, uuid2)
    }
}

//  UUID from Data
extension UUID {
    init?(data: Data) {
        guard data.count == 16 else { return nil }
        self.init(uuid: data.withUnsafeBytes { $0.load(as: uuid_t.self) })
    }
}
