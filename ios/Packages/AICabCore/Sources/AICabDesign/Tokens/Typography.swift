import SwiftUI

/// Serif (New York) for display and words, SF Pro for UI. Everything scales with Dynamic Type.
public extension Font {
    static let wordDisplay = Font.system(size: 46, weight: .bold, design: .serif)
    static let serifLargeTitle = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let serifTitle = Font.system(.title, design: .serif, weight: .bold)
    static let serifTitle2 = Font.system(.title2, design: .serif, weight: .bold)
    static let serifTitle3 = Font.system(.title3, design: .serif, weight: .semibold)
    static let definition = Font.system(.title3, design: .default, weight: .regular)
    static let eyebrow = Font.system(.footnote, design: .default, weight: .semibold)
    static let cardTitle = Font.system(.title3, design: .default, weight: .semibold)
}

public enum Metrics {
    public static let gutter: CGFloat = 20
    public static let cardRadius: CGFloat = 28
    public static let tileRadius: CGFloat = 32
    public static let outline: CGFloat = 2
    public static let hardShadow: CGFloat = 4
}

/// Letter-spaced caps label: "CHAPTER 2".
public struct Eyebrow: View {
    let text: String
    var color: Color

    public init(_ text: String, color: Color = Palette.textSecondary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.eyebrow)
            .tracking(3.5)
            .foregroundStyle(color)
    }
}
