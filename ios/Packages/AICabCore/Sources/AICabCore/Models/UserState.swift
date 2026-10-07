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
    /// Best score per challenge mode (raw value). Optional so older saves still decode.
    public var challengeBests: [String: Int]?

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

/// Word feed look. Raw values are persisted, so cases are only ever added.
public enum FeedTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case cream, charcoal, sage, tide, ember
    case dusk, mist, ocean, aurora, sand
    case contrast, daylight
    case rose, terminal
    case harvest, moonlit, frost
    case halftone, blossom
    /// The user's own background colour and font (Pro).
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cream: "Paper"
        case .charcoal: "Night"
        case .sage: "Library"
        case .tide: "Tide"
        case .ember: "Ember"
        case .dusk: "Dusk"
        case .mist: "Mist"
        case .ocean: "Ocean"
        case .aurora: "Aurora"
        case .sand: "Sand"
        case .contrast: "Contrast"
        case .daylight: "Daylight"
        case .rose: "Rose"
        case .terminal: "Terminal"
        case .harvest: "Harvest"
        case .moonlit: "Moonlit"
        case .frost: "Frost"
        case .halftone: "Halftone sun"
        case .blossom: "Blossom"
        case .custom: "Your theme"
        }
    }

    public var category: ThemeCategory {
        switch self {
        case .cream, .charcoal, .rose, .terminal: .popular
        case .sage, .tide, .ember, .dusk, .mist, .ocean, .aurora, .sand: .calm
        case .contrast, .daylight: .highVisibility
        case .harvest, .moonlit, .frost: .seasonal
        case .halftone, .blossom: .illustration
        case .custom: .custom
        }
    }

    public var font: FeedFont {
        switch self {
        case .tide, .mist, .aurora, .frost: .sans
        case .contrast, .daylight: .bold
        case .rose: .rounded
        case .terminal: .mono
        case .blossom: .italic
        default: .serif
        }
    }

    /// A handful stay free so everyone can personalise.
    public var isPremium: Bool { ![.cream, .charcoal, .sand, .contrast, .rose].contains(self) }

    /// Shown during onboarding: a small, varied pick.
    public static let onboardingPicks: [FeedTheme] = [.charcoal, .cream, .rose, .dusk, .ocean, .harvest]

    /// Gallery themes (custom is reached through "Create").
    public static var gallery: [FeedTheme] { allCases.filter { $0 != .custom } }
}

public enum ThemeCategory: String, CaseIterable, Identifiable, Sendable {
    case popular, calm, seasonal, highVisibility, illustration, custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .popular: "Staff picks"
        case .calm: "Quiet"
        case .seasonal: "This season"
        case .highVisibility: "High contrast"
        case .illustration: "Drawn"
        case .custom: "Yours"
        }
    }

    /// Gallery order.
    public static let galleryOrder: [ThemeCategory] = [.calm, .seasonal, .illustration, .highVisibility, .popular]
}

/// Typeface family used for the word on a feed theme.
public enum FeedFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case serif, sans, bold, rounded, mono, italic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .serif: "Serif"
        case .sans: "Sans"
        case .bold: "Bold"
        case .rounded: "Rounded"
        case .mono: "Mono"
        case .italic: "Italic"
        }
    }
}

/// "Create" theme: background colour and font.
public struct CustomFeedTheme: Codable, Hashable, Sendable {
    /// 0xRRGGBB.
    public var background: Int
    public var font: FeedFont

    public init(background: Int = 0x2F3A4A, font: FeedFont = .serif) {
        self.background = background
        self.font = font
    }

