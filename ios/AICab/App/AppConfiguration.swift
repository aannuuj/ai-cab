import Foundation

/// Build-time configuration read from Info.plist (set in project.yml). No secrets live in the app.
struct AppConfiguration: Sendable {
    /// Static JSON manifest for weekly content drops. Empty = bundled content only.
    var contentManifestURL: URL?
    /// Optional serverless endpoint that drafts definitions for "Your own words".
    var defineEndpoint: URL?
    /// Needed for Instagram Stories sharing; the Stories button hides when empty.
    var facebookAppID: String?
    var privacyURL: URL
    var termsURL: URL
    var supportEmail: String
    var appStoreID: String?
    var build: Int

    static let current: AppConfiguration = {
        let info = Bundle.main.infoDictionary ?? [:]
        func string(_ key: String) -> String? {
            guard let value = info[key] as? String else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
        }
        return AppConfiguration(
            contentManifestURL: string("AICabContentManifestURL").flatMap(URL.init(string:)),
            defineEndpoint: string("AICabDefineURL").flatMap(URL.init(string:)),
            facebookAppID: string("AICabFacebookAppID"),
            privacyURL: string("AICabPrivacyURL").flatMap(URL.init(string:)) ?? URL(string: "https://aannuuj.github.io/ai-cab/privacy")!,
            termsURL: string("AICabTermsURL").flatMap(URL.init(string:)) ?? URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
            supportEmail: string("AICabSupportEmail") ?? "hello@aicab.app",
            appStoreID: string("AICabAppStoreID"),
            build: Int(string("CFBundleVersion") ?? "1") ?? 1
        )
    }()
}
