import UIKit
import AICabDesign

/// UIKit appearance for the pieces SwiftUI doesn't style directly: serif large titles.
enum Appearance {
    static func configure() {
        let serif = { (size: CGFloat, weight: UIFont.Weight) -> UIFont in
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        }
        let nav = UINavigationBar.appearance()
        nav.largeTitleTextAttributes = [
            .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: serif(36, .bold)),
            .foregroundColor: UIColor(Palette.textPrimary),
        ]
        nav.titleTextAttributes = [
            .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: serif(18, .bold)),
            .foregroundColor: UIColor(Palette.textPrimary),
        ]
    }
}
