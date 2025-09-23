import Foundation

public struct ServerAttachment: Codable, Hashable, Sendable {
    public enum AttachmentKind: String, Codable, Sendable {
        case gif
        case location
        case file
        case image
    }
    
    public let kind: AttachmentKind
    public let url: String?
    public let href: String?
    public let lat: Double?
    public let lng: Double?
    public let meta: [String: Any]?
    
    public init(kind: AttachmentKind, url: String? = nil, href: String? = nil, lat: Double? = nil, lng: Double? = nil, meta: [String: Any]? = nil) {
        self.kind = kind
        self.url = url
        self.href = href
        self.lat = lat
        self.lng = lng
        self.meta = meta
    }
    
    public func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["kind"] = kind.rawValue
        
        if let url = url {
            dict["url"] = url
        }
        
        if let href = href {
            dict["href"] = href
        }
        
        if let lat = lat {
            dict["lat"] = lat
        }
        
        if let lng = lng {
            dict["lng"] = lng
        }
        
        if let meta = meta {
            dict["meta"] = meta
        }
        
        return dict
    }
}
