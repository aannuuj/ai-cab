import Foundation

public struct PlannedNotification: Hashable, Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case word, streakSaver, comeback, trialEnding
    }

    public var id: String
    public var kind: Kind
    public var fireDate: Date
    public var title: String
    public var body: String
    public var termId: String?
    public var deepLink: String
}

/// Turns reminder settings into concrete local notifications.
/// The app re-plans on every foreground, so the schedule always reflects today's progress.
public struct NotificationPlanner: Sendable {
    /// iOS keeps at most 64 pending requests per app; leave headroom for the trial reminder.
    public static let maxPending = 56
    public static let streakSaverMinute = 20 * 60 + 30
    public static let comebackDays = 3

    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Evenly spaced minutes-after-midnight inside the user's window.
    public func wordTimes(for settings: ReminderSettings) -> [Int] {
        let count = max(1, min(settings.perDay, ReminderSettings.perDayRange.upperBound))
        let start = settings.startMinute
        let end = max(settings.endMinute, start)
        guard count > 1 else { return [start] }
        let step = Double(end - start) / Double(count - 1)
        return (0..<count).map { start + Int((Double($0) * step).rounded()) }
    }

    public struct Context: Sendable {
        public var settings: ReminderSettings
        public var words: [Term]
        public var level: Level
        public var now: Date
        public var savedToday: Int
        public var dailyGoal: Int
        public var streak: Int
        public var days: Int

        public init(settings: ReminderSettings, words: [Term], level: Level, now: Date,
                    savedToday: Int, dailyGoal: Int, streak: Int, days: Int = 7) {
            self.settings = settings
            self.words = words
            self.level = level
            self.now = now
            self.savedToday = savedToday
            self.dailyGoal = dailyGoal
            self.streak = streak
            self.days = days
        }
    }

    public func plan(_ context: Context) -> [PlannedNotification] {
        guard context.settings.isEnabled else { return [] }
        var result: [PlannedNotification] = []
        let today = calendar.startOfDay(for: context.now)

        // Words of the moment.
        var wordIterator = context.words.makeIterator()
        outer: for day in 0..<context.days {
            guard let dayStart = calendar.date(byAdding: .day, value: day, to: today) else { continue }
            for minute in wordTimes(for: context.settings) {
                guard let fire = calendar.date(byAdding: .minute, value: minute, to: dayStart), fire > context.now else { continue }
                guard let term = wordIterator.next() else { break outer }
                result.append(PlannedNotification(
                    id: "word.\(DayKey.string(for: fire, calendar: calendar)).\(minute)",
                    kind: .word,
                    fireDate: fire,
                    title: term.headline,
                    body: term.definition(at: context.level),
                    termId: term.id,
                    deepLink: "aicab://term/\(term.id)"
                ))
                if result.count >= Self.maxPending - 4 { break outer }
            }
        }

        // Streak saver: tonight if today's goal isn't met yet, and tomorrow night as a safety net.
        for day in 0..<2 {
            guard let dayStart = calendar.date(byAdding: .day, value: day, to: today),
                  let fire = calendar.date(byAdding: .minute, value: Self.streakSaverMinute, to: dayStart),
                  fire > context.now else { continue }
            if day == 0 && context.savedToday >= context.dailyGoal { continue }
            let remaining = day == 0 ? max(context.dailyGoal - context.savedToday, 1) : context.dailyGoal
            let streakAtRisk = day == 0 ? context.streak : context.streak + (context.savedToday >= context.dailyGoal ? 1 : 0)
            let title = streakAtRisk > 0 ? "Keep your \(streakAtRisk)-day streak alive 🔥" : "Your daily words are waiting"
            let noun = remaining == 1 ? "word" : "words"
            result.append(PlannedNotification(
                id: "streak.\(DayKey.string(for: fire, calendar: calendar))",
                kind: .streakSaver,
                fireDate: fire,
                title: title,
                body: "Save \(remaining) more \(noun) to hit today's goal. It takes a minute.",
                termId: nil,
                deepLink: "aicab://words"
            ))
        }

        // Come-back nudge, pushed forward every time the app is opened.
        if let comebackDay = calendar.date(byAdding: .day, value: Self.comebackDays, to: today),
           let fire = calendar.date(byAdding: .minute, value: 18 * 60, to: comebackDay) {
            result.append(PlannedNotification(
                id: "comeback",
                kind: .comeback,
                fireDate: fire,
                title: "New AI words just landed",
                body: "The field moved while you were away. Catch up in a minute a day.",
                termId: nil,
                deepLink: "aicab://words"
            ))
        }

        return Array(result.prefix(Self.maxPending))
    }

    /// Reminder fired a day before a free trial converts.
    public func trialReminder(trialEnds: Date, now: Date) -> PlannedNotification? {
        guard let fire = calendar.date(byAdding: .day, value: -1, to: trialEnds), fire > now else { return nil }
        return PlannedNotification(
            id: "trial.ending",
            kind: .trialEnding,
            fireDate: fire,
            title: "Your free trial ends tomorrow",
            body: "No surprises: cancel anytime in Settings before it renews.",
            termId: nil,
            deepLink: "aicab://profile"
        )
    }
}
