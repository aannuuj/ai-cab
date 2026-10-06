import Foundation
import Observation
import AICabCore

struct HistoryItem: Identifiable {
    let term: Term
    let date: Date
    var id: String { term.id }
}

/// Composition root and single source of truth for the UI.
///
/// Views read derived state from here and call intent methods; all `UserState` writes go through
/// `mutate(_:)`, which persists (debounced) so there is exactly one write path.
@MainActor
@Observable
final class AppModel {
    // MARK: Dependencies

    let purchases: PurchaseManager
    let speech: SpeechService
    let config: AppConfiguration
    let drafter: DefinitionDrafting?
    @ObservationIgnored private let store: UserStateStoring
    @ObservationIgnored private let notifications: NotificationScheduling
    @ObservationIgnored private let widgets: WidgetSyncing
    @ObservationIgnored private let remoteContent: RemoteContentFetching?
    @ObservationIgnored private let contentCache: ContentCache?
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date

    @ObservationIgnored private let feedEngine = FeedEngine()
    @ObservationIgnored private let reminderEngine = FeedEngine(configuration: .init(batchSize: 50, reviewShare: 0, trendingShare: 0.2))
    @ObservationIgnored let journeyEngine = JourneyEngine()
    @ObservationIgnored private let nudgeEngine = NudgeEngine()
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var didStart = false

    // MARK: State

    private(set) var content: ContentPack
    private(set) var state: UserState
    private(set) var feed: [Term] = []
    private(set) var notificationStatus: NotificationAuthorization = .notDetermined
    private(set) var hasWidgetInstalled = true

    var selectedTab: AppTab = .words
    var sheet: AppSheet?
    /// Overlay-style nudges (review card, Journey intro). Sheet-style nudges go through `sheet`.
    var overlayNudge: Nudge?
    /// Bumped to fire the goal celebration.
    private(set) var celebration = 0
    /// Feed position to jump to (deep links, "learn this topic").
    var feedScrollTarget: String?

    @ObservationIgnored private var termIndex: [String: Term] = [:]

    init(
        content: ContentPack,
        store: UserStateStoring,
        notifications: NotificationScheduling,
        widgets: WidgetSyncing,
        purchases: PurchaseManager,
        speech: SpeechService,
        config: AppConfiguration,
        remoteContent: RemoteContentFetching? = nil,
        contentCache: ContentCache? = nil,
        drafter: DefinitionDrafting? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.content = content
        self.store = store
        self.notifications = notifications
        self.widgets = widgets
        self.purchases = purchases
        self.speech = speech
        self.config = config
        self.remoteContent = remoteContent
        self.contentCache = contentCache
        self.drafter = drafter
        self.calendar = calendar
        self.now = now
        self.state = store.load() ?? UserState(now: now())
        rebuildIndex()
    }

    /// Production wiring.
    static func live() -> AppModel {
        let config = AppConfiguration.current
        let cache = ContentCache()
        let bundled = (try? ContentLoader.bundled()) ?? .empty
        if let screen = ScreenshotMode.current {
            return screenshot(screen, content: bundled, config: config)
        }
        let content = ContentLoader.newest(bundled: bundled, cached: cache.load())
        return AppModel(
            content: content,
            store: FileUserStateStore(),
            notifications: UserNotificationScheduler(),
            widgets: WidgetKitSync(store: WidgetStore()),
            purchases: PurchaseManager(),
            speech: SpeechService(),
            config: config,
            remoteContent: config.contentManifestURL.map { RemoteContentClient(manifestURL: $0, appBuild: config.build) },
            contentCache: cache,
            drafter: config.defineEndpoint.map { RemoteDefinitionDrafter(endpoint: $0) }
        )
    }

