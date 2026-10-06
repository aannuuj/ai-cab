import SwiftUI
import AICabCore

/// `/ræɡ/ 🔊` — tap to hear the word.
public struct PronunciationPill: View {
    let ipa: String?
    let colors: FeedColors
    let isSpeaking: Bool
    let action: () -> Void

    public init(ipa: String?, colors: FeedColors, isSpeaking: Bool, action: @escaping () -> Void) {
        self.ipa = ipa
        self.colors = colors
        self.isSpeaking = isSpeaking
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let ipa {
                    Text(ipa)
                        .font(.system(.title3, design: .default))
                        .foregroundStyle(colors.primary)
                }
                Image(systemName: "speaker.wave.2")
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(colors.primary)
                    .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(colors.pill))
            .overlay(Capsule().strokeBorder(colors.pillStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ipa.map { "Pronunciation \($0). Play" } ?? "Play pronunciation")
    }
}

/// Daily goal progress at the top of the feed: 🔖 2/5 ━━━━━━
public struct DailyGoalPill: View {
    let saved: Int
    let goal: Int
    let tint: Color

    public init(saved: Int, goal: Int, tint: Color) {
        self.saved = saved
        self.goal = goal
        self.tint = tint
    }

    private var fraction: Double { goal == 0 ? 0 : min(Double(saved) / Double(goal), 1) }
    private var isComplete: Bool { saved >= goal }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isComplete ? "checkmark.seal.fill" : "bookmark")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(isComplete ? Palette.tealDeep : tint)
                .contentTransition(.symbolEffect(.replace))
            Text("\(min(saved, goal))/\(goal)")
                .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.18))
                    Capsule().fill(isComplete ? Palette.teal : tint.opacity(0.75))
                        .frame(width: max(proxy.size.width * fraction, fraction > 0 ? 8 : 0))
                }
            }
            .frame(width: 110, height: 7)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassCapsule()
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: saved)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily goal: \(saved) of \(goal) words saved")
    }
}

/// Teal outlined padlock shown on premium topics and chapters.
public struct LockBadge: View {
    var color: Color

    public init(color: Color = Palette.textPrimary) {
        self.color = color
    }

    public var body: some View {
        Image(systemName: "lock")
            .font(.system(.title3, weight: .medium))
            .foregroundStyle(color)
            .accessibilityLabel("Pro")
    }
}

/// Selectable option row used in onboarding ("I use AI tools every day  ◯").
public struct RadioPill: View {
    let title: String
    let symbol: String?
    let isSelected: Bool
    let action: () -> Void

    public init(_ title: String, symbol: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Palette.olive)
                        .frame(width: 26)
                }
                Text(title)
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle().strokeBorder(isSelected ? Palette.olive : Palette.ink.opacity(0.18), lineWidth: 2)
                    if isSelected {
                        Circle().fill(Palette.olive).padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Palette.ivory)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(isSelected ? Palette.olive : .clear, lineWidth: 2)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Rounded chip used for related terms, filters and themes.
public struct Chip: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool

    public init(_ title: String, systemImage: String? = nil, isSelected: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.system(.subheadline, weight: .semibold))
        .foregroundStyle(isSelected ? Palette.ink : Palette.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(isSelected ? Palette.teal : Palette.surface))
        .overlay(Capsule().strokeBorder(isSelected ? Palette.outline : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1))
    }
}

/// Wrapping horizontal layout for chips.
public struct FlowLayout: Layout {
    var spacing: CGFloat

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
