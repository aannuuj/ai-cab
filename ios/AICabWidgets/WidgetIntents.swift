import AppIntents
import WidgetKit
import AICabCore

/// Widget style, chosen in the widget's edit sheet.
enum WidgetTheme: String, AppEnum {
    case paper, night, teal

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Style"
    static var caseDisplayRepresentations: [WidgetTheme: DisplayRepresentation] = [
        .paper: "Paper",
        .night: "Night",
        .teal: "Teal",
    ]
}

struct WordWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Word of the hour"
    static var description = IntentDescription("A new AI word every hour, at your level.")

    @Parameter(title: "Style", default: .paper)
    var theme: WidgetTheme

    @Parameter(title: "Show example", default: true)
    var showExample: Bool
}

/// Bookmark button inside the widget. Writes to the shared inbox; the app merges it on next launch.
struct ToggleSaveWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Save word"
    static var description = IntentDescription("Adds the current word to your AI-Cab deck.")
    static var isDiscoverable = false

    @Parameter(title: "Word")
    var termID: String

    init() {}

    init(termID: String) {
        self.termID = termID
    }

    func perform() async throws -> some IntentResult {
        WidgetStore().toggleSaved(termId: termID)
        return .result()
    }
}

/// Skip to the next word without waiting for the hour.
struct NextWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Next word"
    static var description = IntentDescription("Shows the next AI word.")
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        WidgetStore().advanceCursor()
        return .result()
    }
}