    /// Relative luminance check so text flips to dark on light backgrounds.
    public var isLight: Bool {
        func channel(_ shift: Int) -> Double {
            let c = Double((background >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        return luminance > 0.4
    }

    public static let swatches: [Int] = [0x2F3A4A, 0x1F2A24, 0x4A2F3A, 0x5B4636, 0x24324F,
                                         0xE9DCC7, 0xDCE7E2, 0xF3D9D4, 0xE4E0F2, 0xF5F1E6]
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

/// Onboarding "What do you do?" — personalises starting level and topics.
public enum Role: String, Codable, CaseIterable, Identifiable, Sendable {
    case student, engineer, product, designer, researcher, other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .student: "Student"
        case .engineer: "Software engineer"
        case .product: "Product manager or founder"
        case .designer: "Designer or marketer"
        case .researcher: "Researcher or data scientist"
        case .other: "Something else"
        }
    }

    public var symbol: String {
        switch self {
        case .student: "graduationcap"
        case .engineer: "chevron.left.forwardslash.chevron.right"
        case .product: "chart.line.uptrend.xyaxis"
        case .designer: "paintbrush.pointed"
        case .researcher: "flask"
        case .other: "sparkles"
        }
    }

    /// Topics added to the motivation's suggestions.
    public var extraTopicIds: [String] {
        switch self {
        case .student: ["how-models-learn"]
        case .engineer: ["llm-engineering", "agent-era"]
        case .product: ["business", "evals"]
        case .designer: ["prompting", "multimodal"]
        case .researcher: ["research-math", "training"]
        case .other: []
        }
    }
}

public enum AgeRange: String, Codable, CaseIterable, Identifiable, Sendable {
    case teen = "13-17", young = "18-24", adult = "25-34", mid = "35-44", senior = "45-54", older = "55+"
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .older: "55+"
        default: rawValue.replacingOccurrences(of: "-", with: " to ")
        }
    }
}

public enum Gender: String, Codable, CaseIterable, Identifiable, Sendable {
    case female, male, other, unspecified
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .other: "Other"
        case .unspecified: "Prefer not to say"
        }
    }
}

/// "What would help make learning a daily habit?"
public enum HabitHelper: String, Codable, CaseIterable, Identifiable, Sendable {
    case progress, quizzes, reminders, widget
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .progress: "Tracking my progress"
        case .quizzes: "Quizzes and games"
        case .reminders: "Regular reminders"
        case .widget: "A home or lock screen widget"
        }
    }
}

/// "Where does AI jargon trip you up?" — maps to starting topics.
public enum WeakSpot: String, Codable, CaseIterable, Identifiable, Sendable {
    case news, meetings, building, papers, confident
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .news: "Reading AI news"
        case .meetings: "In meetings at work"
        case .building: "Building with AI tools"
        case .papers: "Reading research papers"
        case .confident: "Honestly, none of them"
        }
    }
    public var topicIds: [String] {
        switch self {
        case .news: ["ai-headlines", "how-models-learn", "policy"]
        case .meetings: ["business", "agent-era", "prompting"]
        case .building: ["llm-engineering", "rag", "evals"]
        case .papers: ["research-math", "training", "interpretability"]
        case .confident: ["reasoning-models", "agent-era"]
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
    public var role: Role?
    /// Alternate app icon name; nil = default icon.
    public var appIcon: String?
    // Optional, on-device only onboarding answers. Optional so older saved state still decodes.
    public var name: String?
    public var ageRange: AgeRange?
    public var gender: Gender?
    public var habitHelpers: [HabitHelper]?
    public var weakSpots: [WeakSpot]?
    /// Pronunciation voice (AVSpeechSynthesisVoice identifier) and rate multiplier.
    public var voiceIdentifier: String?
    public var speechRate: Double?
    /// One-time coach marks already shown.
    public var seenTips: [String]?
    /// Colours for the `.custom` feed theme.
    public var customTheme: CustomFeedTheme?
    /// Daily practice alarm (AlarmKit), minutes after midnight; nil = off.
    public var alarmMinute: Int?

    public init() {}

    /// Weekly target from onboarding → words saved per day.
    public static func dailyGoal(forWeeklyWords weekly: Int) -> Int {
        max(1, Int((Double(weekly) / 7).rounded(.up)))
    }

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
