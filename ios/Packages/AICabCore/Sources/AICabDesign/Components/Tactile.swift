import SwiftUI

/// The signature "tactile tile": filled shape, 2pt ink outline, hard offset shadow with no blur.
public struct TactileBackground: View {
    var fill: Color
    var radius: CGFloat
    var pressed: Bool
    var outline: Color

    public init(fill: Color = Palette.surface, radius: CGFloat = Metrics.cardRadius, pressed: Bool = false, outline: Color = Palette.outline) {
        self.fill = fill
        self.radius = radius
        self.pressed = pressed
        self.outline = outline
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(outline).offset(y: pressed ? 0 : Metrics.hardShadow)
            shape.fill(fill)
            shape.strokeBorder(outline, lineWidth: Metrics.outline)
        }
    }
}

public extension View {
    /// Wraps content in a tactile tile. Pad the content first.
    func tactileCard(fill: Color = Palette.surface, radius: CGFloat = Metrics.cardRadius) -> some View {
        background(TactileBackground(fill: fill, radius: radius))
            .padding(.bottom, Metrics.hardShadow)
    }
}

/// Buttons that physically press down into their shadow.
public struct TactileButtonStyle: ButtonStyle {
    var fill: Color
    var radius: CGFloat

    public init(fill: Color = Palette.surface, radius: CGFloat = Metrics.cardRadius) {
        self.fill = fill
        self.radius = radius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(TactileBackground(fill: fill, radius: radius, pressed: configuration.isPressed))
            .offset(y: configuration.isPressed ? Metrics.hardShadow : 0)
            .padding(.bottom, Metrics.hardShadow)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

/// Full-width primary call to action ("Install widget", "Try for ₹0.00").
public struct PrimaryButtonStyle: ButtonStyle {
    public enum Kind { case teal, olive, coral }

    var kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    public init(_ kind: Kind = .teal) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(.title3, weight: .bold))
            .foregroundStyle(kind == .olive ? Palette.ivory : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 24)
            .background {
                switch kind {
                case .olive:
                    Capsule().fill(Palette.olive)
                        .shadow(color: Palette.olive.opacity(pressed ? 0.15 : 0.35), radius: pressed ? 4 : 14, y: pressed ? 2 : 8)
                case .teal, .coral:
                    ZStack {
                        Capsule().fill(Palette.outline).offset(y: pressed ? 0 : Metrics.hardShadow)
                        Capsule().fill(kind == .teal ? Palette.teal : Palette.coral)
                        Capsule().strokeBorder(Palette.outline, lineWidth: Metrics.outline)
                    }
                }
            }
            .offset(y: pressed && kind != .olive ? Metrics.hardShadow : 0)
            .scaleEffect(pressed && kind == .olive ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: pressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: pressed) { _, isPressed in isPressed }
    }
}

/// Secondary text-only action under a CTA ("Remind me later").
public struct QuietButtonStyle: ButtonStyle {
    var color: Color

    public init(color: Color = Palette.textPrimary) {
        self.color = color
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, weight: .semibold))
            .foregroundStyle(color.opacity(configuration.isPressed ? 0.5 : 1))
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
    }
}
