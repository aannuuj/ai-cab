import Foundation
import AICabCore

/// Launch with `-screenshot <screen>` to open a seeded, deterministic state (used by CI and for
/// App Store screenshots). Never active in normal launches.
enum ScreenshotMode {
    enum Screen: String {
        case onboarding, words, topics, journey, practice, profile, paywall, widget, term, share, quiz
        case tailor, streak, themes, icons
        case toast, coach, challenge, flashcards, levelTest, voices
    }

    static let current: Screen? = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screenshot"), args.indices.contains(index + 1) else { return nil }
        return Screen(rawValue: args[index + 1])
    }()

    static func seededState(for screen: Screen, content: ContentPack, now: Date = Date(), calendar: Calendar = .current) -> UserState {
        var state = UserState(now: now)
        guard ![.onboarding, .tailor, .streak, .themes, .icons].contains(screen) else { return state }
        state.preferences.hasOnboarded = true
        state.preferences.level = .builder
        state.preferences.familiarity = .user
        state.preferences.motivation = .build
        state.preferences.reminders = ReminderSettings(isEnabled: true, perDay: 3)
        state.nudges.sessionCount = 1

        let saved = ["rag", "token", "hallucination", "context-window", "agent", "embedding", "fine-tuning", "mcp"]
        for (offset, id) in saved.enumerated() {
            let date = calendar.date(byAdding: .day, value: -(offset / 2), to: now) ?? now
            state.update(id) { p in
                p.isSaved = true
                p.savedAt = date
                p.seenCount = 2
                p.lastSeenAt = date
                p.box = offset % 3 + 1
                p.nextReviewAt = calendar.date(byAdding: .day, value: offset % 2 == 0 ? -1 : 2, to: now)
                p.isFavorite = offset % 3 == 0
            }
            state.history.append(HistoryEntry(termId: id, date: date))
        }
        for day in 1...4 {
            if let date = calendar.date(byAdding: .day, value: -day, to: now) {
                state.activity.savedByDay[DayKey.string(for: date, calendar: calendar)] = 5
            }
        }
        state.activity.savedByDay[DayKey.string(for: now, calendar: calendar)] = 3
        for lesson in [LessonKind.learn, .use, .match] {
            state.journey.completed.insert(JourneyProgress.key(chapter: 1, lesson: lesson))
        }
        state.collections = [UserCollection(name: "Agent design review", termIds: ["agent", "mcp", "rag"])]
        state.challengeBests = ["sprint": 14, "rush": 9]
        if screen != .coach { state.preferences.seenTips = ["save5"] }
        return state
    }
}

/// Scheduler that never prompts or schedules (screenshot runs, previews).
struct NoopNotificationScheduler: NotificationScheduling {
    func authorization() async -> NotificationAuthorization { .authorized }
    func requestAuthorization() async -> Bool { true }
    func replacePending(with plan: [PlannedNotification]) async {}
}
