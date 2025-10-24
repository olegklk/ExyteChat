//
//  Created by Alex.M on 04.07.2022.
//

import Foundation

extension Date {
    func startOfDay() -> Date {
        Calendar.current.startOfDay(for: self)
    }

    func isSameDay(_ date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
}

extension Date {
    static let iso8601Date = Date.ISO8601FormatStyle.iso8601.year().month().day()
}

@MainActor
class DateFormatting {
    static let agoFormatter = RelativeDateTimeFormatter()
}

extension Date {
    // 1 hour ago, 2 days ago...
    @MainActor func formatAgo() -> String {
        let result = DateFormatting.agoFormatter.localizedString(for: self, relativeTo: Date())
        if result.contains("second") {
            return "Just now"
        }
        return result
    }
}
