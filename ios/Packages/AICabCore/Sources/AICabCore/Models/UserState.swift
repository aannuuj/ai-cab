import Foundation

/// Everything the app knows about one learner. Persisted as a single JSON document.
public struct UserState: Codable, Sendable {
    public var schemaVersion: Int = 1
    public var progress: [String: TermProgress] = [:]
    public var collections: [UserCollection] = []
    public var customTerms: [Term] = []
    public var history: [HistoryEntry] = []
    public var journey = JourneyProgress()
    public var preferences = Preferences()
    public var activity = ActivityLog()
    public var nudges: NudgeState
    public var dailyQuiz: DailyQuizRecord?

    public init(now: Date = Date()) {
        nudges = NudgeState(installedAt: now)
    }

    public static let historyLimit = 500

    public func progress(for termId: String) -> TermProgress {
        progress[termId] ?? TermProgress(termId: termId)
    }

    public mutating func update(_ termId: String, _ body: (inout TermProgress) -> Void) {
        var p = progress(for: termId)
        body(&p)
        progress[termId] = p
    }

    public var favoriteIds: [String] {
        progress.values.filter(\.isFavorite).sorted { ($0.lastSeenAt ?? .distantPast) > ($1.lastSeenAt ?? .distantPast) }.map(\.termId)
    }

    public var savedIds: [String] {
        progress.values.filter(\.isSaved).sorted { ($0.savedAt ?? .distantPast) > ($1.savedAt ?? .distantPast) }.map(\.termId)
    }

    public var learnedCount: Int { progress.values.filter(\.isSaved).count }
    public var masteredCount: Int { progress.values.filter(\.isMastered).count }
}

public struct TermProgress: Codable, Hashable, Sendable {
    public var termId: String
    public var seenCount: Int = 0
    public var firstSeenAt: Date?
    public var lastSeenAt: Date?
    public var isFavorite: Bool = false
    /// "Saved" = added to your learning deck; counts toward the daily goal and enters spaced repetition.
    public var isSaved: Bool = false
    public var savedAt: Date?
    /// Leitner box. 0 = not in review, 1...5 = increasing intervals.
    public var box: Int = 0
    public var nextReviewAt: Date?
    public var correct: Int = 0
    public var wrong: Int = 0

    public init(termId: String) { self.termId = termId }

    public var isMastered: Bool { box >= SpacedRepetition.masteredBox }
}

public struct UserCollection: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var termIds: [String]
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, termIds: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.termIds = termIds
        self.createdAt = createdAt
    }
}

public struct HistoryEntry: Codable, Hashable, Sendable {
    public var termId: String
    public var date: Date

    public init(termId: String, date: Date) {
        self.termId = termId
        self.date = date
    }
}

public struct ReminderSettings: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var perDay: Int
    /// Minutes after midnight.
    public var startMinute: Int
    public var endMinute: Int

    public init(isEnabled: Bool = false, perDay: Int = 3, startMinute: Int = 10 * 60, endMinute: Int = 22 * 60) {
        self.isEnabled = isEnabled
        self.perDay = perDay
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public static let perDayRange = 1...10
}

public enum FeedTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case cream, charcoal
    public var id: String { rawValue }
    public var title: String { self == .cream ? "Paper" : "Night" }
}

/// Onboarding self-assessment ("How familiar are you with AI?").
public enum Familiarity: String, Codable, CaseIterable, Identifiable, Sendable {
    case newcomer, user, builder

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newcomer: "I hear the words but don't really get them"
        case .user: "I use AI tools every day"
        case .builder: "I build with or study AI"
        }
    }

    public var suggestedLevel: Level {
        switch self {
        case .newcomer: .beginner
        case .user: .builder
        case .builder: .research
        }
    }
}

public enum Motivation: String, Codable, CaseIterable, Identifiable, Sendable {
    case news, work, build, career, curious

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .news: "Follow the AI news"
        case .work: "Keep up at work"
        case .build: "Build AI products"
        case .career: "Switch into an AI career"
        case .curious: "Just curious"
        }
    }

    public var symbol: String {
        switch self {
        case .news: "newspaper"
        case .work: "briefcase"
        case .build: "hammer"
        case .career: "arrow.up.right"
        case .curious: "sparkles"
        }
    }

    /// Topics pre-selected for this motivation.
    public var suggestedTopicIds: [String] {
        switch self {
        case .news: ["ai-headlines", "how-models-learn", "policy", "business"]
        case .work: ["prompting", "agent-era", "business", "safety"]
        case .build: ["llm-engineering", "agent-era", "rag", "evals"]
        case .career: ["how-models-learn", "llm-engineering", "training", "evals"]
        case .curious: ["how-models-learn", "ai-headlines", "culture", "prompting"]
        }
    }
}

public struct Preferences: Codable, Sendable {
    public var level: Level = .beginner
    /// Topics that feed the Words tab. Empty = everything accessible.
    public var topicIds: [String] = []
    public var dailyGoal: Int = 5
    public var reminders = ReminderSettings()
    public var feedTheme: FeedTheme = .cream
    public var familiarity: Familiarity?
    public var motivation: Motivation?
    public var hasOnboarded: Bool = false
    public var trialReminderEnabled: Bool = true

    public init() {}

    public static let dailyGoalRange = 1...20
}

public struct ActivityLog: Codable, Sendable {
    /// Words saved per day key.
    public var savedByDay: [String: Int] = [:]
    /// Days with any learning activity.
    public var activeDays: Set<String> = []

    public init() {}

    public func goalMetDays(goal: Int) -> Set<String> {
        Set(savedByDay.filter { $0.value >= goal }.map(\.key))
    }
}

public struct JourneyProgress: Codable, Sendable {
    public var completed: Set<String> = []
    public var bestScores: [String: Double] = [:]

    public init() {}

    public static func key(chapter: Int, lesson: LessonKind) -> String { "c\(chapter).\(lesson.rawValue)" }

    public func isCompleted(chapter: Int, lesson: LessonKind) -> Bool {
        completed.contains(Self.key(chapter: chapter, lesson: lesson))
    }
}

public struct DailyQuizRecord: Codable, Sendable {
    public var dayKey: String
    public var correct: Int
    public var total: Int

    public init(dayKey: String, correct: Int, total: Int) {
        self.dayKey = dayKey
        self.correct = correct
        self.total = total
    }
}

/// Bookkeeping for a single kind of in-app prompt.
public struct PromptRecord: Codable, Sendable {
    public var shownCount: Int = 0
    public var lastShownAt: Date?
    public var snoozedUntil: Date?
    /// The user acted on it (rated, installed, subscribed) — never show again.
    public var isResolved: Bool = false

    public init() {}

    public func isSnoozed(at now: Date) -> Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > now
    }
}

public struct NudgeState: Codable, Sendable {
    public var installedAt: Date
    public var sessionCount: Int = 0
    public var lastActiveAt: Date?
    public var lastNudgeAt: Date?
    public var review = PromptRecord()
    public var widget = PromptRecord()
    public var paywall = PromptRecord()
    public var journeyIntroSeen: Bool = false
    public var celebratedDays: Set<String> = []

    public init(installedAt: Date) { self.installedAt = installedAt }
}
