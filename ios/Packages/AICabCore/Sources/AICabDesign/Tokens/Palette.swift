import SwiftUI
import AICabCore

public extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Brand colours. Charcoal for browsing and play, cream for reading, teal + coral as accents.
public enum Palette {
    public static let charcoal = Color(hex: 0x2A2A2C)
    public static let charcoalDeep = Color(hex: 0x1C1C1E)
    public static let surface = Color(hex: 0x3A3A3C)
    public static let surfaceRaised = Color(hex: 0x454547)
    public static let outline = Color(hex: 0x0E0E0F)

    public static let cream = Color(hex: 0xF1EFE8)
    public static let paper = Color(hex: 0xECE9DF)
    public static let ivory = Color(hex: 0xFCFBF7)
    public static let ink = Color(hex: 0x1D1E1A)
    public static let inkSoft = Color(hex: 0x5D5E58)

    public static let teal = Color(hex: 0x8EC3BF)
    public static let tealDeep = Color(hex: 0x5E9E99)
    public static let coral = Color(hex: 0xEE8B7E)
    public static let olive = Color(hex: 0x4B5230)
    public static let oliveSoft = Color(hex: 0x8E9670)
    public static let lime = Color(hex: 0xB5D98A)
    public static let gold = Color(hex: 0xF2C66D)

    public static let textPrimary = Color(hex: 0xF4F3EF)
    public static let textSecondary = Color(hex: 0xA3A3A6)
    public static let textTertiary = Color(hex: 0x6C6C70)

    public static func art(_ palette: ArtPalette) -> (fill: Color, shadow: Color) {
        switch palette {
        case .teal: (teal, coral)
        case .coral: (coral, teal)
        case .cream: (cream, coral)
        case .olive: (oliveSoft, teal)
        }
    }
}

/// Colours for the Words feed, which the reader can switch between paper and night.
public struct FeedColors: Sendable {
    public var background: Color
    public var primary: Color
    public var secondary: Color
    public var pill: Color
    public var pillStroke: Color
    public var chrome: Color

    public static func forTheme(_ theme: FeedTheme) -> FeedColors {
        switch theme {
        case .cream:
            FeedColors(background: Palette.paper, primary: Palette.ink, secondary: Palette.inkSoft,
                       pill: Palette.ivory, pillStroke: Palette.ink.opacity(0.12), chrome: Palette.ink)
        case .charcoal:
            FeedColors(background: Palette.charcoalDeep, primary: Palette.textPrimary, secondary: Palette.textSecondary,
                       pill: Palette.surface, pillStroke: Color.white.opacity(0.08), chrome: Palette.textPrimary)
        case .sage:
            FeedColors(background: Color(hex: 0x3F4630), primary: Palette.cream, secondary: Color(hex: 0xC9CDB4),
                       pill: Color(hex: 0x525A40), pillStroke: Color.white.opacity(0.1), chrome: Palette.cream)
        case .tide:
            FeedColors(background: Color(hex: 0xBFDCD8), primary: Palette.ink, secondary: Color(hex: 0x3F5A57),
                       pill: Palette.ivory, pillStroke: Palette.ink.opacity(0.12), chrome: Palette.ink)
        case .ember:
            FeedColors(background: Color(hex: 0x2B1E1B), primary: Color(hex: 0xF7E3D7), secondary: Color(hex: 0xC9A596),
                       pill: Color(hex: 0x3E2B26), pillStroke: Palette.coral.opacity(0.25), chrome: Color(hex: 0xF7E3D7))
        }
    }

    /// Light themes get dark status bar content.
    public static func isLight(_ theme: FeedTheme) -> Bool {
        theme == .cream || theme == .tide
    }
}
