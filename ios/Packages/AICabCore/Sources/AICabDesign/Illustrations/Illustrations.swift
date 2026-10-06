import SwiftUI
import AICabCore

/// Coral halftone dots — the printed-shadow texture under illustrated objects.
public struct Halftone: View {
    var color: Color
    var spacing: CGFloat
    var dot: CGFloat

    public init(color: Color = Palette.coral, spacing: CGFloat = 5, dot: CGFloat = 1.6) {
        self.color = color
        self.spacing = spacing
        self.dot = dot
    }

    public var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: .color(color))
                    x += spacing
                }
                y += spacing
                row += 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// An isometric "object" drawn from an SF Symbol: a thick tactile token tilted onto the floor,
/// sitting on a halftone shadow. Used for topic cards and Journey decorations.
public struct IsoObject: View {
    let symbol: String
    let palette: ArtPalette
    let size: CGFloat

    public init(symbol: String, palette: ArtPalette = .teal, size: CGFloat = 96) {
        self.symbol = symbol
        self.palette = palette
        self.size = size
    }

    public var body: some View {
        let art = Palette.art(palette)
        ZStack {
            // Floor shadow.
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(art.shadow.opacity(0.9))
                .overlay(Halftone(color: Palette.outline.opacity(0.35), spacing: 4.5, dot: 1.4)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)))
                .frame(width: size * 0.82, height: size * 0.82)
                .modifier(Isometric())
                .offset(x: size * 0.06, y: size * 0.16)
            // Token thickness.
            ForEach(0..<3, id: \.self) { layer in
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Palette.outline)
                    .frame(width: size * 0.78, height: size * 0.78)
                    .modifier(Isometric())
                    .offset(y: CGFloat(3 - layer) * size * 0.025)
            }
            // Face.
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Palette.cream)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .strokeBorder(Palette.outline, lineWidth: 2.5)
                )
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(Palette.outline, art.fill)
                        .symbolRenderingMode(.palette)
                )
                .frame(width: size * 0.78, height: size * 0.78)
                .modifier(Isometric())
        }
        .frame(width: size, height: size * 0.9)
        .accessibilityHidden(true)
    }
}

/// Classic isometric projection: rotate 45°, squash vertically.
public struct Isometric: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(45))
            .scaleEffect(x: 1, y: 0.58)
    }
}

/// A disc-shaped "face" token like the emotion faces on the reference Journey screen.
public struct IsoDisc: View {
    let symbol: String
    let size: CGFloat
    let tint: Color

    public init(symbol: String, size: CGFloat = 70, tint: Color = Palette.teal) {
        self.symbol = symbol
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            Ellipse().fill(Palette.outline).frame(width: size, height: size * 0.62).offset(y: size * 0.09)
            Ellipse().fill(tint).frame(width: size, height: size * 0.62).offset(y: size * 0.05)
            Ellipse().fill(Palette.cream)
                .overlay(Ellipse().strokeBorder(Palette.outline, lineWidth: 2))
                .frame(width: size, height: size * 0.62)
            Image(systemName: symbol)
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(Palette.outline)
                .scaleEffect(x: 1, y: 0.7)
        }
        .frame(width: size, height: size * 0.75)
        .accessibilityHidden(true)
    }
}

/// Journey path stop: a chunky isometric tile with an icon, in locked / available / done states.
public struct IsoLessonTile: View {
    public enum State { case locked, available, completed, current }

    let symbol: String
    let state: State
    let size: CGFloat

    public init(symbol: String, state: State, size: CGFloat = 150) {
        self.symbol = symbol
        self.state = state
        self.size = size
    }

    private var faceColor: Color {
        switch state {
        case .completed: Palette.teal
        case .current: Palette.cream
        case .available: Palette.surfaceRaised
        case .locked: Palette.surface
        }
    }

