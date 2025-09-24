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
    public let meta: [String: JSONValue]?
    
    public init(kind: AttachmentKind, url: String?, href: String?, lat: Double?, lng: Double?, meta: [String: JSONValue]?) {
        self.kind = kind
        self.url = url
        self.href = href
        self.lat = lat
        self.lng = lng
        self.meta = meta
    }

    public init(kind: AttachmentKind, url: String?, href: String?, lat: Double?, lng: Double?, metaAny: [String: Any]?) {
        self.kind = kind
        self.url = url
        self.href = href
        self.lat = lat
        self.lng = lng
        self.meta = metaAny?.compactMapValues { JSONValue.from(any: $0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case kind
        case url
        case href
        case lat
        case lng
        case meta
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decode(AttachmentKind.self, forKey: .kind)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.href = try container.decodeIfPresent(String.self, forKey: .href)
        self.lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        self.lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        self.meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(href, forKey: .href)
        try container.encodeIfPresent(lat, forKey: .lat)
        try container.encodeIfPresent(lng, forKey: .lng)
        try container.encodeIfPresent(meta, forKey: .meta)
    }
}


extension ServerAttachment {
    init?(dict: [String: Any]) {
        guard let kindRaw = dict["kind"] as? String,
              let kind = AttachmentKind(rawValue: kindRaw) else { return nil }
        self.kind = kind
        self.url = dict["url"] as? String
        self.href = dict["href"] as? String
        self.lat = dict["lat"] as? Double
        self.lng = dict["lng"] as? Double
        if let rawMeta = dict["meta"] as? [String: Any] {
            self.meta = rawMeta.compactMapValues { JSONValue.from(any: $0) }
        } else {
            self.meta = nil
        }
    }

    func toDictionary() -> [String: Any] {
        var result: [String: Any] = ["kind": kind.rawValue]
        if let url { result["url"] = url }
        if let href { result["href"] = href }
        if let lat { result["lat"] = lat }
        if let lng { result["lng"] = lng }
        if let meta { result["meta"] = meta.mapValues { $0.anyValue } }
        return result
    }
}
