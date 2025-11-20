//
//  Created by Alex.M on 08.07.2022.
//

import Foundation

extension Date {

    private static let yyyyMMFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // optional: fixing UTC
            return formatter
        }()
        
    /// returns YYYY-MM for a date at monthsAgo back in time
    public static func yyyyMM(monthsAgo: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        guard let pastDate = calendar.date(byAdding: .month, value: -monthsAgo, to: today) else {
            return "Invalid Date"
        }
        
        return yyyyMMFormatter.string(from: pastDate)
    }
    
    // thread-local formatters to avoid shared mutable state across concurrency domains
    private static var iso8601WithFractionalSeconds: ISO8601DateFormatter {
        let key = "JSONValue.iso8601WithFractionalSeconds"
        if let f = Thread.current.threadDictionary[key] as? ISO8601DateFormatter { return f }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        Thread.current.threadDictionary[key] = f
        return f
    }

    private static var iso8601NoFraction: ISO8601DateFormatter {
        let key = "JSONValue.iso8601NoFraction"
        if let f = Thread.current.threadDictionary[key] as? ISO8601DateFormatter { return f }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        Thread.current.threadDictionary[key] = f
        return f
    }
    
    public static func parseDate(_ any: Any?) -> Date? {
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