    private var iconColor: Color {
        switch state {
        case .completed, .current: Palette.ink
        case .available: Palette.textPrimary
        case .locked: Palette.textTertiary
        }
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
        ZStack {
            shape.fill(Color.black.opacity(0.35))
                .frame(width: size * 0.66, height: size * 0.66)
                .modifier(Isometric())
                .offset(y: size * 0.13)
                .blur(radius: 6)
            ForEach(0..<5, id: \.self) { layer in
                shape.fill(layer == 0 ? Palette.outline : faceColor.mix(with: .black, by: 0.35))
                    .overlay(shape.strokeBorder(Palette.outline.opacity(0.9), lineWidth: 1.5))
                    .frame(width: size * 0.62, height: size * 0.62)
                    .modifier(Isometric())
                    .offset(y: CGFloat(5 - layer) * size * 0.018)
            }
            shape.fill(faceColor)
                .overlay(shape.strokeBorder(state == .locked ? Palette.textTertiary.opacity(0.6) : Palette.outline, lineWidth: 2))
                .frame(width: size * 0.62, height: size * 0.62)
                .modifier(Isometric())
            Image(systemName: state == .locked ? "lock.fill" : (state == .completed ? "checkmark" : symbol))
                .font(.system(size: size * 0.17, weight: .bold))
                .foregroundStyle(iconColor)
                .scaleEffect(x: 1, y: 0.8)
                .rotation3DEffect(.degrees(48), axis: (x: 1, y: 0, z: 0))
                .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size * 0.62)
    }
}

/// Welcome illustration: a tree whose canopy is a neural network, two readers beneath it.
public struct NeuralTree: View {
    @State private var pulse = false

    public init() {}

    public var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let ground = CGRect(x: w * 0.06, y: h * 0.86, width: w * 0.88, height: h * 0.07)
            context.fill(Path(ellipseIn: ground), with: .color(Palette.inkSoft.opacity(0.12)))

            // Trunk and branches.
            var trunk = Path()
            trunk.move(to: CGPoint(x: w * 0.46, y: h * 0.88))
            trunk.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.48), control1: CGPoint(x: w * 0.44, y: h * 0.7), control2: CGPoint(x: w * 0.52, y: h * 0.6))
            trunk.addLine(to: CGPoint(x: w * 0.53, y: h * 0.48))
            trunk.addCurve(to: CGPoint(x: w * 0.56, y: h * 0.88), control1: CGPoint(x: w * 0.55, y: h * 0.62), control2: CGPoint(x: w * 0.53, y: h * 0.72))
            trunk.closeSubpath()
            context.fill(trunk, with: .color(Color(hex: 0x6E5A4E)))

            let branchTips: [CGPoint] = [
                CGPoint(x: w * 0.22, y: h * 0.36), CGPoint(x: w * 0.36, y: h * 0.22), CGPoint(x: w * 0.52, y: h * 0.16),
                CGPoint(x: w * 0.68, y: h * 0.22), CGPoint(x: w * 0.82, y: h * 0.36),
            ]
            for tip in branchTips {
                var branch = Path()
                branch.move(to: CGPoint(x: w * 0.51, y: h * 0.52))
                branch.addQuadCurve(to: tip, control: CGPoint(x: (w * 0.51 + tip.x) / 2, y: h * 0.42))
                context.stroke(branch, with: .color(Color(hex: 0x6E5A4E)), style: StrokeStyle(lineWidth: w * 0.012, lineCap: .round))
            }

            // Canopy: three layers of nodes, fully connected.
            let layers: [[CGPoint]] = [
                (0..<5).map { CGPoint(x: w * (0.18 + 0.16 * Double($0)), y: h * 0.36) },
                (0..<6).map { CGPoint(x: w * (0.14 + 0.144 * Double($0)), y: h * 0.24) },
                (0..<4).map { CGPoint(x: w * (0.26 + 0.16 * Double($0)), y: h * 0.11) },
            ]
            for (a, b) in zip(layers, layers.dropFirst()) {
                for p in a {
                    for q in b {
                        var edge = Path()
                        edge.move(to: p)
                        edge.addLine(to: q)
                        context.stroke(edge, with: .color(Palette.olive.opacity(0.28)), lineWidth: 1.2)
                    }
                }
            }
            let canopyColors = [Palette.oliveSoft, Color(hex: 0x6F7A48), Palette.tealDeep, Palette.coral]
            for (li, layer) in layers.enumerated() {
                for (pi, p) in layer.enumerated() {
                    let r = w * (li == 1 ? 0.05 : 0.042)
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect.insetBy(dx: -r * 0.7, dy: -r * 0.7)), with: .color(Palette.oliveSoft.opacity(0.18)))
                    context.fill(Path(ellipseIn: rect), with: .color(canopyColors[(li + pi) % canopyColors.count]))
                    context.stroke(Path(ellipseIn: rect), with: .color(Palette.ink.opacity(0.65)), lineWidth: 1.5)
                }
            }
        }
        .overlay(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 0) {
                Reader(shirt: Color(hex: 0x56613A), facing: .left)
                Spacer(minLength: 0)
                Reader(shirt: Color(hex: 0xC49A6C), facing: .right, hair: Palette.coral)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .scaleEffect(pulse ? 1.01 : 1)
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }

    private struct Reader: View {
        enum Facing { case left, right }
        var shirt: Color
        var facing: Facing
        var hair: Color = Palette.ink

        var body: some View {
            HStack(alignment: .bottom, spacing: 4) {
                if facing == .right { book }
                VStack(spacing: 2) {
                    Circle().fill(Color(hex: 0xE2B48C)).frame(width: 26, height: 26)
                        .overlay(alignment: .top) { Capsule().fill(hair).frame(width: 28, height: 12).offset(y: -2) }
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(shirt).frame(width: 42, height: 48)
                    Capsule().fill(Palette.ink).frame(width: 70, height: 14)
                        .offset(x: facing == .left ? -18 : 18)
                }
                if facing == .left { book }
            }
        }

        private var book: some View {
            RoundedRectangle(cornerRadius: 3).fill(Palette.ivory)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.ink, lineWidth: 1.5))
                .frame(width: 26, height: 18)
                .rotationEffect(.degrees(facing == .left ? -18 : 18))
                .padding(.bottom, 54)
        }
    }
}

