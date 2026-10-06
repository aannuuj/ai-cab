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
    public func recommendedLevel(known: Set<String>, rounds: [Round] = PlacementTest.rounds) -> Level {
        func passed(_ level: Level) -> Bool {
            guard let round = rounds.first(where: { $0.level == level }) else { return false }
            return round.termIds.filter(known.contains).count >= min(Self.passCount, round.termIds.count)
        }
        if passed(.builder) { return .research }
        if passed(.beginner) { return .builder }
        return .beginner
    }
}
