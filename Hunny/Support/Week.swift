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

/// Month math for the monthly race in the score header and its history
/// sheet. A point counts toward the month it was *earned* in (`completed_on`
/// day key / `claimed_at` instant), so the first days of a month can still
/// belong to a week that started in the previous one.
enum Month {
    /// How far back the monthly history reaches, current month included.
    static let historyDepth = 6

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    /// First instant of the month containing `date`, local time. Anchoring
    /// on the 1st keeps the month arithmetic overflow-proof.
    static func start(of date: Date = Date()) -> Date {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: comps) ?? date
    }

    /// First instant of the month `monthsAgo` months before this one.
    static func start(monthsAgo: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -monthsAgo, to: start()) ?? start()
    }

    /// "yyyy-MM" for the month containing `date`.
    static func key(of date: Date) -> String { keyFormatter.string(from: date) }

    /// "yyyy-MM" — prefix of every day key in the current month.
    static var key: String { key(of: Date()) }

    /// Month keys for the history sheet, current month first.
    static var historyKeys: [String] {
        (0..<historyDepth).map { key(of: start(monthsAgo: $0)) }
    }

    /// e.g. "Sep 2026" for a "yyyy-MM" key.
    static func label(forKey monthKey: String) -> String {
        guard let date = keyFormatter.date(from: monthKey) else { return monthKey }
        return monthFormatter.string(from: date)
    }

    /// Day keys are "yyyy-MM-dd", so a prefix match is a month match.
    static func contains(_ dayKey: String, _ monthKey: String) -> Bool {
        dayKey.hasPrefix(monthKey)
    }

    static func contains(_ instant: Date, _ monthKey: String) -> Bool {
        key(of: instant) == monthKey
    }

    /// Monday of the week the month containing `date` starts in — the
    /// earliest `week_start` the monthly data pull needs.
    static func firstMondayKey(for date: Date = Date()) -> String {
        Week.key(for: Week.monday(of: start(of: date)))
    }

    /// e.g. "Oct 1" — where the monthly race resets.
    static var resetsLabel: String {
        let next = Calendar.current.date(byAdding: .month, value: 1, to: start()) ?? start()
        return shortDateFormatter.string(from: next)
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

    /// Any instant as a Directus timestamp string — used for server-side
    /// `claimed_at` range filters.
    static func stamp(_ date: Date) -> String { formatter.string(from: date) }
}
