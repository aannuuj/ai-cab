import Foundation

/// Leitner-box spaced repetition. Saved words enter box 1; correct answers promote, misses reset.
public enum SpacedRepetition {
    /// Review interval in days for boxes 1...5.
    public static let intervals = [1, 3, 7, 14, 30]
    public static let masteredBox = 5

    public static func enroll(_ p: inout TermProgress, now: Date, calendar: Calendar = .current) {
        guard p.box == 0 else { return }
        p.box = 1
        p.nextReviewAt = calendar.date(byAdding: .day, value: intervals[0], to: now)
    }

    public static func unenroll(_ p: inout TermProgress) {
        p.box = 0
        p.nextReviewAt = nil
    }

    public static func record(_ p: inout TermProgress, correct: Bool, now: Date, calendar: Calendar = .current) {
        if correct {
            p.correct += 1
            p.box = min(max(p.box, 1) + 1, masteredBox)
        } else {
            p.wrong += 1
            p.box = 1
        }
        p.nextReviewAt = calendar.date(byAdding: .day, value: intervals[p.box - 1], to: now)
    }

    public static func isDue(_ p: TermProgress, now: Date) -> Bool {
        guard p.box > 0, let next = p.nextReviewAt else { return false }
        return next <= now
    }

    public static func dueIds(in state: UserState, now: Date) -> [String] {
        state.progress.values
            .filter { isDue($0, now: now) }
            .sorted { ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast) }
            .map(\.termId)
    }
}
