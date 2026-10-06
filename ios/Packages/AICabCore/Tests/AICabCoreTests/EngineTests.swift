import XCTest
@testable import AICabCore

final class SpacedRepetitionTests: XCTestCase {
    func testCorrectAnswersPromoteAndMissesReset() {
        let cal = Fixtures.calendar
        let now = Fixtures.date("2026-10-06T09:00:00Z")
        var p = TermProgress(termId: "rag")
        SpacedRepetition.enroll(&p, now: now, calendar: cal)
        XCTAssertEqual(p.box, 1)
        XCTAssertFalse(SpacedRepetition.isDue(p, now: now))

        SpacedRepetition.record(&p, correct: true, now: now, calendar: cal)
        XCTAssertEqual(p.box, 2)
        XCTAssertEqual(p.nextReviewAt, cal.date(byAdding: .day, value: 3, to: now))

        for _ in 0..<10 { SpacedRepetition.record(&p, correct: true, now: now, calendar: cal) }
        XCTAssertEqual(p.box, SpacedRepetition.masteredBox)
        XCTAssertTrue(p.isMastered)

        SpacedRepetition.record(&p, correct: false, now: now, calendar: cal)
        XCTAssertEqual(p.box, 1)
        XCTAssertEqual(p.wrong, 1)
    }
}

final class StreakTests: XCTestCase {
    func testStreakSurvivesUntilEndOfToday() {
        let cal = Fixtures.calendar
        let today = Fixtures.date("2026-10-06T12:00:00Z")
        let days: Set<String> = ["2026-10-03", "2026-10-04", "2026-10-05"]
        XCTAssertEqual(Streak.current(goalMetDays: days, today: today, calendar: cal), 3)
        XCTAssertEqual(Streak.current(goalMetDays: days.union(["2026-10-06"]), today: today, calendar: cal), 4)
        XCTAssertEqual(Streak.current(goalMetDays: ["2026-10-01"], today: today, calendar: cal), 0)
    }

    func testLongestStreak() {
        let days: Set<String> = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-10", "2026-09-11"]
        XCTAssertEqual(Streak.longest(goalMetDays: days, calendar: Fixtures.calendar), 3)
    }

    func testWeekHasSevenDaysAndMarksToday() {
        let week = Streak.week(goalMetDays: ["2026-10-06"], today: Fixtures.date("2026-10-06T12:00:00Z"), calendar: Fixtures.calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.filter(\.isToday).count, 1)
        XCTAssertTrue(week.first(where: \.isToday)!.isComplete)
    }
}

final class FeedEngineTests: XCTestCase {
    func testBatchRespectsPremiumAndSize() {
        var rng = SeededGenerator(seed: 1)
        let engine = FeedEngine()
        let batch = engine.batch(from: Fixtures.catalog, state: UserState(), isPro: false, now: Date(), using: &rng)
        XCTAssertEqual(batch.count, 20)
        XCTAssertFalse(batch.contains(where: \.isPremium))
        XCTAssertEqual(Set(batch.map(\.id)).count, batch.count, "no duplicates")
    }

    func testBatchPrefersLevelAndTopics() {
        var rng = SeededGenerator(seed: 7)
        var state = UserState()
        state.preferences.level = .research
        state.preferences.topicIds = ["even"]
        let batch = FeedEngine().batch(from: Fixtures.catalog, state: state, isPro: true, now: Date(), using: &rng)
        XCTAssertTrue(batch.allSatisfy { $0.topics.contains("even") })
        let firstFive = batch.prefix(5)
        XCTAssertGreaterThanOrEqual(firstFive.filter { $0.difficulty == .pro }.count, 3)
    }

