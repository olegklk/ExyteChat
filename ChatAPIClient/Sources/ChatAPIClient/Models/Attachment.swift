public enum AttachmentType: String, Codable, Sendable {
    case image
    case video
    case reaction

    public var title: String {
        switch self {
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .reaction:
            return "Reaction"
        }
    }
}

public struct Attachment: Codable, Identifiable, Hashable, Sendable {
    
    public enum UploadStatus: Codable, Equatable, Hashable, Sendable {
        case uploading
        case uploaded
        case failed

        public func hash(into hasher: inout Hasher) {
            switch self {
                case .uploading:
                hasher.combine("uploading")
                case .uploaded:
                    hasher.combine("uploaded")
                case .failed:
                    hasher.combine("failed")
            }
        }
    }
    
    public let id: String
    public let url: URL?
    public let type: AttachmentType
    public let thumbnail: URL?
    public let status: UploadStatus
    public let thumbnailCacheKey: String?
    public let fullCacheKey: String?

    public init(id: String, url: URL?, type: AttachmentType, thumbnail: URL? = nil, status: UploadStatus, thumbnailCacheKey: String? = nil, fullCacheKey: String? = nil) {
        self.id = id
        self.url = url
        self.type = type
        self.thumbnail = thumbnail
        self.status = status
        self.thumbnailCacheKey = thumbnailCacheKey
        self.fullCacheKey = fullCacheKey
    }
    
    // Helper initializer for reaction attachments
    public init(reactionEmoji: String) {
        self.id = UUID().uuidString
        self.url = URL(string: "data://reaction/\(reactionEmoji)") // Dummy URL
        self.type = .reaction
        self.thumbnail = nil
        self.status = .uploaded
        self.thumbnailCacheKey = nil
        self.fullCacheKey = nil
    }

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "status": status.rawValue
        ]
        if let url = url?.absoluteString {
            dict["url"] = url
        }
        if let thumbnail = thumbnail?.absoluteString {
            dict["thumbnail"] = thumbnail
        }
        return dict
    }
}
