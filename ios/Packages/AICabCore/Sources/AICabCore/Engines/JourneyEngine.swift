import Foundation

/// The six stops on every chapter's path, in order.
public enum LessonKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case learn, use, match, recall, compare, test

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .learn: "Meet the terms"
        case .use: "Use it"
        case .match: "Match"
        case .recall: "Recall"
        case .compare: "This vs that"
        case .test: "Checkpoint"
        }
    }

    public var subtitle: String {
        switch self {
        case .learn: "Meet this unit's new terms"
        case .use: "Pick the word that fits the sentence"
        case .match: "Pair each term with its meaning"
        case .recall: "Name the term from its definition"
        case .compare: "Tell look-alike concepts apart"
        case .test: "Score 80% to open the next unit"
        }
    }

    public var symbol: String {
        switch self {
        case .learn: "star.fill"
        case .use: "paperplane.fill"
        case .match: "puzzlepiece.fill"
        case .recall: "textformat"
        case .compare: "arrow.left.arrow.right"
        case .test: "trophy.fill"
        }
    }

    var questionKinds: [QuizQuestion.Kind] {
        switch self {
        case .learn, .match: []
        case .use: [.useInSentence, .pickTerm]
        case .recall: [.pickTerm, .expansion]
        case .compare: [.compare, .pickDefinition]
        case .test: QuizQuestion.Kind.allCases
        }
    }
}

public enum LessonStatus: Sendable, Equatable {
    case locked, available, completed
}

public struct JourneyEngine: Sendable {
    public static let passMark = 0.8

    public init() {}

    public func isChapterUnlocked(_ chapter: Chapter, in chapters: [Chapter], progress: JourneyProgress, isPro: Bool) -> Bool {
        if chapter.isPremium && !isPro { return false }
        guard let index = chapters.firstIndex(where: { $0.number == chapter.number }) else { return false }
        if index == 0 { return true }
        return progress.isCompleted(chapter: chapters[index - 1].number, lesson: .test)
    }

    public func status(of lesson: LessonKind, in chapter: Chapter, chapters: [Chapter], progress: JourneyProgress, isPro: Bool) -> LessonStatus {
        if progress.isCompleted(chapter: chapter.number, lesson: lesson) { return .completed }
        guard isChapterUnlocked(chapter, in: chapters, progress: progress, isPro: isPro) else { return .locked }
        guard let index = LessonKind.allCases.firstIndex(of: lesson) else { return .locked }
        if index == 0 { return .available }
        let previous = LessonKind.allCases[index - 1]
        return progress.isCompleted(chapter: chapter.number, lesson: previous) ? .available : .locked
    }

    /// The next lesson to play — what the path highlights and the "Continue" button opens.
    public func current(chapters: [Chapter], progress: JourneyProgress, isPro: Bool) -> (chapter: Chapter, lesson: LessonKind)? {
        for chapter in chapters {
            for lesson in LessonKind.allCases where status(of: lesson, in: chapter, chapters: chapters, progress: progress, isPro: isPro) == .available {
                return (chapter, lesson)
            }
        }
        return nil
    }

    public func completedCount(in chapter: Chapter, progress: JourneyProgress) -> Int {
        LessonKind.allCases.filter { progress.isCompleted(chapter: chapter.number, lesson: $0) }.count
    }

    public func questions<R: RandomNumberGenerator>(for lesson: LessonKind, chapter: Chapter, terms: [String: Term], pool: [Term],
                                                    level: Level, using rng: inout R) -> [QuizQuestion] {
        let chapterTerms = chapter.termIds.compactMap { terms[$0] }
        let generator = QuizGenerator(level: level)
        switch lesson {
        case .learn, .match:
            return []
        case .test:
            let targets = chapterTerms.shuffled(using: &rng)
            return generator.quiz(for: targets, pool: pool, count: min(10, targets.count), kinds: lesson.questionKinds, using: &rng)
        case .compare:
            // Lead with terms that actually have a look-alike.
            let paired = chapterTerms.filter { !$0.contrastWith.isEmpty }
            let rest = chapterTerms.filter { $0.contrastWith.isEmpty }
            let targets = paired.shuffled(using: &rng) + rest.shuffled(using: &rng)
            return generator.quiz(for: targets, pool: pool, count: min(5, targets.count), kinds: lesson.questionKinds, using: &rng)
        case .use, .recall:
            let targets = chapterTerms.shuffled(using: &rng)
            return generator.quiz(for: targets, pool: pool, count: min(5, targets.count), kinds: lesson.questionKinds, using: &rng)
        }
    }

    /// Records a lesson attempt. Returns whether it passed (and was marked complete).
    @discardableResult
    public func record(correct: Int, total: Int, lesson: LessonKind, chapter: Int, progress: inout JourneyProgress) -> Bool {
        let key = JourneyProgress.key(chapter: chapter, lesson: lesson)
        let score = total == 0 ? 1 : Double(correct) / Double(total)
        progress.bestScores[key] = max(progress.bestScores[key] ?? 0, score)
        let needsPassMark = lesson == .test
        let passed = !needsPassMark || score >= Self.passMark
        if passed { progress.completed.insert(key) }
        return passed
    }
}
