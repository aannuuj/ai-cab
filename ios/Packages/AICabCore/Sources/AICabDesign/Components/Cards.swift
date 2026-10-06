import SwiftUI
import AICabCore

/// 🔥 "4 day streak" with this week's day dots.
public struct StreakCard: View {
    let streak: Int
    let days: [StreakDay]

    public init(streak: Int, days: [StreakDay]) {
        self.streak = streak
        self.days = days
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        LinearGradient(colors: [Palette.gold, Palette.coral], startPoint: .top, endPoint: .bottom)
                    )
                    .symbolEffect(.bounce, value: streak)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(streak)")
                        .font(.system(.title, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                    Text("day streak")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
            }
            Divider().overlay(Color.white.opacity(0.08))
            HStack(spacing: 0) {
                ForEach(days) { day in
                    VStack(spacing: 10) {
                        Text(day.label)
                            .font(.system(.subheadline, weight: day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isToday ? Palette.textPrimary : Palette.textSecondary)
                        ZStack {
                            Circle()
                                .strokeBorder(day.isComplete ? Palette.outline : Color.white.opacity(day.isFuture ? 0.12 : 0.22), lineWidth: day.isComplete ? 2 : 1.5)
                                .background(Circle().fill(day.isComplete ? Palette.teal : .clear))
                            if day.isComplete {
                                Image(systemName: "checkmark")
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(Palette.ink)
                            }
                        }
                        .frame(width: 36, height: 36)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.label): \(day.isComplete ? "goal met" : "not yet")")
                }
            }
        }
        .padding(22)
        .tactileCard()
    }
}

/// The trial explainer from the paywall: install ✓ → today → reminder → member.
public struct TrialTimeline: View {
    public struct Step: Identifiable {
        public var id: String { title }
        public var symbol: String
        public var title: String
        public var subtitle: String
        public var isDone: Bool
        public var isFinal: Bool

        public init(symbol: String, title: String, subtitle: String, isDone: Bool = false, isFinal: Bool = false) {
            self.symbol = symbol
            self.title = title
            self.subtitle = subtitle
            self.isDone = isDone
            self.isFinal = isFinal
        }
    }

    let steps: [Step]

    public init(steps: [Step]) {
        self.steps = steps
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(step.isFinal ? Palette.lime : Palette.charcoal)
                                .overlay(Circle().strokeBorder(Palette.lime, lineWidth: 3))
                            Image(systemName: step.symbol)
                                .font(.system(.title3, weight: .medium))
                                .foregroundStyle(step.isFinal ? Palette.ink : Palette.lime)
                        }
                        .frame(width: 52, height: 52)
                        if index < steps.count - 1 {
                            Rectangle().fill(Palette.lime).frame(width: 3).frame(minHeight: 30, maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title)
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                            .strikethrough(step.isDone, color: Palette.textPrimary)
                        Text(step.subtitle)
                            .font(.system(.body))
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, index < steps.count - 1 ? 22 : 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// iOS-style notification banner used to preview reminders during onboarding.
public struct NotificationPreview: View {
    let title: String
    let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AppMark(size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("AI-Cab").font(.system(.headline, weight: .bold))
                    Spacer()
                    Text("now").font(.system(.subheadline)).foregroundStyle(Palette.inkSoft)
                }
                Text(title).font(.system(.subheadline, weight: .semibold))
                Text(message).font(.system(.subheadline)).lineLimit(2)
            }
            .foregroundStyle(Palette.ink)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Palette.ivory)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        )
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Palette.ivory.opacity(0.7))
                .padding(.horizontal, 18)
                .offset(y: 12)
        )
        .accessibilityElement(children: .combine)
    }
}

/// The app's monogram, drawn in code so it matches at every size.
public struct AppMark: View {
    let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(Palette.charcoal)
            Text("Ai")
                .font(.system(size: size * 0.48, weight: .bold, design: .serif))
                .foregroundStyle(Palette.teal)
                .offset(y: -size * 0.02)
            Circle().fill(Palette.coral).frame(width: size * 0.13).offset(x: size * 0.25, y: -size * 0.22)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Phone outline holding a widget preview — the "Add a widget" education screen.
public struct PhoneMock<Screen: View>: View {
    let widget: Screen

    public init(@ViewBuilder widget: () -> Screen) {
        self.widget = widget()
    }

    public var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 56, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [Palette.cream.opacity(0.9), Palette.cream.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 3
                )
            VStack(spacing: 22) {
                Capsule().strokeBorder(Palette.cream.opacity(0.9), lineWidth: 2.5).frame(width: 96, height: 30).padding(.top, 14)
                widget.padding(.horizontal, 22)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 4), spacing: 18) {
                    ForEach(0..<8, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Palette.cream.opacity(index < 4 ? 0.45 : 0.2), lineWidth: 2.5)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 28)
            }
        }
        .mask(LinearGradient(colors: [.black, .black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
        .accessibilityHidden(true)
    }
}

/// The word card as it appears inside widgets and the widget preview.
public struct WidgetWordCard: View {
    let word: WidgetWord
    let fill: Color

    public init(word: WidgetWord, fill: Color = Palette.teal) {
        self.word = word
        self.fill = fill
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text(word.term)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("(\(word.pos)) \(word.definition)")
                .font(.system(.body, design: .serif))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 130)
        .background(TactileBackground(fill: fill, radius: 30))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
    }
}
