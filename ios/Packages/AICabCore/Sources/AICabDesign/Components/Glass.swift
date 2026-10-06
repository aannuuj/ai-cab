import SwiftUI

/// Liquid Glass on iOS 26+, with a material fallback on earlier systems.
public extension View {
    @ViewBuilder
    func glassCapsule(interactive: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(Self.glass(interactive: interactive, tint: tint), in: Capsule())
        } else {
            self.background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func glassCircle(interactive: Bool = true, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(Self.glass(interactive: interactive, tint: tint), in: Circle())
        } else {
            self.background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func glassRounded(_ radius: CGFloat = Metrics.cardRadius, interactive: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(Self.glass(interactive: interactive, tint: tint), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            self.background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial))
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func glass(interactive: Bool, tint: Color?) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

/// Round glass icon button used for the crown, close and toolbar-style actions.
public struct GlassIconButton: View {
    let systemImage: String
    let size: CGFloat
    let tint: Color
    let badge: Bool
    let accessibilityLabel: String
    let action: () -> Void

    public init(_ systemImage: String, size: CGFloat = 52, tint: Color = .primary, badge: Bool = false,
                accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.size = size
        self.tint = tint
        self.badge = badge
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCircle()
        .overlay(alignment: .topLeading) {
            if badge {
                Circle().fill(Palette.teal).frame(width: 12, height: 12).offset(x: 4, y: 4)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
