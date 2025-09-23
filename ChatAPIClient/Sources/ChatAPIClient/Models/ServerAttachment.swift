import Foundation

public struct ServerAttachment: Codable, Hashable, Sendable {
    public enum AttachmentKind: String, Codable {
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
    
    public init(kind: AttachmentKind, url: String?, href: String?, lat: Double?, lng: Double?, meta: [String: Any]?) {
        self.kind = kind
        self.url = url
        self.href = href
        self.lat = lat
        self.lng = lng
        self.meta = meta
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
        let kindString = try container.decode(String.self, forKey: .kind)
        self.kind = AttachmentKind(rawValue: kindString) ?? .image
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.href = try container.decodeIfPresent(String.self, forKey: .href)
        self.lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        self.lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        
        // Handle meta dictionary decoding
        if let metaDict = try container.decodeIfPresent([String: Any].self, forKey: .meta) {
            self.meta = metaDict
        } else {
            self.meta = nil
        }
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

// MARK: - Dictionary Coding Helper

struct JSONCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    init(key: String) {
        self.stringValue = key
    }
}

extension KeyedDecodingContainer {
    public func decode(_ type: [String: Any].Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [String: Any] {
        let container = try self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        return try container.decode(type)
    }

    public func decodeIfPresent(_ type: [String: Any].Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [String: Any]? {
        guard contains(key) else { return nil }
        let container = try self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        return try container.decode(type)
    }

    public func decode(_ type: [Any].Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [Any] {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        return try container.decode(type)
    }

    public func decodeIfPresent(_ type: [Any].Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [Any]? {
        guard contains(key) else { return nil }
        var container = try self.nestedUnkeyedContainer(forKey: key)
        return try container.decode(type)
    }
    
    public func decode(_ type: [String: Any].Type) throws -> [String: Any] {
        var dictionary = [String: Any]()
        for key in allKeys {
            if let boolValue = try? decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = boolValue
            } else if let intValue = try? decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = intValue
            } else if let stringValue = try? decode(String.self, forKey: key) {
                dictionary[key.stringValue] = stringValue
            } else if let doubleValue = try? decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = doubleValue
            } else if let nestedDictionary = try? decode([String: Any].self, forKey: key) {
                dictionary[key.stringValue] = nestedDictionary
            } else if let nestedArray = try? decode([Any].self, forKey: key) {
                dictionary[key.stringValue] = nestedArray
            }
        }
        return dictionary
    }
}

extension UnkeyedDecodingContainer {
    public mutating func decode(_ type: [Any].Type) throws -> [Any] {
        var array: [Any] = []
        while isAtEnd == false {
            if let value = try? decode(Bool.self) {
                array.append(value)
            } else if let value = try? decode(Int.self) {
                array.append(value)
            } else if let value = try? decode(String.self) {
                array.append(value)
            } else if let value = try? decode(Double.self) {
                array.append(value)
            } else if let nestedDictionary = try? decode([String: Any].self) {
                array.append(nestedDictionary)
            } else if let nestedArray = try? decode([Any].self) {
                array.append(nestedArray)
            }
        }
        return array
    }
    
    public mutating func decode(_ type: [String: Any].Type) throws -> [String: Any] {
        let container = try self.nestedContainer(keyedBy: JSONCodingKeys.self)
        return try container.decode(type)
    }
}
