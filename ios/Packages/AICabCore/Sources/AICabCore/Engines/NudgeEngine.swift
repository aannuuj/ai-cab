import Foundation

/// In-app prompts, at most one at a time, each with its own cooldown.
public enum Nudge: String, Identifiable, Sendable, CaseIterable {
    /// "Loving the app?" pre-prompt before the system rating sheet.
    case review
    /// "Add a widget to your Home Screen".
    case widget
    /// Introduces the Journey tab.
    case journey
    /// Free-trial paywall.
    case paywall

    public var id: String { rawValue }
}

public enum NudgeOutcome: Sendable {
    /// Acted on it — never show again.
    case accepted
    /// "Remind me later".
    case snoozed
    /// Dismissed without choosing.
    case dismissed
}

public struct NudgeContext: Sendable {
    public var now: Date
    public var state: UserState
    public var isPro: Bool
    public var hasWidgetInstalled: Bool
    /// Just hit today's goal — the best moment to ask for a rating.
    public var justCompletedGoal: Bool

    public init(now: Date, state: UserState, isPro: Bool, hasWidgetInstalled: Bool, justCompletedGoal: Bool) {
        self.now = now
        self.state = state
        self.isPro = isPro
        self.hasWidgetInstalled = hasWidgetInstalled
        self.justCompletedGoal = justCompletedGoal
    }
}

public struct NudgeEngine: Sendable {
    public struct Rules: Sendable {
        public var globalCooldown: TimeInterval = 20 * 3600
        public var reviewMinDays = 3
        public var reviewMinSaved = 10
        public var reviewMaxShows = 3
        public var widgetMinSessions = 2
        public var widgetMaxShows = 3
        public var journeyMinSessions = 3
        public var paywallMinDays = 2
        public var paywallMaxShows = 4

        public init() {}
    }

    public var rules: Rules

    public init(rules: Rules = Rules()) {
        self.rules = rules
    }

    public func next(_ context: NudgeContext) -> Nudge? {
        let nudges = context.state.nudges
        let now = context.now
        if let last = nudges.lastNudgeAt, now.timeIntervalSince(last) < rules.globalCooldown {
            return nil
        }
        let daysInstalled = now.timeIntervalSince(nudges.installedAt) / 86_400

        if context.justCompletedGoal,
           !nudges.review.isResolved,
           !nudges.review.isSnoozed(at: now),
           nudges.review.shownCount < rules.reviewMaxShows,
           daysInstalled >= Double(rules.reviewMinDays),
           context.state.learnedCount >= rules.reviewMinSaved {
            return .review
        }

        if !context.hasWidgetInstalled,
           !nudges.widget.isResolved,
           !nudges.widget.isSnoozed(at: now),
           nudges.widget.shownCount < rules.widgetMaxShows,
           nudges.sessionCount >= rules.widgetMinSessions {
            return .widget
        }

        if !nudges.journeyIntroSeen, nudges.sessionCount >= rules.journeyMinSessions {
            return .journey
        }

        if !context.isPro,
           !nudges.paywall.isResolved,
           !nudges.paywall.isSnoozed(at: now),
           nudges.paywall.shownCount < rules.paywallMaxShows,
           daysInstalled >= Double(rules.paywallMinDays) {
            return .paywall
        }

        return nil
    }

    /// Updates bookkeeping after a nudge was shown and answered.
    public func record(_ nudge: Nudge, outcome: NudgeOutcome, now: Date, state: inout NudgeState, calendar: Calendar = .current) {
        state.lastNudgeAt = now
        func apply(_ record: inout PromptRecord, snoozeDays: Int) {
            record.shownCount += 1
            record.lastShownAt = now
            switch outcome {
            case .accepted: record.isResolved = true
            case .snoozed, .dismissed: record.snoozedUntil = calendar.date(byAdding: .day, value: snoozeDays, to: now)
            }
        }
        switch nudge {
        case .review: apply(&state.review, snoozeDays: outcome == .snoozed ? 5 : 30)
        case .widget: apply(&state.widget, snoozeDays: 2)
        case .paywall: apply(&state.paywall, snoozeDays: 3)
        case .journey: state.journeyIntroSeen = true
        }
    }
}