    func testDueReviewsAreIncluded() {
        var rng = SeededGenerator(seed: 3)
        let now = Fixtures.date("2026-10-06T09:00:00Z")
        var state = UserState(now: now)
        state.update("t4") { p in
            p.seenCount = 3
            p.box = 2
            p.nextReviewAt = now.addingTimeInterval(-60)
            p.lastSeenAt = now.addingTimeInterval(-3600)
        }
        let batch = FeedEngine().batch(from: Fixtures.catalog, state: state, isPro: false, now: now, using: &rng)
        XCTAssertTrue(batch.contains { $0.id == "t4" })
    }

    func testExcludedTermsAreSkipped() {
        var rng = SeededGenerator(seed: 5)
        let excluded = Set(Fixtures.catalog.prefix(10).map(\.id))
        let batch = FeedEngine().batch(from: Fixtures.catalog, state: UserState(), isPro: true, now: Date(), excluding: excluded, using: &rng)
        XCTAssertTrue(batch.allSatisfy { !excluded.contains($0.id) })
    }
}

final class QuizGeneratorTests: XCTestCase {
    func testQuestionsHaveOneCorrectAnswerAmongFour() {
        var rng = SeededGenerator(seed: 11)
        let generator = QuizGenerator(level: .builder)
        let pool = Fixtures.catalog
        for kind in QuizQuestion.Kind.allCases where kind != .compare {
            let q = generator.question(kind, for: pool[0], pool: pool, using: &rng)
            XCTAssertNotNil(q, "\(kind)")
            XCTAssertEqual(q?.choices.count, 4)
            XCTAssertEqual(Set(q!.choices).count, 4)
        }
    }

    func testUseInSentenceBlanksTheTerm() {
        var rng = SeededGenerator(seed: 2)
        let q = QuizGenerator(level: .beginner).question(.useInSentence, for: Fixtures.catalog[3], pool: Fixtures.catalog, using: &rng)
        XCTAssertEqual(q?.detail, "We used _____ in production.")
        XCTAssertEqual(q?.answer, "t3")
    }

    func testCompareUsesContrastTerm() {
        var rng = SeededGenerator(seed: 4)
        var pool = Fixtures.catalog
        pool[0].contrastWith = ["t1"]
        let q = QuizGenerator(level: .beginner).question(.compare, for: pool[0], pool: pool, using: &rng)
        XCTAssertNotNil(q)
        XCTAssertTrue(q!.choices.contains("t1 for beginners"))
        XCTAssertEqual(q!.answer, "t0 for beginners")
    }
}

final class JourneyEngineTests: XCTestCase {
    let chapters = [
        Chapter(number: 1, title: "One", subtitle: "", termIds: ["t0", "t1", "t2", "t3", "t4"]),
        Chapter(number: 2, title: "Two", subtitle: "", termIds: ["t5", "t6", "t7"]),
        Chapter(number: 3, title: "Three", subtitle: "", termIds: ["t8"], isPremium: true),
    ]

    func testLessonsUnlockInOrder() {
        let engine = JourneyEngine()
        var progress = JourneyProgress()
        XCTAssertEqual(engine.status(of: .learn, in: chapters[0], chapters: chapters, progress: progress, isPro: false), .available)
        XCTAssertEqual(engine.status(of: .use, in: chapters[0], chapters: chapters, progress: progress, isPro: false), .locked)
        engine.record(correct: 0, total: 0, lesson: .learn, chapter: 1, progress: &progress)
        XCTAssertEqual(engine.status(of: .use, in: chapters[0], chapters: chapters, progress: progress, isPro: false), .available)
        XCTAssertEqual(engine.current(chapters: chapters, progress: progress, isPro: false)?.lesson, .use)
    }

    func testTestNeedsPassMarkAndUnlocksNextChapter() {
        let engine = JourneyEngine()
        var progress = JourneyProgress()
        XCTAssertFalse(engine.record(correct: 7, total: 10, lesson: .test, chapter: 1, progress: &progress))
        XCTAssertFalse(engine.isChapterUnlocked(chapters[1], in: chapters, progress: progress, isPro: false))
        XCTAssertTrue(engine.record(correct: 8, total: 10, lesson: .test, chapter: 1, progress: &progress))
        XCTAssertTrue(engine.isChapterUnlocked(chapters[1], in: chapters, progress: progress, isPro: false))
    }