    /// Deterministic, seeded wiring for `-screenshot <screen>` launches.
    private static func screenshot(_ screen: ScreenshotMode.Screen, content: ContentPack, config: AppConfiguration) -> AppModel {
        let model = AppModel(
            content: content,
            store: InMemoryUserStateStore(state: ScreenshotMode.seededState(for: screen, content: content)),
            notifications: NoopNotificationScheduler(),
            widgets: WidgetKitSync(store: WidgetStore()),
            purchases: PurchaseManager(),
            speech: SpeechService(),
            config: config
        )
        model.isScreenshotRun = true
        if let rag = content.terms.first(where: { $0.id == "context-engineering" }) {
            model.feed = [rag]
        }
        switch screen {
        case .onboarding, .words, .tailor, .streak, .themes, .icons: break
        case .topics: model.selectedTab = .topics
        case .journey: model.selectedTab = .journey
        case .practice, .quiz: model.selectedTab = .practice
        case .profile: model.selectedTab = .profile
        case .paywall: model.sheet = .paywall(.crown)
        case .widget: model.sheet = .widgetInstall
        case .term: model.sheet = .term("rag")
        case .share: model.sheet = .share("rag")
        }
        return model
    }

    @ObservationIgnored private(set) var isScreenshotRun = false

    // MARK: - Derived state

    var isPro: Bool { purchases.isPro }
    var preferences: Preferences { state.preferences }
    var todayKey: String { DayKey.string(for: now(), calendar: calendar) }
    var savedToday: Int { state.activity.savedByDay[todayKey] ?? 0 }
    var dailyGoal: Int { state.preferences.dailyGoal }
    var goalMetToday: Bool { savedToday >= dailyGoal }
    var goalMetDays: Set<String> { state.activity.goalMetDays(goal: dailyGoal) }
    var streak: Int { Streak.current(goalMetDays: goalMetDays, today: now(), calendar: calendar) }
    var longestStreak: Int { Streak.longest(goalMetDays: goalMetDays, calendar: calendar) }
    var week: [StreakDay] { Streak.week(goalMetDays: goalMetDays, today: now(), calendar: calendar) }

    /// Research definitions are Pro; free users silently fall back to Builder.
    var level: Level {
        let chosen = state.preferences.level
        return chosen.isPremium && !isPro ? .builder : chosen
    }

    var allTerms: [Term] { content.terms + state.customTerms }
    var topics: [Topic] { content.topics.sorted { $0.order < $1.order } }
    var chapters: [Chapter] { content.chapters.sorted { $0.number < $1.number } }

    func term(_ id: String) -> Term? { termIndex[id] }
    func progress(_ id: String) -> TermProgress { state.progress(for: id) }
    func isSaved(_ id: String) -> Bool { state.progress[id]?.isSaved ?? false }
    func isFavorite(_ id: String) -> Bool { state.progress[id]?.isFavorite ?? false }

    func topics(in section: TopicSection) -> [Topic] { topics.filter { $0.section == section } }
    func terms(in topic: Topic) -> [Term] {
        content.terms.filter { $0.topics.contains(topic.id) }.sorted { $0.difficulty.rawValue < $1.difficulty.rawValue }
    }
    func isLocked(_ topic: Topic) -> Bool { topic.isPremium && !isPro }
    func isLocked(_ term: Term) -> Bool { term.isPremium && !isPro }

    var favorites: [Term] { state.favoriteIds.compactMap(term) }
    var savedTerms: [Term] { state.savedIds.compactMap(term) }
    var dueReviews: [Term] { SpacedRepetition.dueIds(in: state, now: now()).compactMap(term) }

    /// Most recent first, one entry per term.
    var history: [HistoryItem] {
        var seen = Set<String>()
        return state.history.reversed().compactMap { entry in
            guard seen.insert(entry.termId).inserted, let found = self.term(entry.termId) else { return nil }
            return HistoryItem(term: found, date: entry.date)
        }
    }

    var dailyQuizDoneToday: Bool { state.dailyQuiz?.dayKey == todayKey }

    var journeyCurrent: (chapter: Chapter, lesson: LessonKind)? {
        journeyEngine.current(chapters: chapters, progress: state.journey, isPro: isPro)
    }

    var showJourneyBadge: Bool { !state.nudges.journeyIntroSeen && state.journey.completed.isEmpty }

