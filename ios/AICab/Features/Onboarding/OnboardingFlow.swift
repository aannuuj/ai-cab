import SwiftUI
import AICabCore
import AICabDesign

/// First-run flow:
/// welcome → tailor → role → familiarity → goal → topics → streak → reminders → theme → icon → widget → trial.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model

    enum Step: Int, CaseIterable {
        case welcome, tailor, role, familiarity, motivation, topics, streak, reminders, theme, icon, widget, paywall

        /// Dark "tactile" steps vs. light cream question steps (mirrors the reference flow).
        var isDark: Bool { [.tailor, .theme, .icon, .widget, .paywall].contains(self) }
        var showsProgress: Bool { rawValue >= Step.role.rawValue && rawValue <= Step.reminders.rawValue }
    }

    @State private var step: Step = Self.initialStep

    private static var initialStep: Step {
        switch ScreenshotMode.current {
        case .tailor: .tailor
        case .streak: .streak
        case .themes: .theme
        case .icons: .icon
        default: .welcome
        }
    }
    @State private var forward = true
    @State private var role: Role?
    @State private var familiarity: Familiarity?
    @State private var motivation: Motivation?
    @State private var topicIDs: Set<String> = []
    @State private var reminders = ReminderSettings(isEnabled: true, perDay: 3)
    @State private var theme: FeedTheme = .cream
    @State private var appIcon: AppIconOption = AppIconOption.all[0]

    var body: some View {
        ZStack {
            (step.isDark ? Palette.charcoal : Palette.cream).ignoresSafeArea()
            VStack(spacing: 0) {
                if step.showsProgress { topBar }
                Group {
                    switch step {
                    case .welcome: welcome
                    case .tailor: tailor
                    case .role: roleStep
                    case .familiarity: familiarityStep
                    case .motivation: motivationStep
                    case .topics: topicsStep
                    case .streak: streakStep
                    case .reminders: remindersStep
                    case .theme: themeStep
                    case .icon: iconStep
                    case .widget: WidgetInstallView(mode: .onboarding) { go(to: .paywall) }
                    case .paywall: PaywallView(source: .onboarding) { finish() }
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: step)
        .sensoryFeedback(.selection, trigger: step)
    }

    private var topBar: some View {
        let first = Step.role.rawValue
        let total = Step.reminders.rawValue - first + 1
        let done = step.rawValue - first + 1
        return HStack(spacing: 16) {
            Button {
                if let previous = Step(rawValue: step.rawValue - 1) { go(to: previous, forward: false) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Back")
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.ink.opacity(0.1))
                    Capsule().fill(Palette.olive)
                        .frame(width: proxy.size.width * CGFloat(done) / CGFloat(total))
                }
            }
            .frame(height: 6)
            Group {
                if step == .role {
                    Button("Skip") {
                        role = nil
                        go(to: .familiarity)
                    }
                    .font(.headline)
                    .foregroundStyle(Palette.inkSoft)
                } else {
                    Color.clear
                }
            }
            .frame(width: 44)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            NeuralTree()
                .frame(height: 340)
                .padding(.horizontal, 12)
            VStack(spacing: 14) {
                Text("Speak fluent AI\nin 1 minute a day")
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Learn \(model.content.terms.count)+ AI words, from \u{201C}token\u{201D} to \u{201C}test-time compute\u{201D}, with a daily habit that takes just a minute.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.inkSoft)
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 24)
            Spacer()
            Button("Get started") { go(to: .tailor) }
                .buttonStyle(PrimaryButtonStyle(.olive))
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 12)
        }
    }

    private var tailor: some View {
        VStack(spacing: 28) {
            Spacer()
            StairsIllustration()
            Text("Tailor your word\nrecommendations")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textPrimary)
            Text("Four quick questions so your feed starts at the right level, on the topics you care about.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 12)
            Spacer()
            Button("Continue") { go(to: .role) }
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 8)
    }

    private var roleStep: some View {
        QuestionStep(title: "What do you do?",
                     subtitle: "We'll mix in words from your world.",
                     canContinue: role != nil,
                     onContinue: { go(to: .familiarity) }) {
            ForEach(Role.allCases) { option in
                RadioPill(option.title, symbol: option.symbol, isSelected: role == option) { role = option }
            }
        }
    }

    private var familiarityStep: some View {
        QuestionStep(title: "How familiar are you with AI?",
                     subtitle: "We'll pick the right depth for definitions. You can switch any time.",
                     canContinue: familiarity != nil,
                     onContinue: { go(to: .motivation) }) {
            ForEach(Familiarity.allCases) { option in
                RadioPill(option.title, isSelected: familiarity == option) { familiarity = option }
            }
        }
    }

    private var motivationStep: some View {
        QuestionStep(title: "What brings you here?",
                     subtitle: "This shapes the topics in your feed.",
                     canContinue: motivation != nil,
                     onContinue: {
                         if topicIDs.isEmpty, let motivation {
                             let suggested = motivation.suggestedTopicIds + (role?.extraTopicIds ?? [])
                             topicIDs = Set(suggested.filter { id in
                                 model.topics.first { $0.id == id }.map { !model.isLocked($0) } ?? false
                             })
                         }
                         go(to: .topics)
                     }) {
            ForEach(Motivation.allCases) { option in
                RadioPill(option.title, symbol: option.symbol, isSelected: motivation == option) { motivation = option }
            }
        }
    }

    private var topicsStep: some View {
        QuestionStep(title: "Pick your topics",
                     subtitle: "Choose a few to start. Pro unlocks the rest.",
                     canContinue: true,
                     continueTitle: topicIDs.isEmpty ? "Surprise me" : "Continue",
                     onContinue: { go(to: .streak) }) {
            FlowLayout(spacing: 10) {
                ForEach(model.topics) { topic in
                    let locked = model.isLocked(topic)
                    let selected = topicIDs.contains(topic.id)
                    Button {
                        guard !locked else { return }
                        if selected { topicIDs.remove(topic.id) } else { topicIDs.insert(topic.id) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: locked ? "lock.fill" : topic.symbol)
                            Text(topic.title)
                        }
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(locked ? Palette.ink.opacity(0.35) : (selected ? Palette.ivory : Palette.ink))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(selected ? Palette.olive : Palette.ivory))
                        .overlay(Capsule().strokeBorder(Palette.ink.opacity(selected ? 0 : 0.08)))
                    }
                    .buttonStyle(.plain)
                    .disabled(locked)
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
        }
    }

    private var streakStep: some View {
        StreakCommitmentStep { go(to: .reminders) }
    }

    private var remindersStep: some View {
        let sample = model.content.terms.first { $0.id == "rag" } ?? model.content.terms.first
        return VStack(alignment: .leading, spacing: 18) {
            Text("Set up your daily goal")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("Allow notifications to get words throughout the day.")
                .font(.title3)
                .foregroundStyle(Palette.inkSoft)
            if let sample {
                NotificationPreview(title: sample.headline, message: sample.definition(at: familiarity?.suggestedLevel ?? .beginner))
                    .padding(.vertical, 8)
            }
            VStack(spacing: 12) {
                SettingRow(title: "How many") {
                    HStack(spacing: 14) {
                        StepButton(symbol: "minus") { reminders.perDay = max(reminders.perDay - 1, ReminderSettings.perDayRange.lowerBound) }
                        Text("\(reminders.perDay)x").font(.title3.monospacedDigit()).foregroundStyle(Palette.ink)
                            .contentTransition(.numericText())
                        StepButton(symbol: "plus") { reminders.perDay = min(reminders.perDay + 1, ReminderSettings.perDayRange.upperBound) }
                    }
                }
                SettingRow(title: "Start at") {
                    DatePicker("", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute).labelsHidden()
                }
                SettingRow(title: "End at") {
                    DatePicker("", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute).labelsHidden()
                }
            }
            .environment(\.colorScheme, .light)
            Spacer()
            Button("Allow and save") {
                Task {
                    await model.updateReminders(reminders)
                    go(to: .theme)
                }
            }
            .buttonStyle(PrimaryButtonStyle(.olive))
            Button("Not now") {
                Task {
                    var off = reminders
                    off.isEnabled = false
                    await model.updateReminders(off)
                    go(to: .theme)
                }
            }
            .buttonStyle(QuietButtonStyle(color: Palette.inkSoft))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .animation(.snappy, value: reminders.perDay)
    }

    private var themeStep: some View {
        DarkChoiceStep(title: "Which theme would you like to start with?", onContinue: { go(to: .icon) }) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(FeedTheme.allCases) { option in
                    let locked = option.isPremium && !model.isPro
                    Button {
                        if !locked { theme = option }
                    } label: {
                        ThemeTile(theme: option, selected: theme == option, locked: locked)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: theme == option)
                }
            }
        }
    }

    private var iconStep: some View {
        DarkChoiceStep(title: "Which icon style do you like the most?", onContinue: { go(to: .widget) }) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
                ForEach(AppIconOption.all) { option in
                    Button { appIcon = option } label: {
                        Image(option.previewAsset)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .padding(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .strokeBorder(appIcon == option ? Palette.textPrimary : .clear, lineWidth: 3)
                            )
                            .overlay(alignment: .topTrailing) {
                                if appIcon == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Palette.ink, Palette.teal)
                                        .symbolRenderingMode(.palette)
                                        .offset(x: 4, y: -4)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.title) icon")
                    .accessibilityAddTraits(appIcon == option ? .isSelected : [])
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appIcon)
        }
    }

    // MARK: Helpers

    private func go(to next: Step, forward: Bool = true) {
        self.forward = forward
        step = next
    }

    private func finish() {
        let ordered = model.topics.map(\.id).filter(topicIDs.contains)
        model.completeOnboarding(familiarity: familiarity, motivation: motivation, role: role, topicIds: ordered,
                                 theme: theme, appIcon: appIcon.iconName)
        if appIcon.iconName != nil {
            Task {
                // Let the transition settle before iOS shows its "icon changed" alert.
                try? await Task.sleep(for: .seconds(0.8))
                await AppIconService.apply(appIcon.iconName)
            }
        }
    }

    private func minuteBinding(_ keyPath: WritableKeyPath<ReminderSettings, Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminders[keyPath: keyPath] / 60, minute: reminders[keyPath: keyPath] % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminders[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }
}

