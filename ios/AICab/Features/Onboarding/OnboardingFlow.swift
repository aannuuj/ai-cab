import SwiftUI
import AICabCore
import AICabDesign

/// First-run flow: welcome → familiarity → goal → topics → daily reminders → widget → trial.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model

    enum Step: Int, CaseIterable {
        case welcome, familiarity, motivation, topics, reminders, widget, paywall
    }

    @State private var step: Step = .welcome
    @State private var familiarity: Familiarity?
    @State private var motivation: Motivation?
    @State private var topicIDs: Set<String> = []
    @State private var reminders = ReminderSettings(isEnabled: true, perDay: 3)
    @State private var forward = true

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 0) {
                if step != .welcome && step.rawValue <= Step.reminders.rawValue {
                    topBar
                }
                Group {
                    switch step {
                    case .welcome: welcome
                    case .familiarity: familiarityStep
                    case .motivation: motivationStep
                    case .topics: topicsStep
                    case .reminders: remindersStep
                    case .widget:
                        WidgetInstallView(mode: .onboarding) { go(to: .paywall) }
                    case .paywall:
                        PaywallView(source: .onboarding) { finish() }
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

    private var background: Color {
        step.rawValue >= Step.widget.rawValue ? Palette.charcoal : Palette.cream
    }

    private var topBar: some View {
        HStack(spacing: 16) {
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
                        .frame(width: proxy.size.width * CGFloat(step.rawValue) / CGFloat(Step.reminders.rawValue))
                }
            }
            .frame(height: 6)
            Spacer().frame(width: 40)
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
            Button("Get started") { go(to: .familiarity) }
                .buttonStyle(PrimaryButtonStyle(.olive))
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 12)
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
                             topicIDs = Set(motivation.suggestedTopicIds.filter { id in
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
                     onContinue: { go(to: .reminders) }) {
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
                    go(to: .widget)
                }
            }
            .buttonStyle(PrimaryButtonStyle(.olive))
            Button("Not now") {
                Task {
                    var off = reminders
                    off.isEnabled = false
                    await model.updateReminders(off)
                    go(to: .widget)
                }
            }
            .buttonStyle(QuietButtonStyle(color: Palette.inkSoft))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .animation(.snappy, value: reminders.perDay)
    }

    // MARK: Helpers

    private func go(to next: Step, forward: Bool = true) {
        self.forward = forward
        step = next
    }

    private func finish() {
        let ordered = model.topics.map(\.id).filter(topicIDs.contains)
        model.completeOnboarding(familiarity: familiarity, motivation: motivation, topicIds: ordered)
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