    // MARK: - Lifecycle

    func start() async {
        guard !didStart else { return }
        didStart = true
        UserNotificationScheduler.registerCategories()
        mutate {
            $0.nudges.sessionCount += 1
            $0.nudges.lastActiveAt = now()
        }
        ensureFeed()
        await purchases.start()
        await refreshSystemState()
        syncWidgets()
        await rescheduleNotifications()
        await refreshRemoteContent()
    }

    func sceneDidBecomeActive() async {
        guard didStart else { return }
        if let last = state.nudges.lastActiveAt, now().timeIntervalSince(last) > 30 * 60 {
            mutate { $0.nudges.sessionCount += 1 }
        }
        mutate { $0.nudges.lastActiveAt = now() }
        await refreshSystemState()
        syncWidgets()
        await rescheduleNotifications()
        try? await Task.sleep(for: .seconds(1.2))
        evaluateNudges(justCompletedGoal: false)
    }

    func sceneDidEnterBackground() async {
        persistNow()
        syncWidgets()
        await rescheduleNotifications()
    }

    private func refreshSystemState() async {
        mergeWidgetInbox()
        notificationStatus = await notifications.authorization()
        hasWidgetInstalled = await widgets.installedWidgetCount() > 0
        if hasWidgetInstalled, !state.nudges.widget.isResolved {
            mutate { $0.nudges.widget.isResolved = true }
        }
    }

    private func refreshRemoteContent() async {
        guard let remoteContent else { return }
        guard let pack = try? await remoteContent.fetchPack(newerThan: content.version) else { return }
        try? contentCache?.save(pack)
        content = pack
        rebuildIndex()
    }

