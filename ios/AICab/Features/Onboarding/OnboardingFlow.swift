import SwiftUI
import AICabCore
import AICabDesign

/// First-run flow: who you are, what you already know, how deep and how often.
///
/// welcome → name → role → comfort → knowledge check (3 rounds) → starting depth →
/// three-depths demo → tricky contexts → feed topics → daily pace → reminders → theme → widget → trial
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model

    enum Step: Int, CaseIterable {
        case welcome, name, role, familiarity, knownBeginner, knownBuilder, knownResearch, placement
        case depth, weakSpots, topics, pace, reminders, theme, widget, paywall

        var isSkippable: Bool {
            [.name, .role, .familiarity, .weakSpots, .knownBeginner, .knownBuilder, .knownResearch].contains(self)
        }

        /// Steps that show the progress bar (everything between welcome and the widget guide).
        static var progressSteps: [Step] { allCases.filter { $0 != .welcome && $0 != .widget && $0 != .paywall } }

        var next: Step { Step(rawValue: rawValue + 1) ?? .paywall }
        var previous: Step? { Step(rawValue: rawValue - 1) }
    }

    @State private var step: Step = Self.initialStep
    @State private var forward = true
    @State private var answers = OnboardingAnswers()
    @State private var nameDraft = ""
    @State private var reminders = ReminderSettings(isEnabled: true, perDay: 3)
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
        case .name: nameStep
        case .role:
            SingleChoice(title: "What brings you to AI?", subtitle: "Your feed leans toward the terms you'll actually hear.",
                         options: Role.allCases, selection: answers.role, label: \.title, symbol: \.symbol) {
                answers.role = $0
                advance()
            }
        case .familiarity:
            SingleChoice(title: "How comfortable are you with AI talk?", subtitle: "This sets how deep definitions start. Change it whenever.",
                         options: Familiarity.allCases, selection: answers.familiarity, label: \.title) {
                answers.familiarity = $0
                advance()
            }
        case .knownBeginner: knownStep(round: 0)
        case .knownBuilder: knownStep(round: 1)
        case .knownResearch: knownStep(round: 2)
        case .placement: placementStep
        case .depth: DepthStep(level: placementLevel, onContinue: advance)
        case .weakSpots:
            MultiChoice(title: "Which conversations lose you?", options: WeakSpot.allCases,
                        selection: $answers.weakSpots, label: \.title, onContinue: advance)
        case .topics: topicsStep
        case .pace: PaceStep(selection: $answers.dailyGoal, onContinue: advance)
        case .reminders: remindersStep
        case .theme: themeStep
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
            StepProgress(current: Step.progressSteps.firstIndex(of: step) ?? 0, total: Step.progressSteps.count)
                .padding(.horizontal, 8)
            if step.isSkippable {
                Button("Skip") { skip() }
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(height: 44)
            } else {
                Color.clear.frame(width: 44, height: 44)
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
            Text("Learn the language\nof AI")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textPrimary)
            Text("Bite-size definitions at your depth, from \u{201C}token\u{201D} to \u{201C}test-time compute\u{201D}. One swipe at a time.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
            HStack(alignment: .center) {
                LaurelStat(value: "\(model.content.terms.count)+", caption: "AI terms")
                Spacer()
                LaurelStat(value: "3", caption: "depth levels", laurel: true)
                Spacer()
                LaurelStat(value: "\(model.chapters.count)", caption: "units")
            }
            .padding(.horizontal, 8)
            Button("Start learning") { advance() }
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

    private var nameStep: some View {
        VStack(spacing: 28) {
            StepTitle("What should AI-Cab call you?", subtitle: "Just a first name, kept on this phone.")
            TextField("", text: $nameDraft, prompt: Text("First name").foregroundStyle(Palette.textTertiary))
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

    private var remindersStep: some View {
        let sample = model.term("rag") ?? model.content.terms.first
        return VStack(spacing: 20) {
            StepTitle("When should terms find you?", subtitle: "A gentle nudge with one term and what it means.")
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
            Button("Turn on reminders") {
                Task {
                    await model.updateReminders(reminders)
                    advance()
                }
            }
            .buttonStyle(PrimaryButtonStyle(.teal))
            Button("Maybe later") {
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
        DarkChoiceStep(title: "Pick a look for your feed", onContinue: advance) {
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

    private func knownStep(round index: Int) -> some View {
        let round = PlacementTest().rounds(in: termIndex)[index]
        let terms = round.termIds.compactMap(model.term)
        return VStack(spacing: 0) {
            StepTitle(round.title, subtitle: "Tap the ones you could explain to a friend")
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
            Button(terms.contains(where: { answers.knownTermIds.contains($0.id) }) ? "Continue" : "None of these yet") {
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
            Eyebrow("Your starting depth", color: Palette.teal)
            Text(level.title)
                .font(.system(size: 52, weight: .bold, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            Text(level.blurb)
                .font(.title3)
                .foregroundStyle(Palette.textSecondary)
            VStack(spacing: 14) {
                Text(known.isEmpty
                     ? "A clean slate. Every term will be new, and we'll build up from the basics."
                     : "You know \(known.count) already, so those stay out of your feed. We'll start just past them.")
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
            StepTitle("Your feed, to start", subtitle: "Based on your answers. Tap to tweak.")
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
            Button(answers.topicIds.isEmpty ? "Mix of everything" : "Continue") { advance() }
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
        case .role: answers.role = nil
        case .familiarity: answers.familiarity = nil
        case .knownBeginner, .knownBuilder, .knownResearch:
            // Skipping the check jumps past its result screen.
            go(to: .depth)
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
        model.completeOnboarding(final)
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

/// Thin progress bar across the top bar.
private struct StepProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surface)
                Capsule().fill(Palette.teal)
                    .frame(width: max(8, proxy.size.width * CGFloat(current + 1) / CGFloat(max(total, 1))))
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

/// "One term, three depths": the same term explained at each level, stacked.
private struct DepthStep: View {
    @Environment(AppModel.self) private var model
    let level: Level
    let onContinue: () -> Void
    @State private var revealed = 0

    var body: some View {
        let term = model.term("rag") ?? model.content.terms[0]
        VStack(spacing: 18) {
            StepTitle("One term, three depths", subtitle: "Every definition is written three ways. Start at yours, go deeper anytime.")
            ScrollView {
                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(term.term)
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundStyle(Palette.textPrimary)
                        if let expansion = term.expansion {
                            Text(expansion)
                                .font(.system(.footnote, design: .serif).italic())
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer(minLength: 0)
                    }
                    ForEach(Array(Level.allCases.enumerated()), id: \.element) { index, depth in
                        depthCard(depth, term: term, isYours: depth == level)
                            .opacity(index < revealed ? 1 : 0)
                            .offset(y: index < revealed ? 0 : 16)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
        .task {
            for step in 1...Level.allCases.count {
                try? await Task.sleep(for: .milliseconds(320))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { revealed = step }
            }
        }
    }

    private func depthCard(_ depth: Level, term: Term, isYours: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(depth.title.uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(isYours ? Palette.ink : Palette.teal)
                Spacer()
                if isYours {
                    Text("YOUR START")
                        .font(.caption2.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Palette.teal)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.ink))
                } else if depth.isPremium {
                    Text("PRO").font(.caption2.weight(.heavy)).tracking(1.2).foregroundStyle(Palette.gold)
                }
            }
            Text(term.definition(at: depth))
                .font(.body)
                .foregroundStyle(isYours ? Palette.ink : Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tactileCard(fill: isYours ? Palette.teal : Palette.surface)
    }
}

/// Daily pace: three tactile cards with how long each takes.
private struct PaceStep: View {
    @Binding var selection: Int?
    let onContinue: () -> Void

    private struct Pace: Identifiable {
        let goal: Int
        let title: String
        let minutes: String
        let symbol: String
        var id: Int { goal }
    }

    private let paces = [
        Pace(goal: 2, title: "Easy", minutes: "about 1 minute a day", symbol: "tortoise.fill"),
        Pace(goal: 5, title: "Steady", minutes: "about 3 minutes a day", symbol: "figure.walk"),
        Pace(goal: 8, title: "Intense", minutes: "about 5 minutes a day", symbol: "hare.fill"),
    ]

    var body: some View {
        VStack(spacing: 22) {
            StepTitle("Pick your pace", subtitle: "How many new terms to save each day. Hitting it keeps your streak alive.")
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                ForEach(paces) { pace in
                    paceCard(pace, picked: (selection ?? 5) == pace.goal)
                }
            }
            Spacer(minLength: 0)
            Button("Continue") {
                if selection == nil { selection = 5 }
                onContinue()
            }
            .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func paceCard(_ pace: Pace, picked: Bool) -> some View {
        Button { selection = pace.goal } label: {
            HStack(spacing: 16) {
                Image(systemName: pace.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(picked ? Palette.cream : Palette.teal))
                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(pace.title).font(.system(.title3, design: .serif, weight: .bold))
                    Text(pace.minutes).font(.subheadline).opacity(0.75)
                }
                Spacer(minLength: 0)
                Text("\(pace.goal)").font(.system(size: 34, weight: .bold, design: .serif))
                Text("terms\na day").font(.caption).multilineTextAlignment(.leading).opacity(0.75)
            }
            .foregroundStyle(picked ? Palette.ink : Palette.textPrimary)
            .padding(18)
        }
        .buttonStyle(TactileButtonStyle(fill: picked ? Palette.teal : Palette.surface, radius: 28))
        .accessibilityLabel("\(pace.title), \(pace.goal) terms a day, \(pace.minutes)")
        .accessibilityAddTraits(picked ? .isSelected : [])
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
