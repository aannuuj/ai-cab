import Foundation

/// Timed / lives-based practice challenges.
public enum ChallengeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// As many as you can in 60 seconds.
    case blitz
    /// Endless, three lives.
    case survival
    /// Endless, one mistake ends it.
    case flawless

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .blitz: "Blitz"
        case .survival: "Survival"
        case .flawless: "Flawless"
        }
    }

    public var tagline: String {
        switch self {
        case .blitz: "60 seconds on the clock"
        case .survival: "Three strikes and you're out"
        case .flawless: "One mistake ends it"
        }
    }

    /// Lives before the run ends; `nil` means unlimited.
    public var lives: Int? {
        switch self {
        case .blitz: nil
        case .survival: 3
        case .flawless: 1
        }
    }

    /// Seconds on the clock; `nil` means untimed.
    public var timeLimit: TimeInterval? {
        switch self {
        case .blitz: 60
        case .survival, .flawless: nil
        }
    }

    public var isPremium: Bool { self != .blitz }
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