    private func rebuildIndex() {
        termIndex = Dictionary(allTerms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Persistence

    func mutate(_ body: (inout UserState) -> Void) {
        body(&state)
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.persistNow()
        }
    }

    func persistNow() {
        saveTask?.cancel()
        try? store.save(state)
    }

    // MARK: - Feed

    func ensureFeed() {
        if feed.isEmpty { feed = feedEngine.batch(from: allTerms, state: state, isPro: isPro, now: now(), using: &rng) }
    }

    func regenerateFeed() {
        feed = feedEngine.batch(from: allTerms, state: state, isPro: isPro, now: now(), using: &rng)
        feedScrollTarget = feed.first?.id
        syncWidgets()
    }

    /// Called as the reader swipes; tops up the feed before it runs out.
    func didShow(_ term: Term) {
        markSeen(term)
        guard let index = feed.firstIndex(where: { $0.id == term.id }), index >= feed.count - 6 else { return }
        let recent = Set(feed.suffix(60).map(\.id))
        let more = feedEngine.batch(from: allTerms, state: state, isPro: isPro, now: now(), excluding: recent, using: &rng)
        feed.append(contentsOf: more.isEmpty ? allTerms.filter { !isLocked($0) }.shuffled(using: &rng).prefix(20) : more[...])
    }

    /// Puts a specific term on screen in the Words tab (deep link, search result, topic).
    func show(termID: String) {
        guard let term = term(termID) else { return }
        if isLocked(term) {
            sheet = .paywall(.lockedTopic)
            return
        }
        if !feed.contains(where: { $0.id == termID }) {
            feed.insert(term, at: 0)
        }
        selectedTab = .words
        feedScrollTarget = termID
    }

    /// Focuses the feed on one topic's words.
    func learn(topic: Topic) {
        guard !isLocked(topic) else {
            sheet = .paywall(.lockedTopic)
            return
        }
        let words = terms(in: topic).filter { !isSaved($0.id) }.shuffled(using: &rng)
        feed = Array((words.isEmpty ? terms(in: topic) : words).prefix(30))
        selectedTab = .words
        feedScrollTarget = feed.first?.id
    }

    // MARK: - Word actions

    func markSeen(_ term: Term) {
        let date = now()
        mutate { s in
            s.update(term.id) { p in
                p.seenCount += 1
                if p.firstSeenAt == nil { p.firstSeenAt = date }
                p.lastSeenAt = date
            }
            if s.history.last?.termId != term.id {
                s.history.append(HistoryEntry(termId: term.id, date: date))
                if s.history.count > UserState.historyLimit { s.history.removeFirst(s.history.count - UserState.historyLimit) }
            }
            s.activity.activeDays.insert(DayKey.string(for: date, calendar: calendar))
        }
    }

    func toggleFavorite(_ term: Term) {
        mutate { s in s.update(term.id) { $0.isFavorite.toggle() } }
    }

    func toggleSave(_ term: Term) {
        setSaved(!isSaved(term.id), termID: term.id, at: now())
        syncWidgets()
    }

    private func setSaved(_ saved: Bool, termID: String, at date: Date) {
        let wasMet = goalMetToday
        let dayKey = DayKey.string(for: date, calendar: calendar)
        mutate { s in
            var p = s.progress(for: termID)
            guard p.isSaved != saved else { return }
            p.isSaved = saved
            if saved {
                p.savedAt = date
                SpacedRepetition.enroll(&p, now: date, calendar: calendar)
                s.activity.savedByDay[dayKey, default: 0] += 1
                s.activity.activeDays.insert(dayKey)
            } else {
                if let savedAt = p.savedAt {
                    let savedKey = DayKey.string(for: savedAt, calendar: calendar)
                    if let count = s.activity.savedByDay[savedKey], count > 0 {
                        s.activity.savedByDay[savedKey] = count - 1
                    }
                }
                p.savedAt = nil
                SpacedRepetition.unenroll(&p)
            }
            s.progress[termID] = p
        }
        if !wasMet, goalMetToday, !state.nudges.celebratedDays.contains(todayKey) {
            let key = todayKey
            mutate { $0.nudges.celebratedDays.insert(key) }
            celebration += 1
            Task {
                try? await Task.sleep(for: .seconds(2.6))
                evaluateNudges(justCompletedGoal: true)
                await rescheduleNotifications()
            }
        }
    }

    /// Applies saves queued outside the UI (notification actions) if the app is already running.
    func applyExternalSaves() {
        guard didStart else { return }
        mergeWidgetInbox()
        syncWidgets()
    }

    private func mergeWidgetInbox() {
        for item in widgets.drainInbox() {
            setSaved(item.action == .save, termID: item.termId, at: item.date)
        }
    }

    // MARK: - Practice & Journey

    func quizPool() -> [Term] { content.terms.filter { !isLocked($0) } }

    func recordAnswer(termID: String, correct: Bool) {
        let date = now()
        mutate { s in
            s.update(termID) { p in
                if p.box > 0 {
                    SpacedRepetition.record(&p, correct: correct, now: date, calendar: calendar)
                } else if correct {
                    p.correct += 1
                } else {
                    p.wrong += 1
                }
            }
            s.activity.activeDays.insert(DayKey.string(for: date, calendar: calendar))
        }
    }

    func completeDailyQuiz(correct: Int, total: Int) {
        let key = todayKey
        mutate { $0.dailyQuiz = DailyQuizRecord(dayKey: key, correct: correct, total: total) }
    }

    @discardableResult
    func completeLesson(_ lesson: LessonKind, chapter: Chapter, correct: Int, total: Int) -> Bool {
        var passed = false
        mutate { s in
            passed = journeyEngine.record(correct: correct, total: total, lesson: lesson, chapter: chapter.number, progress: &s.journey)
            s.nudges.journeyIntroSeen = true
        }
        if lesson == .learn {
            for id in chapter.termIds { if let t = term(id) { markSeen(t) } }
        }
        return passed
    }

    func lessonStatus(_ lesson: LessonKind, in chapter: Chapter) -> LessonStatus {
        journeyEngine.status(of: lesson, in: chapter, chapters: chapters, progress: state.journey, isPro: isPro)
    }

    func isUnlocked(_ chapter: Chapter) -> Bool {
        journeyEngine.isChapterUnlocked(chapter, in: chapters, progress: state.journey, isPro: isPro)
    }

    func questions(for lesson: LessonKind, in chapter: Chapter) -> [QuizQuestion] {
        journeyEngine.questions(for: lesson, chapter: chapter, terms: termIndex, pool: quizPool(), level: level, using: &rng)
    }

    func quiz(for targets: [Term], count: Int) -> [QuizQuestion] {
        QuizGenerator(level: level).quiz(for: targets.shuffled(using: &rng), pool: quizPool(), count: count, using: &rng)
    }

    /// Daily quiz: due reviews first, then saved words, then recently seen ones.
    func dailyQuizQuestions() -> [QuizQuestion] {
        var targets = dueReviews
        targets += savedTerms.filter { t in !targets.contains(where: { $0.id == t.id }) }
        targets += history.map(\.term).filter { t in !targets.contains(where: { $0.id == t.id }) }
        if targets.count < 3 { targets += quizPool().shuffled(using: &rng).prefix(6) }
        return QuizGenerator(level: level).quiz(for: Array(targets.prefix(12)).shuffled(using: &rng), pool: quizPool(), count: 3, using: &rng)
    }

    // MARK: - Preferences

    func setLevel(_ level: Level) {
        if level.isPremium && !isPro {
            sheet = .paywall(.researchLevel)
            return
        }
        mutate { $0.preferences.level = level }
        syncWidgets()
    }

    func setTopics(_ ids: [String]) {
        mutate { $0.preferences.topicIds = ids }
        regenerateFeed()
    }

    func setDailyGoal(_ goal: Int) {
        mutate { $0.preferences.dailyGoal = min(max(goal, Preferences.dailyGoalRange.lowerBound), Preferences.dailyGoalRange.upperBound) }
        syncWidgets()
    }

    func setFeedTheme(_ theme: FeedTheme) {
        if theme.isPremium && !isPro {
            sheet = .paywall(.shareTheme)
            return
        }
        mutate { $0.preferences.feedTheme = theme }
    }

    func setAppIcon(_ name: String?) {
        mutate { $0.preferences.appIcon = name }
        Task { await AppIconService.apply(name) }
    }

    func setTrialReminder(_ enabled: Bool) {
        mutate { $0.preferences.trialReminderEnabled = enabled }
    }

    /// Saves reminder settings, asking for permission first when turning them on.
    @discardableResult
    func updateReminders(_ settings: ReminderSettings) async -> Bool {
        var settings = settings
        if settings.isEnabled {
            var status = await notifications.authorization()
            if status == .notDetermined {
                status = await notifications.requestAuthorization() ? .authorized : .denied
            }
            notificationStatus = status
            if status != .authorized { settings.isEnabled = false }
        }
        let applied = settings
        mutate { $0.preferences.reminders = applied }
        await rescheduleNotifications()
        return applied.isEnabled
    }

    func completeOnboarding(familiarity: Familiarity?, motivation: Motivation?, role: Role?, topicIds: [String],
                            theme: FeedTheme, appIcon: String?) {
        mutate { s in
            s.preferences.familiarity = familiarity
            s.preferences.motivation = motivation
            s.preferences.role = role
            s.preferences.feedTheme = theme.isPremium && !isPro ? .cream : theme
            s.preferences.appIcon = appIcon
            if let familiarity { s.preferences.level = familiarity.suggestedLevel }
            s.preferences.topicIds = topicIds
            s.preferences.hasOnboarded = true
        }
        persistNow()
        regenerateFeed()
    }

    // MARK: - Library

    func createCollection(named name: String, with termID: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { $0.collections.append(UserCollection(name: trimmed, termIds: termID.map { [$0] } ?? [])) }
    }

    func toggle(_ termID: String, in collectionID: UUID) {
        mutate { s in
            guard let index = s.collections.firstIndex(where: { $0.id == collectionID }) else { return }
            if let position = s.collections[index].termIds.firstIndex(of: termID) {
                s.collections[index].termIds.remove(at: position)
            } else {
                s.collections[index].termIds.append(termID)
            }
        }
    }

    func deleteCollection(_ id: UUID) {
        mutate { $0.collections.removeAll { $0.id == id } }
    }

    func addCustomTerm(term: String, pos: String, definitions: Definitions, example: String?) {
        let slug = term.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let custom = Term(
            id: "custom-\(slug)-\(UUID().uuidString.prefix(6))",
            term: term.trimmingCharacters(in: .whitespaces),
            pos: pos,
            definitions: definitions,
            example: example?.isEmpty == true ? nil : example,
            topics: ["custom"],
            isCustom: true
        )
        mutate { $0.customTerms.insert(custom, at: 0) }
        rebuildIndex()
        setSaved(true, termID: custom.id, at: now())
    }

    func deleteCustomTerm(_ id: String) {
        mutate { s in
            s.customTerms.removeAll { $0.id == id }
            s.progress[id] = nil
        }
        feed.removeAll { $0.id == id }
        rebuildIndex()
    }

    // MARK: - Nudges

    func evaluateNudges(justCompletedGoal: Bool) {
        guard !isScreenshotRun, sheet == nil, overlayNudge == nil, state.preferences.hasOnboarded else { return }
        let context = NudgeContext(now: now(), state: state, isPro: isPro, hasWidgetInstalled: hasWidgetInstalled,
                                   justCompletedGoal: justCompletedGoal)
        guard let nudge = nudgeEngine.next(context) else { return }
        // Bookkeep as "shown"; accepting later upgrades it to resolved.
        mutate { nudgeEngine.record(nudge, outcome: .dismissed, now: now(), state: &$0.nudges) }
        switch nudge {
        case .review, .journey: overlayNudge = nudge
        case .widget: sheet = .widgetInstall
        case .paywall: sheet = .paywall(.nudge)
        }
    }

    func resolve(_ nudge: Nudge, _ outcome: NudgeOutcome) {
        mutate { nudgeEngine.record(nudge, outcome: outcome, now: now(), state: &$0.nudges) }
        if overlayNudge == nudge { overlayNudge = nil }
    }

    // MARK: - Deep links

    func handle(_ url: URL) {
        guard let link = DeepLink(url: url) else { return }
        handle(link)
    }

    func handle(_ link: DeepLink) {
        switch link {
        case .term(let id): show(termID: id)
        case .tab(let tab): selectedTab = tab
        case .paywall: sheet = .paywall(.crown)
        }
    }

    // MARK: - Widgets & notifications

    func syncWidgets() {
        let upcoming = (feed + feedEngine.batch(from: content.terms, state: state, isPro: isPro, now: now(),
                                                excluding: Set(feed.map(\.id)), using: &rng))
            .filter { !$0.isCustom }
        var seen = Set<String>()
        let words = upcoming.filter { seen.insert($0.id).inserted }.prefix(24).map { WidgetWord(term: $0, level: level) }
        widgets.publish(WidgetSnapshot(
            generatedAt: now(),
            words: Array(words),
            savedIds: Set(state.savedIds),
            streak: streak,
            savedToday: savedToday,
            dailyGoal: dailyGoal,
            dayKey: todayKey
        ))
    }

    func rescheduleNotifications() async {
        let words = reminderEngine.batch(from: content.terms, state: state, isPro: isPro, now: now(),
                                         excluding: Set(feed.prefix(10).map(\.id)), using: &rng)
        let planner = NotificationPlanner(calendar: calendar)
        var plan = planner.plan(.init(
            settings: state.preferences.reminders,
            words: words,
            level: level,
            now: now(),
            savedToday: savedToday,
            dailyGoal: dailyGoal,
            streak: streak
        ))
        if state.preferences.trialReminderEnabled, let trialEnd = purchases.trialEndDate,
           let reminder = planner.trialReminder(trialEnds: trialEnd, now: now()) {
            plan.append(reminder)
        }
        guard notificationStatus == .authorized else { return }
        await notifications.replacePending(with: plan)
    }
}
