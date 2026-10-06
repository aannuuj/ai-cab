import Foundation

enum AppTab: String, Hashable, CaseIterable {
    case today, explore, train, you

    /// Older link hosts (widgets and notifications already on devices) keep working.
    init?(host: String) {
        switch host {
        case "words": self = .today
        case "topics": self = .explore
        case "journey", "practice": self = .train
        case "profile": self = .you
        default: self.init(rawValue: host)
        }
    }
}

/// The two halves of the Train tab.
enum TrainMode: String, Hashable, CaseIterable {
    case path, drills

    var title: String {
        switch self {
        case .path: "Path"
        case .drills: "Drills"
        }
    }
}

/// Where a paywall was opened from — used for copy and analytics.
enum PaywallSource: String {
    case onboarding, crown, banner, lockedTopic, lockedChapter, researchLevel, shareTheme, nudge, settings, ownWords
}

/// App-wide sheets, presented from the root so any screen (or a deep link) can open them.
enum AppSheet: Identifiable {
    case term(String)
    case share(String)
    case paywall(PaywallSource)
    case widgetInstall
    case feedback
    case saveDestination(String)

    var id: String {
        switch self {
        case .term(let id): "term.\(id)"
        case .share(let id): "share.\(id)"
        case .paywall(let source): "paywall.\(source.rawValue)"
        case .widgetInstall: "widget"
        case .feedback: "feedback"
        case .saveDestination(let id): "destination.\(id)"
        }
    }
}

/// `aicab://` URLs used by widgets, notifications and Spotlight.
enum DeepLink: Equatable {
    case term(String)
    case tab(AppTab)
    case train(TrainMode)
    case paywall

    init?(url: URL) {
        guard url.scheme == "aicab" else { return nil }
        let host = url.host() ?? ""
        let path = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "term":
            guard let id = path.first else { return nil }
            self = .term(id)
        case "paywall":
            self = .paywall
        default:
            guard let tab = AppTab(host: host) else { return nil }
            self = .tab(tab)
            if host == "journey" { self = .train(.path) }
            if host == "practice" { self = .train(.drills) }
        }
    }
}
