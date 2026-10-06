import Foundation
@testable import AICabCore

/// Deterministic RNG so engine tests are reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum Fixtures {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)!
    }

    static func term(_ id: String, difficulty: Difficulty = .beginner, topics: [String] = ["basics"],
                     premium: Bool = false, trending: Double = 0, example: String? = nil,
                     expansion: String? = nil, contrast: [String] = []) -> Term {
        Term(
            id: id,
            term: id,
            expansion: expansion,
            definitions: Definitions(beginner: "\(id) for beginners", builder: "\(id) for builders", research: "\(id) for researchers"),
            example: example,
            difficulty: difficulty,
            topics: topics,
            contrastWith: contrast,
            isPremium: premium,
            trendingScore: trending
        )
    }

    static var catalog: [Term] {
        (0..<40).map { i in
            let difficulty: Difficulty = [.beginner, .intermediate, .pro][i % 3]
            return term("t\(i)", difficulty: difficulty, topics: [i.isMultiple(of: 2) ? "even" : "odd"],
                        premium: i % 10 == 9, trending: Double(i) / 40,
                        example: "We used t\(i) in production.", expansion: "Term number \(i)")
        }
    }
}
