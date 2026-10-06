import SwiftUI
import AICabCore

/// Full-bleed feed background. Scenic themes are drawn procedurally (no photos to license),
/// so they stay crisp at any size and cost nothing to ship.
public struct FeedBackground: View {
    let theme: FeedTheme
    let custom: CustomFeedTheme?

    public init(theme: FeedTheme, custom: CustomFeedTheme? = nil) {
        self.theme = theme
        self.custom = custom
    }

    public var body: some View {
        let colors = FeedColors.forTheme(theme, custom: custom)
        ZStack {
            colors.background
            scene
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var scene: some View {
        switch theme {
        case .dusk:
            LinearGradient(colors: [Color(hex: 0x2C2445), Color(hex: 0x6B4466), Color(hex: 0xE58F6E)], startPoint: .top, endPoint: .bottom)
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFD7A3), Color(hex: 0xF29E72).opacity(0)], center: .center, startRadius: 0, endRadius: w * 0.45))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .position(x: w * 0.5, y: h * 0.78)
                Hills(seed: 3, amplitude: 0.05, baseline: 0.84).fill(Color(hex: 0x3A2740).opacity(0.9))
                Hills(seed: 7, amplitude: 0.04, baseline: 0.9).fill(Color(hex: 0x241A2E))
            }
        case .mist:
            LinearGradient(colors: [Color(hex: 0xE3E8EA), Color(hex: 0xB9C6CD)], startPoint: .top, endPoint: .bottom)
            Hills(seed: 2, amplitude: 0.07, baseline: 0.72).fill(Color(hex: 0x8C9DA6).opacity(0.35))
            Hills(seed: 5, amplitude: 0.06, baseline: 0.8).fill(Color(hex: 0x6E828C).opacity(0.4))
            Hills(seed: 9, amplitude: 0.05, baseline: 0.9).fill(Color(hex: 0x4F636D).opacity(0.5))
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.35)], startPoint: .center, endPoint: .bottom)
        case .ocean:
            LinearGradient(colors: [Color(hex: 0x0D2236), Color(hex: 0x1C4A66), Color(hex: 0x2E7187)], startPoint: .top, endPoint: .bottom)
            ForEach(0..<6, id: \.self) { band in
                Waves(phase: Double(band) * 0.9, amplitude: 10 + Double(band) * 2, baseline: 0.58 + Double(band) * 0.07)
                    .stroke(Color.white.opacity(0.06 + Double(band) * 0.015), lineWidth: 1.5)
            }
        case .aurora:
            LinearGradient(colors: [Color(hex: 0x081221), Color(hex: 0x10263A)], startPoint: .top, endPoint: .bottom)
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                Ellipse().fill(Color(hex: 0x4FE3B0).opacity(0.38)).frame(width: w * 1.1, height: h * 0.18)
                    .rotationEffect(.degrees(-18)).position(x: w * 0.4, y: h * 0.22).blur(radius: 40)
                Ellipse().fill(Color(hex: 0x6C8CFF).opacity(0.3)).frame(width: w * 0.9, height: h * 0.14)
                    .rotationEffect(.degrees(-8)).position(x: w * 0.7, y: h * 0.32).blur(radius: 46)
                Stars(seed: 11, count: 70).fill(Color.white.opacity(0.7))
            }
        case .sand:
            Grain(seed: 4, density: 0.0016).fill(Color(hex: 0x6B5A40).opacity(0.18))
        case .harvest:
            LinearGradient(colors: [Color(hex: 0x3B1D12), Color(hex: 0x7A3A1C), Color(hex: 0xC2672B)], startPoint: .top, endPoint: .bottom)
            Scatter(symbol: "leaf.fill", seed: 21, count: 18, tint: Color(hex: 0xF0A04B).opacity(0.35))
        case .moonlit:
            LinearGradient(colors: [Color(hex: 0x0B0E18), Color(hex: 0x1B2036)], startPoint: .top, endPoint: .bottom)
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                Stars(seed: 5, count: 90).fill(Color.white.opacity(0.75))
                Circle().fill(Color(hex: 0xF4EFD9))
                    .overlay(Circle().fill(Color(hex: 0xD9D2B6)).frame(width: w * 0.06).offset(x: -w * 0.04, y: w * 0.03))
                    .overlay(Circle().fill(Color(hex: 0xDDD6BC)).frame(width: w * 0.04).offset(x: w * 0.05, y: -w * 0.04))
                    .frame(width: w * 0.28, height: w * 0.28)
                    .shadow(color: Color(hex: 0xF4EFD9).opacity(0.5), radius: 40)
                    .position(x: w * 0.5, y: h * 0.14)
                Hills(seed: 13, amplitude: 0.03, baseline: 0.92).fill(Color(hex: 0x070910))
            }
        case .frost:
            LinearGradient(colors: [Color(hex: 0xF2F6F9), Color(hex: 0xC8D9E6)], startPoint: .top, endPoint: .bottom)
            Scatter(symbol: "snowflake", seed: 8, count: 22, tint: Color(hex: 0x7F9CB5).opacity(0.3))
        case .halftone:
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                ZStack {
                    Circle().fill(Palette.coral)
                    Halftone(color: Palette.outline.opacity(0.35), spacing: 9, dot: 3).clipShape(Circle())
                }
                .frame(width: w * 0.95, height: w * 0.95)
                .position(x: w * 0.85, y: h * 0.12)
                Rectangle().fill(Palette.cream).frame(height: h * 0.16).position(x: w / 2, y: h * 0.92)
                Halftone(color: Palette.outline.opacity(0.2), spacing: 8, dot: 2).frame(height: h * 0.16).position(x: w / 2, y: h * 0.92)
            }
        case .blossom:
            LinearGradient(colors: [Color(hex: 0xF7E6E4), Color(hex: 0xEFC9CE)], startPoint: .top, endPoint: .bottom)
            Scatter(symbol: "camera.macro", seed: 17, count: 14, tint: Color(hex: 0xC86F7E).opacity(0.28))
        case .terminal:
            Scanlines().fill(Color(hex: 0x9CF2A6).opacity(0.04))
        case .cream, .tide:
            Halftone(color: Palette.ink.opacity(0.035), spacing: 10, dot: 1.4)
        default:
            EmptyView()
        }
    }
}