    func testPremiumChapterNeedsPro() {
        let engine = JourneyEngine()
        var progress = JourneyProgress()
        engine.record(correct: 1, total: 1, lesson: .test, chapter: 2, progress: &progress)
        XCTAssertFalse(engine.isChapterUnlocked(chapters[2], in: chapters, progress: progress, isPro: false))
        XCTAssertTrue(engine.isChapterUnlocked(chapters[2], in: chapters, progress: progress, isPro: true))
    }

    func testQuestionsComeFromChapterTerms() {
        var rng = SeededGenerator(seed: 9)
        let terms = Dictionary(uniqueKeysWithValues: Fixtures.catalog.map { ($0.id, $0) })
        let qs = JourneyEngine().questions(for: .recall, chapter: chapters[0], terms: terms, pool: Fixtures.catalog, level: .beginner, using: &rng)
        XCTAssertEqual(qs.count, 5)
        XCTAssertTrue(qs.allSatisfy { chapters[0].termIds.contains($0.termId) })
    }
}

final class NotificationPlannerTests: XCTestCase {
    func testTimesAreEvenlySpacedInsideWindow() {
        let planner = NotificationPlanner(calendar: Fixtures.calendar)
        let times = planner.wordTimes(for: ReminderSettings(isEnabled: true, perDay: 3, startMinute: 600, endMinute: 1320))
        XCTAssertEqual(times, [600, 960, 1320])
        XCTAssertEqual(planner.wordTimes(for: ReminderSettings(isEnabled: true, perDay: 1)), [600])
    }

    func testPlanSkipsPastTimesAndAddsStreakSaver() {
        let planner = NotificationPlanner(calendar: Fixtures.calendar)
        let now = Fixtures.date("2026-10-06T12:00:00Z")
        let plan = planner.plan(.init(
            settings: ReminderSettings(isEnabled: true, perDay: 3),
            words: Fixtures.catalog, level: .beginner, now: now,
            savedToday: 1, dailyGoal: 5, streak: 4, days: 2
        ))
        let words = plan.filter { $0.kind == .word }
        XCTAssertEqual(words.count, 5, "2 left today + 3 tomorrow")
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > now })
        let saver = plan.first { $0.kind == .streakSaver }
        XCTAssertEqual(saver?.title, "Keep your 4-day streak alive 🔥")
        XCTAssertTrue(plan.contains { $0.kind == .comeback })
        XCTAssertLessThanOrEqual(plan.count, NotificationPlanner.maxPending)
    }

    func testNoStreakSaverTonightWhenGoalMet() {
        let planner = NotificationPlanner(calendar: Fixtures.calendar)
        let now = Fixtures.date("2026-10-06T12:00:00Z")
        let plan = planner.plan(.init(settings: ReminderSettings(isEnabled: true), words: [], level: .beginner,
                                      now: now, savedToday: 5, dailyGoal: 5, streak: 2, days: 1))
        let savers = plan.filter { $0.kind == .streakSaver }
        XCTAssertEqual(savers.count, 1, "only tomorrow's")
        XCTAssertEqual(savers.first?.title, "Keep your 3-day streak alive 🔥")
    }

    func testDisabledPlansNothing() {
        let plan = NotificationPlanner().plan(.init(settings: ReminderSettings(isEnabled: false), words: Fixtures.catalog,
                                                    level: .beginner, now: Date(), savedToday: 0, dailyGoal: 5, streak: 0))
        XCTAssertTrue(plan.isEmpty)
    }
}

