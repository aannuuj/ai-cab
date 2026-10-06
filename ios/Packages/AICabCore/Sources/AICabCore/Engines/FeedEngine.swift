import Foundation

/// Picks what the Words feed shows next: mostly new words at the learner's level,
/// mixed with spaced-repetition reviews and what's trending.
public struct FeedEngine: Sendable {
    public struct Configuration: Sendable {
        public var batchSize: Int
        public var reviewShare: Double
        public var trendingShare: Double
        /// Don't re-show a word inside this window unless it's a due review.
        public var repeatCooldown: TimeInterval

        public init(batchSize: Int = 20, reviewShare: Double = 0.25, trendingShare: Double = 0.15,
                    repeatCooldown: TimeInterval = 48 * 3600) {
            self.batchSize = batchSize
            self.reviewShare = reviewShare
            self.trendingShare = trendingShare
            self.repeatCooldown = repeatCooldown
        }
    }

    public var configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func batch<R: RandomNumberGenerator>(
        from terms: [Term],
        state: UserState,
        isPro: Bool,
        now: Date,
        excluding excluded: Set<String> = [],
        using rng: inout R
    ) -> [Term] {
        let accessible = terms.filter { (!$0.isPremium || isPro) && !excluded.contains($0.id) }
        guard !accessible.isEmpty else { return [] }

        let topicFilter = Set(state.preferences.topicIds)
        let focused = topicFilter.isEmpty
            ? accessible
            : accessible.filter { !topicFilter.isDisjoint(with: $0.topics) || $0.isCustom }
        let candidates = focused.isEmpty ? accessible : focused

        let size = configuration.batchSize
        var picked: [Term] = []
        var pickedIds = Set<String>()
        func take(_ term: Term) {
            guard picked.count < size, pickedIds.insert(term.id).inserted else { return }
            picked.append(term)
        }

        // 1. Reviews that are due.
        let byId = Dictionary(accessible.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let reviewQuota = Int((Double(size) * configuration.reviewShare).rounded())
        let reviews = SpacedRepetition.dueIds(in: state, now: now).compactMap { byId[$0] }
        reviews.prefix(reviewQuota).forEach(take)

        // 2. Fresh words at the learner's level.
        let level = state.preferences.level
        let unseen = candidates.filter { state.progress[$0.id]?.seenCount ?? 0 == 0 }
        let ranked = unseen
            .map { ($0, Self.affinity(of: $0.difficulty, for: level) + Double.random(in: 0..<0.8, using: &rng)) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        let trendingQuota = Int((Double(size) * configuration.trendingShare).rounded())
        let newQuota = size - picked.count - trendingQuota
        ranked.prefix(max(newQuota, 0)).forEach(take)

        // 3. Trending / recently added.
        let rested = { (term: Term) -> Bool in
            guard let last = state.progress[term.id]?.lastSeenAt else { return true }
            return now.timeIntervalSince(last) > configuration.repeatCooldown
        }
        let trending = candidates
            .filter { rested($0) && !pickedIds.contains($0.id) }
            .sorted { $0.trendingScore > $1.trendingScore }
            .prefix(30)
            .shuffled(using: &rng)
        trending.prefix(trendingQuota).forEach(take)

        // 4. Top up: remaining unseen, then least recently seen.
        if picked.count < size {
            ranked.forEach(take)
        }
        if picked.count < size {
            candidates
                .filter(rested)
                .sorted { (state.progress[$0.id]?.lastSeenAt ?? .distantPast) < (state.progress[$1.id]?.lastSeenAt ?? .distantPast) }
                .forEach(take)
        }
        if picked.count < size {
            candidates.shuffled(using: &rng).forEach(take)
        }

        return Self.interleave(picked, reviews: Set(reviews.map(\.id)))
    }

    /// Spread reviews through the batch so they don't arrive in a clump.
    static func interleave(_ terms: [Term], reviews: Set<String>) -> [Term] {
        var fresh = terms.filter { !reviews.contains($0.id) }
        var due = terms.filter { reviews.contains($0.id) }
        var result: [Term] = []
        var position = 0
        while !fresh.isEmpty || !due.isEmpty {
            if position % 4 == 3, !due.isEmpty {
                result.append(due.removeFirst())
            } else if !fresh.isEmpty {
                result.append(fresh.removeFirst())
            } else {
                result.append(due.removeFirst())
            }
            position += 1
        }
        return result
    }

    static func affinity(of difficulty: Difficulty, for level: Level) -> Double {
        switch (level, difficulty) {
        case (.beginner, .beginner): 3
        case (.beginner, .intermediate): 1.5
        case (.beginner, .pro): 0
        case (.builder, .intermediate): 3
        case (.builder, .beginner): 1.5
        case (.builder, .pro): 1.2
        case (.research, .pro): 3
        case (.research, .intermediate): 2
        case (.research, .beginner): 0.6
        }
    }
}
