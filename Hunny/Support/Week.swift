import Foundation

/// Week math for scoring. Weeks run Monday → Sunday in the device's local time
/// zone, and every "week key" is the yyyy-MM-dd string of that week's Monday.
enum Week {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    static func monday(of date: Date = Date()) -> Date {
        let calendar = isoCalendar
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: date, duration: 0)
        return calendar.startOfDay(for: interval.start)
    }

    static func key(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// Monday of the current week, as a week key.
    static var currentKey: String { key(for: monday()) }

    /// Today as a day key — used for the once-per-day rule on 4× tasks.
    static var todayKey: String { key(for: Date()) }

    /// e.g. "Aug 17 – Aug 23"
    static var rangeLabel: String {
        let start = monday()
        let end = isoCalendar.date(byAdding: .day, value: 6, to: start) ?? start
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}

/// Timestamps Hunny sends to Directus (Directus accepts UTC ISO-8601).
enum ISO {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    static var now: String { formatter.string(from: Date()) }
}