final class NudgeEngineTests: XCTestCase {
    func testWidgetNudgeAfterSecondSessionThenCooldown() {
        let now = Fixtures.date("2026-10-06T12:00:00Z")
        var state = UserState(now: now)
        state.nudges.sessionCount = 2
        let engine = NudgeEngine()
        let context = NudgeContext(now: now, state: state, isPro: false, hasWidgetInstalled: false, justCompletedGoal: false)
        XCTAssertEqual(engine.next(context), .widget)

        engine.record(.widget, outcome: .snoozed, now: now, state: &state.nudges)
        let later = NudgeContext(now: now.addingTimeInterval(3600), state: state, isPro: false, hasWidgetInstalled: false, justCompletedGoal: false)
        XCTAssertNil(engine.next(later), "global cooldown")
    }

    func testReviewOnlyAtAPositiveMoment() {
        let installed = Fixtures.date("2026-10-01T12:00:00Z")
        let now = Fixtures.date("2026-10-06T12:00:00Z")
        var state = UserState(now: installed)
        state.nudges.sessionCount = 1
        for i in 0..<12 { state.update("t\(i)") { $0.isSaved = true } }
        let engine = NudgeEngine()
        XCTAssertEqual(engine.next(.init(now: now, state: state, isPro: true, hasWidgetInstalled: true, justCompletedGoal: true)), .review)
        XCTAssertNil(engine.next(.init(now: now, state: state, isPro: true, hasWidgetInstalled: true, justCompletedGoal: false)))
    }

    func testAcceptedNudgesNeverReturn() {
        let now = Fixtures.date("2026-10-06T12:00:00Z")
        var state = UserState(now: now.addingTimeInterval(-10 * 86_400))
        state.nudges.sessionCount = 5
        state.nudges.journeyIntroSeen = true
        let engine = NudgeEngine()
        engine.record(.paywall, outcome: .accepted, now: now.addingTimeInterval(-30 * 86_400), state: &state.nudges)
        XCTAssertNil(engine.next(.init(now: now, state: state, isPro: false, hasWidgetInstalled: true, justCompletedGoal: false)))
    }
}

final class WidgetStoreTests: XCTestCase {
    func testToggleSavedWritesInboxAndUpdatesSnapshot() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = WidgetStore(directory: dir)
        let now = Date()
        var snapshot = WidgetSnapshot.placeholder
        snapshot.dayKey = DayKey.string(for: now)
        snapshot.savedToday = 0
        try store.write(snapshot)

        store.toggleSaved(termId: "rag", now: now)
        XCTAssertTrue(store.snapshot()!.savedIds.contains("rag"))
        XCTAssertEqual(store.snapshot()!.savedToday, 1)

        let inbox = store.drainInbox()
        XCTAssertEqual(inbox.map(\.action), [.save])
        XCTAssertTrue(store.drainInbox().isEmpty)
    }

    func testWordIndexWraps() {
        let s = WidgetSnapshot.placeholder
        XCTAssertEqual(WidgetStore.word(in: s, at: 3)?.id, s.words[0].id)
        XCTAssertEqual(WidgetStore.word(in: s, at: -1)?.id, s.words[2].id)
    }
}

final class ContentTests: XCTestCase {
    func testDecodesWithDefaults() throws {
        let json = """
        {"version": 3, "generatedAt": "2026-10-06", "topics": [], "chapters": [],
         "terms": [{"id": "rag", "term": "RAG", "definitions": {"beginner": "a", "builder": "b", "research": "c"}}]}
        """
        let pack = try ContentLoader.decode(Data(json.utf8))
        XCTAssertEqual(pack.terms.first?.pos, "n.")
        XCTAssertEqual(pack.terms.first?.difficulty, .beginner)
        XCTAssertEqual(pack.terms.first?.definition(at: .research), "c")
    }

    func testNewestPrefersHigherVersion() {
        let bundled = ContentPack(version: 2, generatedAt: "", terms: [], topics: [], chapters: [])
        let cached = ContentPack(version: 3, generatedAt: "", terms: [], topics: [], chapters: [])
        XCTAssertEqual(ContentLoader.newest(bundled: bundled, cached: cached).version, 3)
        XCTAssertEqual(ContentLoader.newest(bundled: cached, cached: bundled).version, 3)
    }

