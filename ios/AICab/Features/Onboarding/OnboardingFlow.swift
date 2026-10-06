import SwiftUI
import AICabCore
import AICabDesign

/// First-run flow, modelled on the reference app and adapted to AI vocabulary.
///
/// welcome → tailor → name → age → gender → role → weekly goal → streak → habits → reminders →
/// icon → theme → insight → familiarity → weak spots → placement test (3 rounds) → result →
/// topics → widget → trial
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model

    enum Step: Int, CaseIterable {
        case welcome, tailor, name, age, gender, role, weekly, streak, habits, reminders
        case icon, theme, insight, familiarity, weakSpots, knownBeginner, knownBuilder, knownResearch, placement
        case topics, widget, paywall

        var isSkippable: Bool {
            [.name, .age, .gender, .role, .weekly, .habits, .familiarity, .weakSpots,
             .knownBeginner, .knownBuilder, .knownResearch].contains(self)
        }

        var next: Step { Step(rawValue: rawValue + 1) ?? .paywall }
        var previous: Step? { Step(rawValue: rawValue - 1) }
    }

    @State private var step: Step = Self.initialStep
    @State private var forward = true
    @State private var answers = OnboardingAnswers()
    @State private var nameDraft = ""
    @State private var reminders = ReminderSettings(isEnabled: true, perDay: 3)
    @State private var appIcon: AppIconOption = AppIconOption.all[0]
    @State private var placementDone = false
    @FocusState private var nameFocused: Bool

    /// `-onboardingStep <name>` opens a specific step (screenshots and QA).
    static var initialStep: Step {
        guard let name = ProcessInfo.processInfo.arguments.drop(while: { $0 != "-onboardingStep" }).dropFirst().first else {
            return .welcome
        }
        return Step.allCases.first { "\($0)" == name } ?? .welcome
    }

    var body: some View {
        ZStack {
            Palette.charcoal.ignoresSafeArea()
            VStack(spacing: 0) {
                if step != .welcome && step != .widget && step != .paywall {
                    topBar
                }
                Group { content }
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

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .tailor: tailor
        case .name: nameStep
        case .age:
            SingleChoice(title: "How old are you?", options: AgeRange.allCases, selection: answers.ageRange, label: \.title) {
                answers.ageRange = $0
                advance()
            }
        case .gender:
            SingleChoice(title: "Which option represents you best?", options: Gender.allCases, selection: answers.gender, label: \.title) {
                answers.gender = $0
                advance()
            }
        case .role:
            SingleChoice(title: "What do you do?", subtitle: "We'll mix in words from your world.",
                         options: Role.allCases, selection: answers.role, label: \.title, symbol: \.symbol) {
                answers.role = $0
                advance()
            }
        case .weekly: weeklyStep
        case .streak: DarkStreakStep(onContinue: advance)
        case .habits:
            MultiChoice(title: "What would help make learning a daily habit?", options: HabitHelper.allCases,
                        selection: $answers.habitHelpers, label: \.title, onContinue: advance)
        case .reminders: remindersStep
        case .icon: iconStep
        case .theme: themeStep
        case .insight: InsightStep(onContinue: advance)
        case .familiarity:
            SingleChoice(title: "How familiar are you with AI?", subtitle: "Sets how deep definitions go. Switch any time.",
                         options: Familiarity.allCases, selection: answers.familiarity, label: \.title) {
                answers.familiarity = $0
                advance()
            }
        case .weakSpots:
            MultiChoice(title: "Where does AI jargon trip you up?", options: WeakSpot.allCases,
                        selection: $answers.weakSpots, label: \.title, onContinue: advance)
        case .knownBeginner: knownStep(round: 0)
        case .knownBuilder: knownStep(round: 1)
        case .knownResearch: knownStep(round: 2)
        case .placement: placementStep
        case .topics: topicsStep
        case .widget: WidgetInstallView(mode: .onboarding) { advance() }
        case .paywall: PaywallView(source: .onboarding) { finish() }
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Button {
                if let previous = step.previous { go(to: previous, forward: false) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            Spacer()
            if step.isSkippable {
                Button("Skip") { skip() }
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            WelcomeArt()
            Text("Speak fluent AI\nin 1 minute a day")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textPrimary)
            Text("Learn \(model.content.terms.count)+ AI words, from \u{201C}token\u{201D} to \u{201C}test-time compute\u{201D}, with a daily habit that takes a minute.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
            HStack(alignment: .center) {
                LaurelStat(value: "\(model.content.terms.count)+", caption: "AI words")
                Spacer()
                LaurelStat(value: "3", caption: "depth levels", laurel: true)
                Spacer()
                LaurelStat(value: "\(model.chapters.count)", caption: "chapters")
            }
            .padding(.horizontal, 8)
            Button("Get started") { advance() }
                .buttonStyle(PrimaryButtonStyle(.teal))
            legal
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
    }

    private var legal: some View {
        Text(.init("By continuing you agree to our [Terms](\(model.config.termsURL.absoluteString)) and [Privacy Policy](\(model.config.privacyURL.absoluteString))"))
            .font(.footnote)
            .foregroundStyle(Palette.textTertiary)
            .tint(Palette.textSecondary)
            .multilineTextAlignment(.center)
    }

    private var tailor: some View {
        VStack(spacing: 28) {
            Spacer()
            StairsIllustration()
            Text("Tailor your word\nrecommendations")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textPrimary)
            Text("A few quick questions so your feed starts at the right level, on the topics you care about.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 12)
            Spacer()
            Button("Continue") { advance() }
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 8)
    }

    private var nameStep: some View {
        VStack(spacing: 28) {
            StepTitle("What should we call you?")
            TextField("", text: $nameDraft, prompt: Text("Your first name").foregroundStyle(Palette.textTertiary))
                .font(.title3)
                .foregroundStyle(Palette.textPrimary)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit(saveName)
                .padding(.horizontal, 26)
                .frame(height: 64)
                .background(TactileBackground(fill: Palette.surface, radius: 32))
            Button("Continue", action: saveName)
                .buttonStyle(PrimaryButtonStyle(.teal))
                .disabled(nameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer()
        }
        .padding(.horizontal, Metrics.gutter)
        .onAppear {
            nameDraft = answers.name ?? ""
            nameFocused = true
        }
    }

    private var weeklyStep: some View {
        SingleChoice(title: "How many AI words do you want to learn per week?", options: [10, 30, 50],
                     selection: answers.weeklyWords,
                     label: { "\($0) words a week" },
                     detail: { "about \(Preferences.dailyGoal(forWeeklyWords: $0)) a day" }) {
            answers.weeklyWords = $0
            advance()
        }
    }

    private var remindersStep: some View {
        let sample = model.term("rag") ?? model.content.terms.first
        return VStack(spacing: 20) {
            StepTitle("Get AI words throughout the day", subtitle: "Allow notifications to get daily words.")
            if let sample {
                DarkNotificationPreview(title: sample.headline, message: sample.definition(at: answers.familiarity?.suggestedLevel ?? .beginner))
            }
            Spacer(minLength: 8)
            HStack {
                Text("How many").font(.title3).foregroundStyle(Palette.textPrimary)
                Spacer()
                CircleStep(symbol: "minus") { reminders.perDay = max(reminders.perDay - 1, ReminderSettings.perDayRange.lowerBound) }
                Text("\(reminders.perDay)x")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 64)
                    .contentTransition(.numericText())
                CircleStep(symbol: "plus") { reminders.perDay = min(reminders.perDay + 1, ReminderSettings.perDayRange.upperBound) }
            }
            .padding(.horizontal, 22)
            .frame(minHeight: 72)
            .background(TactileBackground(fill: Palette.surface, radius: 36))
            .padding(.bottom, Metrics.hardShadow)
            VStack(spacing: 0) {
                timeRow("Start at", \.startMinute)
                Rectangle().fill(Palette.outline).frame(height: 2)
                timeRow("End at", \.endMinute)
            }
            .background(TactileBackground(fill: Palette.surface, radius: 32))
            .padding(.bottom, Metrics.hardShadow)
            Spacer()
            Button("Allow and save") {
                Task {
                    await model.updateReminders(reminders)
                    advance()
                }
            }
            .buttonStyle(PrimaryButtonStyle(.teal))
            Button("Not now") {
                Task {
                    var off = reminders
                    off.isEnabled = false
                    await model.updateReminders(off)
                    advance()
                }
            }
            .buttonStyle(QuietButtonStyle(color: Palette.textSecondary))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
        .animation(.snappy, value: reminders.perDay)
    }

    private func timeRow(_ title: String, _ keyPath: WritableKeyPath<ReminderSettings, Int>) -> some View {
        HStack {
            Text(title).font(.title3).foregroundStyle(Palette.textPrimary)
            Spacer()
            DatePicker("", selection: minuteBinding(keyPath), displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .padding(.horizontal, 22)
        .frame(minHeight: 70)
    }

    private var themeStep: some View {
        DarkChoiceStep(title: "Which theme would you like to start with?", onContinue: advance) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(FeedTheme.onboardingPicks) { option in
                    let locked = option.isPremium && !model.isPro
                    Button {
                        if !locked { answers.theme = option }
                    } label: {
                        ThemeTile(theme: option, selected: answers.theme == option, locked: locked)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: answers.theme == option)
                }
            }
        }
    }

    private var iconStep: some View {
        DarkChoiceStep(title: "Which icon style do you like the most?", onContinue: advance) {
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

    private func knownStep(round index: Int) -> some View {
        let round = PlacementTest().rounds(in: termIndex)[index]
        let terms = round.termIds.compactMap(model.term)
        return VStack(spacing: 0) {
            StepTitle(round.title, subtitle: "Select all the ones you know")
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(terms) { term in
                        TactileOption(term.term, isSelected: answers.knownTermIds.contains(term.id)) {
                            if answers.knownTermIds.contains(term.id) {
                                answers.knownTermIds.remove(term.id)
                            } else {
                                answers.knownTermIds.insert(term.id)
                            }
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            Button(terms.contains(where: { answers.knownTermIds.contains($0.id) }) ? "Continue" : "I don't know these yet") {
                placementDone = true
                advance()
            }
            .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
    }

    private var placementStep: some View {
        let level = placementLevel
        let known = answers.knownTermIds.compactMap(model.term).sorted { $0.term < $1.term }
        return VStack(spacing: 22) {
            Spacer()
            Eyebrow("Your starting level", color: Palette.teal)
            Text(level.title)
                .font(.system(size: 52, weight: .bold, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            Text(level.blurb)
                .font(.title3)
                .foregroundStyle(Palette.textSecondary)
            VStack(spacing: 14) {
                Text(known.isEmpty
                     ? "Perfect place to start. Every word will be new."
                     : "You already know \(known.count) of these. We'll skip them and start where it gets interesting.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textPrimary)
                if !known.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(known.prefix(9)) { Chip($0.term, systemImage: "checkmark", isSelected: true) }
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .tactileCard()
            if level.isPremium && !model.isPro {
                Text("Research-depth definitions are part of Pro. You'll see Builder definitions until you try it.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("Continue") { advance() }
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
    }

    private var topicsStep: some View {
        VStack(spacing: 0) {
            StepTitle("Your starting topics", subtitle: "Picked from your answers. Tap to change.")
            ScrollView {
                FlowLayout(spacing: 10) {
                    ForEach(model.topics) { topic in
                        let locked = model.isLocked(topic)
                        let selected = answers.topicIds.contains(topic.id)
                        Button {
                            guard !locked else { return }
                            if selected { answers.topicIds.removeAll { $0 == topic.id } } else { answers.topicIds.append(topic.id) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: locked ? "lock.fill" : topic.symbol)
                                Text(topic.title)
                            }
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(locked ? Palette.textTertiary : (selected ? Palette.ink : Palette.textPrimary))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(selected ? Palette.teal : Palette.surface))
                            .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .disabled(locked)
                        .sensoryFeedback(.selection, trigger: selected)
                    }
                }
                .padding(.top, 24)
            }
            .scrollIndicators(.hidden)
            Button(answers.topicIds.isEmpty ? "Surprise me" : "Continue") { advance() }
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
        .onAppear(perform: seedTopics)
    }

    // MARK: Logic

    private var termIndex: [String: Term] {
        Dictionary(model.content.terms.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var placementLevel: Level {
        guard placementDone else { return answers.familiarity?.suggestedLevel ?? .beginner }
        let test = PlacementTest()
        return test.recommendedLevel(known: answers.knownTermIds, rounds: test.rounds(in: termIndex))
    }

    private func seedTopics() {
        guard answers.topicIds.isEmpty else { return }
        var ids: [String] = answers.weakSpots.sorted { $0.rawValue < $1.rawValue }.flatMap(\.topicIds)
        ids += answers.role?.extraTopicIds ?? []
        if ids.isEmpty { ids = Motivation.curious.suggestedTopicIds }
        let allowed = Set(model.topics.filter { !model.isLocked($0) }.map(\.id))
        var seen = Set<String>()
        answers.topicIds = ids.filter { allowed.contains($0) && seen.insert($0).inserted }
    }

    private func saveName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        answers.name = trimmed.isEmpty ? nil : String(trimmed.prefix(30))
        nameFocused = false
        advance()
    }

    private func skip() {
        switch step {
        case .name: answers.name = nil
        case .age: answers.ageRange = nil
        case .gender: answers.gender = nil
        case .role: answers.role = nil
        case .weekly: answers.weeklyWords = nil
        case .familiarity: answers.familiarity = nil
        case .knownBeginner, .knownBuilder, .knownResearch:
            // Skipping the test jumps past the result screen.
            go(to: .topics)
            return
        default: break
        }
        advance()
    }

    private func advance() {
        go(to: step.next)
    }

    private func go(to next: Step, forward: Bool = true) {
        self.forward = forward
        step = next
    }

    private func finish() {
        var final = answers
        final.placementLevel = placementDone ? placementLevel : nil
        final.appIcon = appIcon.iconName
        model.completeOnboarding(final)
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

// MARK: - Building blocks

/// Centered serif question with optional subtitle.
private struct StepTitle: View {
    let title: String
    var subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// Single-select question; tapping an option answers and advances.
private struct SingleChoice<Option: Hashable>: View {
    let title: String
    let subtitle: String?
    let options: [Option]
    let selection: Option?
    let label: (Option) -> String
    let symbol: ((Option) -> String)?
    let detail: ((Option) -> String)?
    let onSelect: (Option) -> Void

    @State private var picked: Option?

    init(title: String, subtitle: String? = nil, options: [Option], selection: Option?,
         label: @escaping (Option) -> String, symbol: ((Option) -> String)? = nil,
         detail: ((Option) -> String)? = nil, onSelect: @escaping (Option) -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.options = options
        self.selection = selection
        self.label = label
        self.symbol = symbol
        self.detail = detail
        self.onSelect = onSelect
    }

    init(title: String, subtitle: String? = nil, options: [Option], selection: Option?,
         label: KeyPath<Option, String>, symbol: KeyPath<Option, String>? = nil, onSelect: @escaping (Option) -> Void) {
        let symbolClosure: ((Option) -> String)? = symbol.map { path in { option in option[keyPath: path] } }
        self.init(title: title, subtitle: subtitle, options: options, selection: selection,
                  label: { $0[keyPath: label] }, symbol: symbolClosure, detail: nil, onSelect: onSelect)
    }

    var body: some View {
        VStack(spacing: 0) {
            StepTitle(title, subtitle: subtitle)
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(options, id: \.self) { option in
                        VStack(alignment: .leading, spacing: 4) {
                            TactileOption(label(option), symbol: symbol?(option), isSelected: (picked ?? selection) == option) {
                                picked = option
                                Task {
                                    try? await Task.sleep(for: .milliseconds(320))
                                    onSelect(option)
                                }
                            }
                            if let detail {
                                Text(detail(option))
                                    .font(.caption)
                                    .foregroundStyle(Palette.textTertiary)
                                    .padding(.leading, 26)
                            }
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Metrics.gutter)
    }
}

/// Multi-select question with a Continue button.
private struct MultiChoice<Option: Hashable>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Set<Option>
    let label: KeyPath<Option, String>
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            StepTitle(title, subtitle: "Choose as many as you like")
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(options, id: \.self) { option in
                        TactileOption(option[keyPath: label], isSelected: selection.contains(option)) {
                            if selection.contains(option) { selection.remove(option) } else { selection.insert(option) }
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
    }
}

/// Dark streak commitment: halftone flame, two-letter day card, today ticked.
private struct DarkStreakStep: View {
    let onContinue: () -> Void
    @State private var checked = false

    private var days: [(label: String, isToday: Bool)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEEE"
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            return (formatter.string(from: date), offset == 0)
        }
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            HalftoneFlame(count: checked ? 1 : 0, size: 210)
            Text("Create a consistent daily learning routine")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textPrimary)
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 10) {
                            Text(day.label)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(day.isToday ? Palette.textPrimary : Palette.textTertiary)
                            ZStack {
                                if day.isToday && checked {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(Palette.ink, Palette.teal)
                                        .symbolRenderingMode(.palette)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Circle().fill(Palette.textTertiary.opacity(0.7))
                                }
                            }
                            .frame(width: 40, height: 40)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Text("Build a streak, one day at a time")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 10)
            .tactileCard()
            Spacer()
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: checked)
        .sensoryFeedback(.success, trigger: checked)
        .task {
            try? await Task.sleep(for: .seconds(0.6))
            checked = true
        }
    }
}

/// "Get deeper insight into each AI word": a live card that demos the depth switch.
private struct InsightStep: View {
    @Environment(AppModel.self) private var model
    let onContinue: () -> Void
    @State private var level: Level = .beginner

    var body: some View {
        let term = model.term("rag") ?? model.content.terms[0]
        let related = Array(term.related.compactMap(model.term).prefix(3))
        VStack(spacing: 22) {
            StepTitle("Get deeper insight into each AI word")
            ScrollView {
                VStack(alignment: .center, spacing: 14) {
                    Text(term.term)
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.textPrimary)
                    if let expansion = term.expansion {
                        Text(expansion).font(.system(.subheadline, design: .serif).italic()).foregroundStyle(Palette.textSecondary)
                    }
                    PronunciationPill(ipa: term.ipa, colors: .forTheme(.charcoal), isSpeaking: model.speech.speakingID == term.id) {
                        model.speech.speak(term.term, id: term.id)
                    }
                    Picker("Depth", selection: $level) {
                        ForEach(Level.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("(\(term.pos)) \(term.definition(at: level))")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.opacity)
                        .animation(.easeInOut, value: level)
                        .frame(minHeight: 70)
                    VStack(alignment: .leading, spacing: 10) {
                        if let example = term.example {
                            section("Example", example)
                        }
                        if !related.isEmpty {
                            Text("Related").font(.subheadline).foregroundStyle(Palette.textSecondary)
                            FlowLayout(spacing: 8) {
                                ForEach(related) { Chip($0.term) }
                            }
                        }
                        if let origin = term.origin {
                            section("Origin", origin)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22)
                .tactileCard()
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
        .task {
            for next in [Level.builder, .research, .beginner] {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation { level = next }
            }
        }
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(Palette.textSecondary)
            Text(text).font(.body).foregroundStyle(Palette.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Dark glass notification preview.
private struct DarkNotificationPreview: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AppMark(size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("AI-Cab").font(.headline)
                    Spacer()
                    Text("Now").font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.subheadline).lineLimit(2)
            }
            .foregroundStyle(Palette.textPrimary)
        }
        .padding(18)
        .glassRounded(26)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Palette.surface.opacity(0.6))
                .padding(.horizontal, 22)
                .offset(y: 14)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct CircleStep: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(Palette.textPrimary, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "More" : "Fewer")
    }
}

/// Dark step with a serif question, a grid of choices and a teal Continue.
private struct DarkChoiceStep<Content: View>: View {
    let title: String
    let onContinue: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 24) {
            StepTitle(title)
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
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
            FeedBackground(theme: theme)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text("Aa")
                .font(colors.font.display(size: 34))
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