/// "Create a consistent daily learning routine": flame + this week, today checked.
private struct StreakCommitmentStep: View {
    let onContinue: () -> Void
    @State private var checked = false

    private var days: [(label: String, isToday: Bool)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            return (formatter.string(from: date), offset == 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create a consistent daily learning routine")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Build a streak, one day at a time.")
                .font(.title3)
                .foregroundStyle(Palette.inkSoft)
            Spacer()
            StreakFlame(count: checked ? 1 : 0, size: 170)
                .frame(maxWidth: .infinity)
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 10) {
                        Text(day.label)
                            .font(.system(.subheadline, weight: day.isToday ? .semibold : .regular))
                            .foregroundStyle(day.isToday ? Palette.ink : Palette.inkSoft)
                        ZStack {
                            Circle().strokeBorder(day.isToday && checked ? Palette.oliveSoft : Palette.ink.opacity(0.15), lineWidth: day.isToday && checked ? 5 : 2)
                            if day.isToday && checked {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Palette.olive)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 38, height: 38)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Palette.ivory))
            .padding(.top, 20)
            Spacer()
            Text("Saving your daily words keeps the flame going. Miss a day and it starts again.")
                .font(.footnote)
                .foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(.olive))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: checked)
        .sensoryFeedback(.success, trigger: checked)
        .task {
            try? await Task.sleep(for: .seconds(0.6))
            checked = true
        }
    }
}

