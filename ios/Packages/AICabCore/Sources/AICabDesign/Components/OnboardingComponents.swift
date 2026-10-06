import SwiftUI
import AICabCore

/// Dark tactile answer row: outlined capsule with a hard shadow; teal when selected.
public struct TactileOption: View {
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
                        .frame(width: 26)
                }
                Text(title)
                    .font(.system(.title3, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle().strokeBorder(isSelected ? Palette.outline : Palette.textSecondary, lineWidth: isSelected ? 3 : 2.5)
                        .background(Circle().fill(isSelected ? Palette.ivory : .clear))
                    if isSelected {
                        Circle().fill(Palette.outline).padding(8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 30, height: 30)
            }
            .foregroundStyle(isSelected ? Palette.ink : Palette.textPrimary)
            .padding(.horizontal, 24)
            .frame(minHeight: 64)
        }
        .buttonStyle(TactileButtonStyle(fill: isSelected ? Palette.teal : Palette.surface, radius: 32))
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Small stat with an optional laurel wreath, for the welcome screen.
public struct LaurelStat: View {
    let value: String
    let caption: String
    let laurel: Bool

    public init(value: String, caption: String, laurel: Bool = false) {
        self.value = value
        self.caption = caption
        self.laurel = laurel
    }

    public var body: some View {
        HStack(spacing: 4) {
            if laurel { Image(systemName: "laurel.leading").font(.system(size: 34, weight: .light)) }
            VStack(spacing: 2) {
                Text(value).font(.system(laurel ? .title : .title3, design: .serif, weight: .bold))
                Text(caption).font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            if laurel { Image(systemName: "laurel.trailing").font(.system(size: 34, weight: .light)) }
        }
        .foregroundStyle(Palette.textPrimary)
        .accessibilityElement(children: .combine)
    }
}

/// Welcome art: isometric books, a chip and a chat bubble on halftone floors.
public struct WelcomeArt: View {
    @State private var float = false

    public init() {}

    public var body: some View {
        ZStack {
            floor(width: 230, height: 120).offset(x: -40, y: 10)
            floor(width: 230, height: 120).offset(x: 60, y: 120)
            IsoObject(symbol: "books.vertical.fill", palette: .cream, size: 170)
                .offset(x: -40, y: -30)
            IsoObject(symbol: "cpu.fill", palette: .teal, size: 150)
                .offset(x: 60, y: 80)
            IsoObject(symbol: "text.bubble.fill", palette: .teal, size: 92)
                .offset(x: 110, y: float ? -110 : -98)
            IsoDisc(symbol: "sparkles", size: 70, tint: Palette.coral)
                .offset(x: -120, y: float ? 120 : 128)
        }
        .frame(width: 340, height: 360)
        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: float)
        .onAppear { float = true }
        .accessibilityHidden(true)
    }

    private func floor(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(Palette.coral)
            .overlay(Halftone(color: Palette.outline.opacity(0.5), spacing: 7, dot: 2.4)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)))
            .frame(width: width, height: height)
            .modifier(Isometric())
    }
}

/// Teal / halftone-coral / cream flame with the streak count, for the dark streak step.
public struct HalftoneFlame: View {
    let count: Int
    let size: CGFloat
    @State private var flicker = false

    public init(count: Int, size: CGFloat = 220) {
        self.count = count
        self.size = size
    }

    public var body: some View {
        ZStack {
            flame.foregroundStyle(Palette.teal)
                .frame(width: size, height: size)
                .scaleEffect(x: 1, y: flicker ? 1.03 : 0.98, anchor: .bottom)
            ZStack {
                flame.foregroundStyle(Palette.coral)
                Halftone(color: Palette.outline.opacity(0.6), spacing: 6, dot: 2.2)
                    .mask { flame }
            }
            .frame(width: size * 0.74, height: size * 0.74)
            .offset(x: size * 0.04, y: size * 0.12)
            flame.foregroundStyle(Palette.cream)
                .frame(width: size * 0.52, height: size * 0.52)
                .offset(x: size * 0.02, y: size * 0.22)
                .scaleEffect(x: 1, y: flicker ? 0.98 : 1.02, anchor: .bottom)
            Text("\(count)")
                .font(.system(size: size * 0.24, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
                .offset(y: size * 0.3)
                .contentTransition(.numericText())
        }
        .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: flicker)
        .onAppear { flicker = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) day streak")
    }

    private var flame: some View {
        Image(systemName: "flame.fill").resizable().scaledToFit()
    }
}
