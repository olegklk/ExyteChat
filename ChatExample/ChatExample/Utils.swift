import Foundation

func combineUUIDs(_ uuid1: UUID, _ uuid2: UUID) -> String {
    var uuid1Bytes = [UInt8](repeating: 0, count: 16)
    var uuid2Bytes = [UInt8](repeating: 0, count: 16)
    
    // Конвертируем UUID в байты
    uuid1.uuid.withUnsafeBytes { ptr in
        _ = ptr.copyBytes(to: &uuid1Bytes)
    }
    uuid2.uuid.withUnsafeBytes { ptr in
        _ = ptr.copyBytes(to: &uuid2Bytes)
    }
    
    // Объединяем и кодируем в base64
    let combinedBytes = uuid1Bytes + uuid2Bytes
    let combinedData = Data(combinedBytes)
    return combinedData.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func splitUUIDs(_ combinedString: String) -> (UUID, UUID)? {
    // Восстанавливаем padding и заменяем URL-safe символы
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

// Расширение для создания UUID из Data
extension UUID {
    init?(data: Data) {
        guard data.count == 16 else { return nil }
        self.init(uuid: data.withUnsafeBytes { $0.load(as: uuid_t.self) })
    }
}