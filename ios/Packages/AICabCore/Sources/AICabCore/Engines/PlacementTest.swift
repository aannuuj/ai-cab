import Foundation

/// Onboarding knowledge check: "Select all the AI words you know", one round per level.
public struct PlacementTest: Sendable {
    public struct Round: Identifiable, Sendable {
        public let level: Level
        public let termIds: [String]
        public var id: Level { level }

        public var title: String {
            switch level {
            case .beginner: "Beginner words"
            case .builder: "Builder words"
            case .research: "Research words"
            }
        }
    }

    /// A round counts as "known" at this many of its six words.
    public static let passCount = 4

    public static let rounds: [Round] = [
        Round(level: .beginner, termIds: ["token", "prompt", "hallucination", "chatbot", "fine-tuning", "context-window"]),
        Round(level: .builder, termIds: ["rag", "embedding", "transformer", "lora", "quantization", "function-calling-api"]),
        Round(level: .research, termIds: ["kv-cache", "rlhf", "mixture-of-experts", "speculative-decoding", "sparse-autoencoder", "grpo"]),
    ]

    public init() {}

    /// Rounds whose terms all exist in the catalog.
    public func rounds(in terms: [String: Term]) -> [Round] {
        Self.rounds.map { round in
            Round(level: round.level, termIds: round.termIds.filter { terms[$0] != nil })
        }
    }

    /// Highest level whose round the learner mostly knows; the next level up is where learning starts.
    public func recommendedLevel(known: Set<String>, rounds: [Round] = PlacementTest.rounds,
                                 passCount: Int = PlacementTest.passCount) -> Level {
        func passed(_ level: Level) -> Bool {
            guard let round = rounds.first(where: { $0.level == level }), !round.termIds.isEmpty else { return false }
            return round.termIds.filter(known.contains).count >= min(passCount, round.termIds.count)
        }
        if passed(.builder) { return .research }
        if passed(.beginner) { return .builder }
        return .beginner
    }

    /// Practice "What's your level?" quiz: a few words from each round, in level order.
    public static let quizPerRound = 3

    public func quizRounds<R: RandomNumberGenerator>(in terms: [String: Term], using rng: inout R) -> [Round] {
        rounds(in: terms).map { round in
            Round(level: round.level, termIds: Array(round.termIds.shuffled(using: &rng).prefix(Self.quizPerRound)))
        }
    }

    /// Level from the ids answered correctly in the quiz (2 of 3 passes a round).
    public func recommendedLevel(correctIds: Set<String>, quizRounds: [Round]) -> Level {
        recommendedLevel(known: correctIds, rounds: quizRounds, passCount: Self.quizPerRound - 1)
    }
}