/// Dark step with a serif question, a grid of choices and a teal Continue.
private struct DarkChoiceStep<Content: View>: View {
    let title: String
    let onContinue: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 36)
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 8)
    }
}

/// Large "Aa" preview tile for a feed theme.
private struct ThemeTile: View {
    let theme: FeedTheme
    let selected: Bool
    let locked: Bool

    var body: some View {
        let colors = FeedColors.forTheme(theme)
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(colors.background)
            Text("Aa")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(colors.primary)
            VStack {
                HStack {
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Palette.ink, Palette.lime)
                            .symbolRenderingMode(.palette)
                    } else if locked {
                        Image(systemName: "lock.fill")
                            .font(.footnote)
                            .foregroundStyle(colors.secondary)
                    }
                }
                Spacer()
                Text(theme.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colors.secondary)
            }
            .padding(10)
        }
        .aspectRatio(0.7, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.outline)
                .offset(y: Metrics.hardShadow)
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(selected ? Palette.lime : Palette.outline, lineWidth: selected ? 3 : 2))
        .opacity(locked ? 0.7 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.title) theme\(locked ? ", Pro" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Question layout used by the multiple-choice onboarding steps.
private struct QuestionStep<Options: View>: View {
    let title: String
    let subtitle: String
    let canContinue: Bool
    var continueTitle = "Continue"
    let onContinue: () -> Void
    @ViewBuilder let options: () -> Options

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.bottom, 12)
                    options()
                }
                .padding(.top, 28)
            }
            .scrollIndicators(.hidden)
            Button(continueTitle, action: onContinue)
                .buttonStyle(PrimaryButtonStyle(.olive))
                .disabled(!canContinue)
                .padding(.vertical, 8)
        }
        .padding(.horizontal, Metrics.gutter)
    }
}

private struct SettingRow<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(title).font(.title3).foregroundStyle(Palette.inkSoft)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 22)
        .frame(minHeight: 66)
        .background(RoundedRectangle(cornerRadius: 33, style: .continuous).fill(Palette.ivory))
    }
}

private struct StepButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.ivory)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Palette.oliveSoft))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "More" : "Fewer")
    }
}