// MARK: - Shapes

/// Deterministic pseudo-random numbers so scenes look the same on every launch.
struct SeededRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 33) / Double(UInt64(1) << 31)
    }
}

/// Rolling hill silhouette filling to the bottom edge.
struct Hills: Shape {
    let seed: UInt64
    let amplitude: Double
    let baseline: Double

    func path(in rect: CGRect) -> Path {
        var random = SeededRandom(seed)
        let phase = random.next() * .pi * 2
        let frequency = 1.2 + random.next() * 1.4
        return Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            for step in 0...60 {
                let x = Double(step) / 60
                let y = baseline - amplitude * (sin(x * .pi * 2 * frequency + phase) * 0.6 + sin(x * .pi * 5.3 + phase * 1.7) * 0.4)
                p.addLine(to: CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height))
            }
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// One sine line across the width.
struct Waves: Shape {
    let phase: Double
    let amplitude: Double
    let baseline: Double

    func path(in rect: CGRect) -> Path {
        Path { p in
            for step in 0...80 {
                let x = Double(step) / 80
                let y = rect.minY + baseline * rect.height + amplitude * sin(x * .pi * 4 + phase)
                let point = CGPoint(x: rect.minX + x * rect.width, y: y)
                if step == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
        }
    }
}

/// Small dots for a night sky (upper two thirds).
struct Stars: Shape {
    let seed: UInt64
    let count: Int

    func path(in rect: CGRect) -> Path {
        var random = SeededRandom(seed)
        return Path { p in
            for _ in 0..<count {
                let r = 0.6 + random.next() * 1.4
                let x = rect.minX + random.next() * rect.width
                let y = rect.minY + random.next() * rect.height * 0.66
                p.addEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
            }
        }
    }
}

/// Paper grain.
struct Grain: Shape {
    let seed: UInt64
    let density: Double

    func path(in rect: CGRect) -> Path {
        var random = SeededRandom(seed)
        let count = Int(rect.width * rect.height * density)
        return Path { p in
            for _ in 0..<count {
                let x = rect.minX + random.next() * rect.width
                let y = rect.minY + random.next() * rect.height
                p.addRect(CGRect(x: x, y: y, width: 1.2, height: 1.2))
            }
        }
    }
}

/// CRT-style horizontal lines.
struct Scanlines: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            var y = rect.minY
            while y < rect.maxY {
                p.addRect(CGRect(x: rect.minX, y: y, width: rect.width, height: 1))
                y += 4
            }
        }
    }
}

/// Symbols sprinkled across the background (leaves, snowflakes, flowers).
struct Scatter: View {
    let symbol: String
    let seed: UInt64
    let count: Int
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let items = Self.layout(seed: seed, count: count)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Image(systemName: symbol)
                    .font(.system(size: item.size))
                    .foregroundStyle(tint)
                    .rotationEffect(.degrees(item.angle))
                    .position(x: item.x * proxy.size.width, y: item.y * proxy.size.height)
            }
        }
    }

    private static func layout(seed: UInt64, count: Int) -> [(x: Double, y: Double, size: Double, angle: Double)] {
        var random = SeededRandom(seed)
        return (0..<count).map { _ in
            (random.next(), random.next(), 14 + random.next() * 26, random.next() * 360 - 180)
        }
    }
}