    func testUserStateRoundTrips() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FileUserStateStore(directory: dir)
        var state = UserState()
        state.update("rag") { $0.isFavorite = true }
        state.preferences.level = .builder
        try store.save(state)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertTrue(loaded.progress["rag"]!.isFavorite)
        XCTAssertEqual(loaded.preferences.level, .builder)
    }
}

final class PlacementTests: XCTestCase {
    func testLevelFollowsKnownWords() {
        let test = PlacementTest()
        XCTAssertEqual(test.recommendedLevel(known: []), .beginner)
        let beginner = Set(PlacementTest.rounds[0].termIds.prefix(4))
        XCTAssertEqual(test.recommendedLevel(known: beginner), .builder)
        let builder = beginner.union(PlacementTest.rounds[1].termIds.prefix(5))
        XCTAssertEqual(test.recommendedLevel(known: builder), .research)
    }

    func testWeeklyGoalMapsToDailyGoal() {
        XCTAssertEqual(Preferences.dailyGoal(forWeeklyWords: 10), 2)
        XCTAssertEqual(Preferences.dailyGoal(forWeeklyWords: 30), 5)
        XCTAssertEqual(Preferences.dailyGoal(forWeeklyWords: 50), 8)
    }

    func testStreakSaverUsesName() {
        let plan = NotificationPlanner(calendar: Fixtures.calendar).plan(.init(
            settings: ReminderSettings(isEnabled: true), words: [], level: .beginner,
            now: Fixtures.date("2026-10-06T12:00:00Z"), savedToday: 0, dailyGoal: 5, streak: 3, days: 1, name: "Om"))
        XCTAssertEqual(plan.first { $0.kind == .streakSaver }?.title, "Om, keep your 3-day streak alive 🔥")
    }
}

final class ChallengeTests: XCTestCase {
    func testRushEndsAfterThreeMisses() {
        var run = ChallengeRun(mode: .rush)
        run.record(correct: true)
        run.record(correct: false)
        run.record(correct: false)
        XCTAssertEqual(run.livesLeft, 1)
        XCTAssertFalse(run.isOver(elapsed: 999))
        run.record(correct: false)
        XCTAssertTrue(run.isOver(elapsed: 0))
        run.record(correct: true)
        XCTAssertEqual(run.score, 1, "answers after the run ends don't count")
    }

    func testPerfectionEndsOnFirstMiss() {
        var run = ChallengeRun(mode: .perfection)
        for _ in 0..<5 { run.record(correct: true) }
        run.record(correct: false)
        XCTAssertTrue(run.isOver(elapsed: 0))
        XCTAssertEqual(run.bestStreak, 5)
    }

    func testSprintEndsOnTheClockNotMisses() {
        var run = ChallengeRun(mode: .sprint)
        for _ in 0..<10 { run.record(correct: false) }
        XCTAssertNil(run.livesLeft)
        XCTAssertFalse(run.isOver(elapsed: 59))
        XCTAssertEqual(run.timeLeft(elapsed: 45), 15)
        XCTAssertTrue(run.isOver(elapsed: 60))
    }

    func testLevelQuizNeedsTwoOfThree() {
        let test = PlacementTest()
        let rounds = [PlacementTest.Round(level: .beginner, termIds: ["a", "b", "c"]),
                      PlacementTest.Round(level: .builder, termIds: ["d", "e", "f"])]
        XCTAssertEqual(test.recommendedLevel(correctIds: ["a"], quizRounds: rounds), .beginner)
        XCTAssertEqual(test.recommendedLevel(correctIds: ["a", "b"], quizRounds: rounds), .builder)
        XCTAssertEqual(test.recommendedLevel(correctIds: ["a", "b", "d", "f"], quizRounds: rounds), .research)
    }
}
