import Foundation

/// Timed / lives-based practice challenges.
public enum ChallengeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// As many as you can in 60 seconds.
    case sprint
    /// Endless, three lives.
    case rush
    /// Endless, one mistake ends it.
    case perfection

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sprint: "Sprint"
        case .rush: "Rush"
        case .perfection: "Perfection"
        }
    }

    public var tagline: String {
        switch self {
        case .sprint: "60 seconds, go"
        case .rush: "3 lives, no clock"
        case .perfection: "One mistake ends it"
        }
    }

    /// Lives before the run ends; `nil` means unlimited.
    public var lives: Int? {
        switch self {
        case .sprint: nil
        case .rush: 3
        case .perfection: 1
        }
    }

    /// Seconds on the clock; `nil` means untimed.
    public var timeLimit: TimeInterval? {
        switch self {
        case .sprint: 60
        case .rush, .perfection: nil
        }
    }

    public var isPremium: Bool { self != .sprint }
}

/// Score keeping for one challenge run. Pure value type so the rules are testable.
public struct ChallengeRun: Sendable, Equatable {
    public let mode: ChallengeMode
    public private(set) var correct = 0
    public private(set) var wrong = 0
    public private(set) var streak = 0
    public private(set) var bestStreak = 0

    public init(mode: ChallengeMode) {
        self.mode = mode
    }

    public var livesLeft: Int? { mode.lives.map { max($0 - wrong, 0) } }

    public mutating func record(correct isCorrect: Bool) {
        guard !isOver(elapsed: 0) else { return }
        if isCorrect {
            correct += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            wrong += 1
            streak = 0
        }
    }

    public func timeLeft(elapsed: TimeInterval) -> TimeInterval? {
        mode.timeLimit.map { max($0 - elapsed, 0) }
    }

    public func isOver(elapsed: TimeInterval) -> Bool {
        if let livesLeft, livesLeft == 0 { return true }
        if let left = timeLeft(elapsed: elapsed), left <= 0 { return true }
        return false
    }

    /// The headline number: correct answers.
    public var score: Int { correct }
}
