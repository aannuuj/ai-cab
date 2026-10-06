import Foundation

/// One word as the widget shows it. Kept tiny: widgets have a strict memory budget.
public struct WidgetWord: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var term: String
    public var pos: String
    public var definition: String
    public var ipa: String?
    public var example: String?

    public init(id: String, term: String, pos: String, definition: String, ipa: String? = nil, example: String? = nil) {
        self.id = id
        self.term = term
        self.pos = pos
        self.definition = definition
        self.ipa = ipa
        self.example = example
    }

    public init(term: Term, level: Level) {
        self.init(id: term.id, term: term.term, pos: term.pos, definition: term.definition(at: level),
                  ipa: term.ipa, example: term.example)
    }
}

/// What the app hands to the widget extension. Widgets never touch the network or the full catalog.
public struct WidgetSnapshot: Codable, Sendable {
    public var generatedAt: Date
    public var words: [WidgetWord]
    public var savedIds: Set<String>
    public var streak: Int
    public var savedToday: Int
    public var dailyGoal: Int
    /// Day key `savedToday` belongs to, so the widget can reset it at midnight.
    public var dayKey: String

    public init(generatedAt: Date, words: [WidgetWord], savedIds: Set<String>, streak: Int,
                savedToday: Int, dailyGoal: Int, dayKey: String) {
        self.generatedAt = generatedAt
        self.words = words
        self.savedIds = savedIds
        self.streak = streak
        self.savedToday = savedToday
        self.dailyGoal = dailyGoal
        self.dayKey = dayKey
    }

    public static let placeholder = WidgetSnapshot(
        generatedAt: Date(timeIntervalSince1970: 0),
        words: [
            WidgetWord(id: "rag", term: "RAG", pos: "n.",
                       definition: "Letting an AI look things up before it answers, like an open-book exam.", ipa: "/ræɡ/",
                       example: "We added RAG so the support bot cites our actual docs."),
            WidgetWord(id: "token", term: "token", pos: "n.",
                       definition: "A small chunk of text, often part of a word, that language models read and write.", ipa: "/ˈtoʊ.kən/"),
            WidgetWord(id: "hallucination", term: "hallucination", pos: "n.",
                       definition: "When an AI states something false with total confidence.", ipa: "/həˌluː.sɪˈneɪ.ʃən/"),
        ],
        savedIds: [],
        streak: 3,
        savedToday: 2,
        dailyGoal: 5,
        dayKey: ""
    )

    public func savedToday(on date: Date, calendar: Calendar = .current) -> Int {
        dayKey == DayKey.string(for: date, calendar: calendar) ? savedToday : 0
    }
}

/// An action taken inside a widget, waiting for the app to merge it into `UserState`.
public struct WidgetInboxItem: Codable, Hashable, Sendable {
    public enum Action: String, Codable, Sendable { case save, unsave }

    public var termId: String
    public var action: Action
    public var date: Date

    public init(termId: String, action: Action, date: Date) {
        self.termId = termId
        self.action = action
        self.date = date
    }
}

/// File-backed exchange between the app and the widget extension.
///
/// The app is the only writer of the snapshot; widget intents only append to the inbox
/// (and update the snapshot optimistically so the tap is reflected instantly).
public struct WidgetStore: Sendable {
    private let snapshotFile: JSONFile<WidgetSnapshot>
    private let inboxFile: JSONFile<[WidgetInboxItem]>
    private let cursorFile: JSONFile<Int>

    public init(directory: URL = SharedContainer.url) {
        snapshotFile = JSONFile(url: directory.appendingPathComponent("widget-snapshot.json"))
        inboxFile = JSONFile(url: directory.appendingPathComponent("widget-inbox.json"))
        cursorFile = JSONFile(url: directory.appendingPathComponent("widget-cursor.json"))
    }

    public func snapshot() -> WidgetSnapshot? { snapshotFile.read() }

    public func write(_ snapshot: WidgetSnapshot) throws {
        try snapshotFile.write(snapshot)
        try? cursorFile.write(0)
    }

    /// Index of the word the widget currently shows; advanced by the "Next" button.
    public func cursor() -> Int { cursorFile.read() ?? 0 }

    public func advanceCursor(by step: Int = 1) {
        try? cursorFile.write(cursor() + step)
    }

    public func toggleSaved(termId: String, now: Date = Date(), calendar: Calendar = .current) {
        guard var snapshot = snapshot() else { return }
        let today = DayKey.string(for: now, calendar: calendar)
        if snapshot.dayKey != today {
            snapshot.dayKey = today
            snapshot.savedToday = 0
        }
        let action: WidgetInboxItem.Action
        if snapshot.savedIds.contains(termId) {
            snapshot.savedIds.remove(termId)
            snapshot.savedToday = max(snapshot.savedToday - 1, 0)
            action = .unsave
        } else {
            snapshot.savedIds.insert(termId)
            snapshot.savedToday += 1
            action = .save
        }
        try? snapshotFile.write(snapshot)
        var inbox = inboxFile.read() ?? []
        inbox.append(WidgetInboxItem(termId: termId, action: action, date: now))
        try? inboxFile.write(inbox)
    }

    /// Returns pending widget actions and clears the inbox.
    public func drainInbox() -> [WidgetInboxItem] {
        let items = inboxFile.read() ?? []
        if !items.isEmpty { inboxFile.delete() }
        return items
    }

    /// The word for a timeline slot, wrapping around the snapshot.
    public static func word(in snapshot: WidgetSnapshot, at index: Int) -> WidgetWord? {
        guard !snapshot.words.isEmpty else { return nil }
        let wrapped = ((index % snapshot.words.count) + snapshot.words.count) % snapshot.words.count
        return snapshot.words[wrapped]
    }
}
