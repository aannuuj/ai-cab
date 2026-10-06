import Foundation

public struct QuizQuestion: Identifiable, Hashable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case pickDefinition, pickTerm, useInSentence, expansion, compare
    }

    public var id: String
    public var kind: Kind
    public var prompt: String
    /// Secondary line, e.g. the sentence with a blank.
    public var detail: String?
    public var choices: [String]
    public var answerIndex: Int
    public var termId: String
    public var explanation: String

    public var answer: String { choices[answerIndex] }
}

public struct MatchPair: Identifiable, Hashable, Sendable {
    public var id: String { termId }
    public var termId: String
    public var term: String
    public var definition: String
}

/// Builds multiple-choice questions from the catalog. Distractors prefer terms from the same topics,
/// which makes questions harder in a useful way.
public struct QuizGenerator: Sendable {
    public var level: Level

    public init(level: Level) {
        self.level = level
    }

    public func question<R: RandomNumberGenerator>(_ kind: QuizQuestion.Kind, for term: Term, pool: [Term], using rng: inout R) -> QuizQuestion? {
        let others = distractorPool(for: term, in: pool, using: &rng)
        switch kind {
        case .pickDefinition:
            let wrong = Array(others.map { $0.definition(at: level) }.uniqued(excluding: term.definition(at: level)).prefix(3))
            guard wrong.count == 3 else { return nil }
            return make(kind, term: term, prompt: "What does \u{201C}\(term.term)\u{201D} mean?", detail: nil,
                        correct: term.definition(at: level), wrong: wrong, using: &rng,
                        explanation: term.analogy ?? term.definition(at: .beginner))
        case .pickTerm:
            let wrong = Array(others.map(\.term).uniqued(excluding: term.term).prefix(3))
            guard wrong.count == 3 else { return nil }
            return make(kind, term: term, prompt: "Which term matches this definition?", detail: term.definition(at: level),
                        correct: term.term, wrong: wrong, using: &rng,
                        explanation: "\(term.term): \(term.definition(at: .beginner))")
        case .useInSentence:
            guard let example = term.example, let blanked = Self.blank(term.term, in: example) else { return nil }
            let wrong = Array(others.map(\.term).uniqued(excluding: term.term).prefix(3))
            guard wrong.count == 3 else { return nil }
            return make(kind, term: term, prompt: "Which word completes the sentence?", detail: blanked,
                        correct: term.term, wrong: wrong, using: &rng, explanation: example)
        case .expansion:
            guard let expansion = term.expansion else { return nil }
            let wrong = Array(pool.compactMap(\.expansion).shuffled(using: &rng).uniqued(excluding: expansion).prefix(3))
            guard wrong.count == 3 else { return nil }
            return make(kind, term: term, prompt: "What does \(term.term) stand for?", detail: nil,
                        correct: expansion, wrong: wrong, using: &rng, explanation: term.definition(at: .beginner))
        case .compare:
            guard let otherId = term.contrastWith.first, let other = pool.first(where: { $0.id == otherId }) else { return nil }
            var wrong = [other.definition(at: level)]
            wrong += others.filter { $0.id != other.id }.map { $0.definition(at: level) }.uniqued(excluding: term.definition(at: level)).prefix(2)
            guard wrong.count == 3 else { return nil }
            return make(kind, term: term, prompt: "\(term.term) vs \(other.term): which one describes \(term.term)?", detail: nil,
                        correct: term.definition(at: level), wrong: wrong, using: &rng,
                        explanation: "\(other.term) is \(other.definition(at: .beginner).lowercasedFirst())")
        }
    }

    /// Best-effort question of the requested kind; falls back to a definition question.
    public func anyQuestion<R: RandomNumberGenerator>(preferring kinds: [QuizQuestion.Kind], for term: Term, pool: [Term], using rng: inout R) -> QuizQuestion? {
        for kind in kinds + [.pickDefinition, .pickTerm] {
            if let q = question(kind, for: term, pool: pool, using: &rng) { return q }
        }
        return nil
    }

    public func quiz<R: RandomNumberGenerator>(for targets: [Term], pool: [Term], count: Int,
                                               kinds: [QuizQuestion.Kind] = QuizQuestion.Kind.allCases,
                                               using rng: inout R) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        for (index, term) in targets.enumerated() where questions.count < count {
            let rotated = Array(kinds[(index % kinds.count)...] + kinds[..<(index % kinds.count)])
            if let q = anyQuestion(preferring: rotated, for: term, pool: pool, using: &rng) {
                questions.append(q)
            }
        }
        return questions
    }

    public func matchPairs(for targets: [Term], count: Int = 4) -> [MatchPair] {
        targets.prefix(count).map { MatchPair(termId: $0.id, term: $0.term, definition: $0.definition(at: .beginner)) }
    }

    // MARK: - Helpers

    private func distractorPool<R: RandomNumberGenerator>(for term: Term, in pool: [Term], using rng: inout R) -> [Term] {
        let topics = Set(term.topics)
        let candidates = pool.filter { $0.id != term.id && !$0.isCustom }
        let near = candidates.filter { !topics.isDisjoint(with: $0.topics) }.shuffled(using: &rng)
        let far = candidates.filter { topics.isDisjoint(with: $0.topics) }.shuffled(using: &rng)
        return near + far
    }

    private func make<R: RandomNumberGenerator>(_ kind: QuizQuestion.Kind, term: Term, prompt: String, detail: String?,
                                                correct: String, wrong: [String], using rng: inout R,
                                                explanation: String) -> QuizQuestion {
        var choices = wrong + [correct]
        choices.shuffle(using: &rng)
        let index = choices.firstIndex(of: correct) ?? 0
        return QuizQuestion(id: "\(kind.rawValue).\(term.id)", kind: kind, prompt: prompt, detail: detail,
                            choices: choices, answerIndex: index, termId: term.id, explanation: explanation)
    }

    /// Replaces the term inside an example sentence with a blank (case-insensitive).
    static func blank(_ word: String, in sentence: String) -> String? {
        guard let range = sentence.range(of: word, options: [.caseInsensitive]) else { return nil }
        return sentence.replacingCharacters(in: range, with: "_____")
    }
}

extension Sequence where Element == String {
    func uniqued(excluding excluded: String) -> [String] {
        var seen: Set<String> = [excluded]
        return filter { seen.insert($0).inserted }
    }
}

extension String {
    func lowercasedFirst() -> String {
        guard let first else { return self }
        // Keep acronyms ("LLM", "GPU") intact.
        if count > 1, self[index(after: startIndex)].isUppercase { return self }
        return first.lowercased() + dropFirst()
    }
}
