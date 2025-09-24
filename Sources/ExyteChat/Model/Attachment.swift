//
//  Created by Alex.M on 16.06.2022.
//

import Foundation
import ExyteMediaPicker

public enum AttachmentType: String, Codable, Sendable {
    case image
    case video

    public var title: String {
        switch self {
        case .image:
            return "Image"
        case .video:
            return "Video"
        }
    }

    public init(mediaType: MediaType) {
        switch mediaType {
        case .image:
            self = .image
        case .video:
            self = .video
        default:
            self = .image // Default to image for other media types
        }
    }
    
    public init(serverAttachmentKind: String) {
        switch serverAttachmentKind {
        case "image":
            self = .image
        case "video":
            self = .video
        case "gif":
            self = .image // Treat GIFs as images
        case "file":
            self = .image // Treat files as images for now
        case "location":
            self = .image // Treat locations as images for now
        default:
            self = .image
        }
    }
}

public struct Attachment: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let thumbnail: URL
    public let full: URL
    public let type: AttachmentType
    public let thumbnailCacheKey: String?
    public let fullCacheKey: String?

    public init(id: String, thumbnail: URL, full: URL, type: AttachmentType, thumbnailCacheKey: String? = nil, fullCacheKey: String? = nil) {
        self.id = id
        self.thumbnail = thumbnail
        self.full = full
        self.type = type
        self.thumbnailCacheKey = thumbnailCacheKey
        self.fullCacheKey = fullCacheKey
    }

    public init(id: String, url: URL, type: AttachmentType, cacheKey: String? = nil) {
        self.init(id: id, thumbnail: url, full: url, type: type, thumbnailCacheKey: cacheKey, fullCacheKey: cacheKey)
    }
}
