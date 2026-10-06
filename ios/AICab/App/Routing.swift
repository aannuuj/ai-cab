import Foundation

enum AppTab: String, Hashable, CaseIterable {
    case words, topics, journey, practice, profile
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

    var id: String {
        switch self {
        case .term(let id): "term.\(id)"
        case .share(let id): "share.\(id)"
        case .paywall(let source): "paywall.\(source.rawValue)"
        case .widgetInstall: "widget"
        case .feedback: "feedback"
        }
    }
}

/// `aicab://` URLs used by widgets, notifications and Spotlight.
enum DeepLink: Equatable {
    case term(String)
    case tab(AppTab)
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
            guard let tab = AppTab(rawValue: host) else { return nil }
            self = .tab(tab)
        }
    }
}
