import Foundation

public struct SenderRef: Codable, Hashable, Sendable {
    public let userId: String
    public let displayName: String
    
    public init(userId: String, displayName: String) {
        self.userId = userId
        self.displayName = displayName
    }
}
