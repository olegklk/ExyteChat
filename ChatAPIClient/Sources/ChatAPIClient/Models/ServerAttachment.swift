import Foundation
/*{
 “id”: “att_unique_id”,
 “kind”: “image”,
 “meta”: {
   “images”: [
     {
       “url”: “https://cdn.example.com/image.jpg”,
       “alt”: “optional description”,
       “expiresAt”: null
     }
   ]
 }
}*/
public struct ServerAttachment: Codable, Hashable, Sendable {
    public enum AttachmentKind: String, Codable, Sendable {
        case gif
        case location
        case file
        case image
        case reaction
    }

    public let id: String
    public let kind: AttachmentKind
    public let href: String?
    public let lat: Double?
    public let lng: Double?
    public let meta: [String: JSONValue]?
    
    public init(id: String, kind: AttachmentKind, href: String?, lat: Double?, lng: Double?, meta: [String: JSONValue]?) {
        self.id = id
        self.kind = kind
        self.href = href
        self.lat = lat
        self.lng = lng
        self.meta = meta
    }

    public init(id: String, kind: AttachmentKind, href: String?, lat: Double?, lng: Double?, metaAny: [String: Any]?) {
        self.id = id
        self.kind = kind
        self.href = href
        self.lat = lat
        self.lng = lng
        self.meta = metaAny?.compactMapValues { JSONValue.from(any: $0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case href
        case lat
        case lng
        case meta
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.kind = try container.decode(AttachmentKind.self, forKey: .kind)
        self.href = try container.decodeIfPresent(String.self, forKey: .href)
        self.lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        self.lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        self.meta = try container.decodeIfPresent([String: JSONValue].self, forKey: .meta)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encodeIfPresent(href, forKey: .href)
        try container.encodeIfPresent(lat, forKey: .lat)
        try container.encodeIfPresent(lng, forKey: .lng)
        try container.encodeIfPresent(meta, forKey: .meta)
    }
        
}


extension ServerAttachment {
    public var url: String? {
        // Prefer extracting URL from `meta` in supported shapes:
        // 1) meta["url"] as .string
        // 2) meta["images"] as .array of .object each having "url": .string
        // 3) meta["files"] as .array of .object each having "url": .string
        guard let meta = meta else { return nil }

        if case let .string(u)? = meta["url"] {
            return u
        }

        if case let .array(items)? = meta["images"] {
            for item in items {
                if case let .object(obj) = item, case let .string(u)? = obj["url"] {
                    return u
                }
            }
        }

        if case let .array(items)? = meta["files"] {
            for item in items {
                if case let .object(obj) = item, case let .string(u)? = obj["url"] {
                    return u
                }
            }
        }

        return nil
    }
    
    init?(dict: [String: Any]) {
        guard let kindRaw = dict["kind"] as? String,
              let kind = AttachmentKind(rawValue: kindRaw) else { return nil }
        self.kind = kind
        self.id = dict["id"] as! String
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
        result["id"] = id        
        if let href { result["href"] = href }
        if let lat { result["lat"] = lat }
        if let lng { result["lng"] = lng }
        if let meta { result["meta"] = meta.mapValues { $0.anyValue } }
        return result
    }
}
