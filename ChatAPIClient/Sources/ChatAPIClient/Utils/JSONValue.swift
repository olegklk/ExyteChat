import Foundation

public enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self)   { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        }
    }

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func from(any: Any) -> JSONValue? {
        switch any {
        case let v as String: return .string(v)
        case let v as Int:    return .number(Double(v))
        case let v as Double: return .number(v)
        case let v as Float:  return .number(Double(v))
        case let v as Bool:   return .bool(v)
        case let v as [String: Any]:
            var obj: [String: JSONValue] = [:]
            for (k, vv) in v { if let j = from(any: vv) { obj[k] = j } }
            return .object(obj)
        case let v as [Any]:
            return .array(v.compactMap { from(any: $0) })
        case _ as NSNull:
            return .null
        default:
            return nil
        }
    }

    var anyValue: Any {
        switch self {
        case .string(let s): return s
        case .number(let d): return d
        case .bool(let b):   return b
        case .object(let o): return o.mapValues { $0.anyValue }
        case .array(let a):  return a.map { $0.anyValue }
        case .null:          return NSNull()
        }
    }
    
    static func parseDate(_ any: Any?) -> Date? {
        switch any {
        case let s as String:
            if let t = TimeInterval(s) { return Date(timeIntervalSince1970: t) }
            if let d = Self.iso8601WithFractionalSeconds.date(from: s) { return d }
            if let d = Self.iso8601NoFraction.date(from: s) { return d }
            return nil
        case let d as Double:
            return Date(timeIntervalSince1970: d)
        case let i as Int:
            return Date(timeIntervalSince1970: TimeInterval(i))
        default:
            return nil
        }
    }
}
