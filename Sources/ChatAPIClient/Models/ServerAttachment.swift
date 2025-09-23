import Foundation

public struct ServerAttachment: Codable, Hashable, Sendable {
    public let kind: String
    public let url: String?
    public let href: String?
    public let lat: Double?
    public let lng: Double?
    public let meta: [String: Any]?
    
    public init(kind: String, url: String?, href: String?, lat: Double?, lng: Double?, meta: [String: Any]?) {
        self.kind = kind
        self.url = url
        self.href = href
        self.lat = lat
        self.lng = lng
        self.meta = meta
    }
    
    public enum CodingKeys: String, CodingKey {
        case kind
        case url
        case href
        case lat
        case lng
        case meta
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.href = try container.decodeIfPresent(String.self, forKey: .href)
        self.lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        self.lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        
        if let metaValue = try container.decodeIfPresent([String: Any].self, forKey: .meta) {
            self.meta = metaValue
        } else {
            self.meta = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(href, forKey: .href)
        try container.encodeIfPresent(lat, forKey: .lat)
        try container.encodeIfPresent(lng, forKey: .lng)
        try container.encodeIfPresent(meta, forKey: .meta)
    }
}
