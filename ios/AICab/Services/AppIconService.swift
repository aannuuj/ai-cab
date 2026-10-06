import UIKit

/// Alternate app icons (the "Which icon style do you like?" picker).
struct AppIconOption: Identifiable, Hashable {
    /// nil = primary icon.
    let iconName: String?
    let title: String
    let previewAsset: String

    var id: String { iconName ?? "default" }

    static let all: [AppIconOption] = [
        AppIconOption(iconName: nil, title: "Teal", previewAsset: "IconPreview-Default"),
        AppIconOption(iconName: "AppIcon-Paper", title: "Paper", previewAsset: "IconPreview-Paper"),
        AppIconOption(iconName: "AppIcon-Night", title: "Night", previewAsset: "IconPreview-Night"),
        AppIconOption(iconName: "AppIcon-Coral", title: "Coral", previewAsset: "IconPreview-Coral"),
        AppIconOption(iconName: "AppIcon-Olive", title: "Olive", previewAsset: "IconPreview-Olive"),
        AppIconOption(iconName: "AppIcon-Mono", title: "Mono", previewAsset: "IconPreview-Mono"),
    ]
}

enum AppIconService {
    @MainActor
    static func apply(_ name: String?) async {
        guard UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != name else { return }
        try? await UIApplication.shared.setAlternateIconName(name)
    }
}
