import Foundation

public struct StreakDay: Hashable, Identifiable, Sendable {
    public var date: Date
    public var key: String
    public var label: String
    public var isToday: Bool
    public var isComplete: Bool
    public var isFuture: Bool

    public var id: String { key }
}

/// A day counts toward the streak when the daily goal (words saved) was met.
public enum Streak {
    /// Consecutive goal days ending today — or yesterday, so the streak survives until tonight.
    public static func current(goalMetDays: Set<String>, today: Date, calendar: Calendar = .current) -> Int {
        var day = today
        if !goalMetDays.contains(DayKey.string(for: day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while goalMetDays.contains(DayKey.string(for: day, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    public static func longest(goalMetDays: Set<String>, calendar: Calendar = .current) -> Int {
        let dates = goalMetDays.compactMap { DayKey.date(from: $0, calendar: calendar) }.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for date in dates {
            if let previous, let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: date) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = date
        }
        return best
    }

    /// The seven days of the current week, for the streak card's day dots.
    public static func week(goalMetDays: Set<String>, today: Date, calendar: Calendar = .current) -> [StreakDay] {
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? calendar.startOfDay(for: today)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = "EEE"
        let todayStart = calendar.startOfDay(for: today)
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = DayKey.string(for: date, calendar: calendar)
            return StreakDay(
                date: date,
                key: key,
                label: formatter.string(from: date),
                isToday: calendar.isDate(date, inSameDayAs: today),
                isComplete: goalMetDays.contains(key),
                isFuture: date > todayStart
            )
        }
    }
}