/// Burst of brand-coloured pieces for goal completion.
public struct ConfettiBurst: View {
    let trigger: Int
    @State private var pieces: [Piece] = []

    public init(trigger: Int) {
        self.trigger = trigger
    }

    struct Piece: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var color: Color
        var shape: Int
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    Group {
                        if piece.shape == 0 {
                            Circle().fill(piece.color).frame(width: 10, height: 10)
                        } else if piece.shape == 1 {
                            RoundedRectangle(cornerRadius: 2).fill(piece.color).frame(width: 8, height: 16)
                        } else {
                            Image(systemName: "sparkle").font(.system(size: 14, weight: .bold)).foregroundStyle(piece.color)
                        }
                    }
                    .rotationEffect(.degrees(piece.rotation))
                    .position(x: piece.x, y: piece.y)
                }
            }
            .onChange(of: trigger) {
                burst(in: proxy.size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func burst(in size: CGSize) {
        let colors = [Palette.teal, Palette.coral, Palette.gold, Palette.lime, Palette.cream]
        let origin = CGPoint(x: size.width / 2, y: size.height * 0.4)
        pieces = (0..<36).map { i in
            Piece(x: origin.x, y: origin.y, rotation: 0, color: colors[i % colors.count], shape: i % 3)
        }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.65)) {
            pieces = pieces.map { piece in
                var p = piece
                let angle = Double.random(in: 0..<(2 * .pi))
                let distance = CGFloat.random(in: 60...max(min(size.width, 260), 61))
                p.x = origin.x + cos(angle) * distance
                p.y = origin.y + sin(angle) * distance * 0.8 - 40
                p.rotation = Double.random(in: -200...200)
                return p
            }
        }
        withAnimation(.easeIn(duration: 0.8).delay(1.1)) {
            pieces = pieces.map { piece in
                var p = piece
                p.y += size.height
                return p
            }
        }
    }
}
