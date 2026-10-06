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

/// Colours and type for the Words feed. Backgrounds with scenery are drawn by `FeedBackground`.
public struct FeedColors: Sendable {
    public var background: Color
    public var primary: Color
    public var secondary: Color
    public var pill: Color
    public var pillStroke: Color
    public var chrome: Color
    public var font: FeedFont = .serif

    public init(background: Color, primary: Color, secondary: Color, pill: Color, pillStroke: Color, chrome: Color,
                font: FeedFont = .serif) {
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.pill = pill
        self.pillStroke = pillStroke
        self.chrome = chrome
        self.font = font
    }

    /// Big word on the feed, in the theme's typeface.
    public var wordFont: Font { font.display(size: 46) }

    /// Dark text on a light background.
    private static func light(_ background: Color, secondary: Color = Palette.inkSoft, font: FeedFont) -> FeedColors {
        FeedColors(background: background, primary: Palette.ink, secondary: secondary,
                   pill: Palette.ivory.opacity(0.85), pillStroke: Palette.ink.opacity(0.12), chrome: Palette.ink, font: font)
    }

    /// Light text on a dark background.
    private static func dark(_ background: Color, primary: Color = Palette.textPrimary, secondary: Color = Color.white.opacity(0.72),
                             pill: Color = Color.white.opacity(0.14), font: FeedFont) -> FeedColors {
        FeedColors(background: background, primary: primary, secondary: secondary,
                   pill: pill, pillStroke: Color.white.opacity(0.12), chrome: primary, font: font)
    }

    public static func forTheme(_ theme: FeedTheme, custom: CustomFeedTheme? = nil) -> FeedColors {
        let font = theme.font
        switch theme {
        case .cream:
            return FeedColors(background: Palette.paper, primary: Palette.ink, secondary: Palette.inkSoft,
                              pill: Palette.ivory, pillStroke: Palette.ink.opacity(0.12), chrome: Palette.ink, font: font)
        case .charcoal:
            return FeedColors(background: Palette.charcoalDeep, primary: Palette.textPrimary, secondary: Palette.textSecondary,
                              pill: Palette.surface, pillStroke: Color.white.opacity(0.08), chrome: Palette.textPrimary, font: font)
        case .sage:
            return FeedColors(background: Color(hex: 0x3F4630), primary: Palette.cream, secondary: Color(hex: 0xC9CDB4),
                              pill: Color(hex: 0x525A40), pillStroke: Color.white.opacity(0.1), chrome: Palette.cream, font: font)
        case .tide:
            return FeedColors(background: Color(hex: 0xBFDCD8), primary: Palette.ink, secondary: Color(hex: 0x3F5A57),
                              pill: Palette.ivory, pillStroke: Palette.ink.opacity(0.12), chrome: Palette.ink, font: font)
        case .ember:
            return FeedColors(background: Color(hex: 0x2B1E1B), primary: Color(hex: 0xF7E3D7), secondary: Color(hex: 0xC9A596),
                              pill: Color(hex: 0x3E2B26), pillStroke: Palette.coral.opacity(0.25), chrome: Color(hex: 0xF7E3D7), font: font)
        case .dusk: return dark(Color(hex: 0x3B2E4F), primary: Color(hex: 0xFFF1E6), font: font)
        case .mist: return light(Color(hex: 0xC9D3D8), secondary: Color(hex: 0x46525A), font: font)
        case .ocean: return dark(Color(hex: 0x123049), font: font)
        case .aurora: return dark(Color(hex: 0x0E1A2B), font: font)
        case .sand: return light(Color(hex: 0xD9C8AA), secondary: Color(hex: 0x6B5A40), font: font)
        case .contrast:
            return FeedColors(background: .black, primary: .white, secondary: Color.white.opacity(0.85),
                              pill: Color.white.opacity(0.16), pillStroke: Color.white.opacity(0.4), chrome: .white, font: font)
        case .daylight:
            return FeedColors(background: .white, primary: .black, secondary: Color.black.opacity(0.8),
                              pill: Color.black.opacity(0.06), pillStroke: Color.black.opacity(0.35), chrome: .black, font: font)
        case .rose: return light(Color(hex: 0xE8C7CC), secondary: Color(hex: 0x6E4A50), font: font)
        case .terminal:
            return FeedColors(background: Color(hex: 0x0B0F0C), primary: Color(hex: 0x9CF2A6), secondary: Color(hex: 0x6FBF79),
                              pill: Color(hex: 0x16261A), pillStroke: Color(hex: 0x9CF2A6).opacity(0.25), chrome: Color(hex: 0x9CF2A6), font: font)
        case .harvest: return dark(Color(hex: 0x4A2617), primary: Color(hex: 0xFFE9D2), font: font)
        case .moonlit: return dark(Color(hex: 0x111522), primary: Color(hex: 0xF2EEDC), font: font)
        case .frost: return light(Color(hex: 0xDDE8F0), secondary: Color(hex: 0x4A5D6E), font: font)
        case .halftone: return light(Color(hex: 0x9CC9C4), secondary: Color(hex: 0x2F4A47), font: font)
        case .blossom: return light(Color(hex: 0xF4DCDD), secondary: Color(hex: 0x7A5257), font: font)
        case .custom:
            let custom = custom ?? CustomFeedTheme()
            let background = Color(hex: UInt32(truncatingIfNeeded: custom.background))
            return custom.isLight ? light(background, font: custom.font) : dark(background, font: custom.font)
        }
    }

    /// Light themes get dark status bar content.
    public static func isLight(_ theme: FeedTheme, custom: CustomFeedTheme? = nil) -> Bool {
        switch theme {
        case .cream, .tide, .mist, .sand, .daylight, .rose, .frost, .halftone, .blossom: true
        case .custom: (custom ?? CustomFeedTheme()).isLight
        default: false
        }
    }
}

public extension FeedFont {
    func display(size: CGFloat) -> Font {
        switch self {
        case .serif: .system(size: size, weight: .bold, design: .serif)
        case .sans: .system(size: size, weight: .semibold, design: .default)
        case .bold: .system(size: size, weight: .heavy, design: .default)
        case .rounded: .system(size: size, weight: .bold, design: .rounded)
        case .mono: .system(size: size * 0.86, weight: .semibold, design: .monospaced)
        case .italic: .system(size: size, weight: .semibold, design: .serif).italic()
        }
    }
}
