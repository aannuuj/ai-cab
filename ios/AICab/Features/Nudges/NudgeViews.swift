import SwiftUI
import StoreKit
import AICabCore
import AICabDesign

/// "Add a widget to your Home Screen" — used in onboarding, as a nudge, and from Profile.
struct WidgetInstallView: View {
    enum Mode { case onboarding, nudge, settings }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    var onDone: (() -> Void)?
    var startOnLockScreen = false

    @State private var step = 0
    @State private var showingSteps = false
    @State private var lockScreen = false

    private var sample: WidgetWord {
        let term = model.term("rag") ?? model.feed.first
        return term.map { WidgetWord(term: $0, level: model.level) } ?? WidgetSnapshot.placeholder.words[0]
    }

    private let homeSteps = [
        ("hand.tap", "Touch and hold an empty area of your Home Screen until the apps jiggle."),
        ("plus.circle", "Tap Edit, then Add Widget in the top corner."),
        ("magnifyingglass", "Search for AI-Cab and pick a size. Medium shows the full definition."),
        ("checkmark.circle", "Tap Add Widget, then Done. A new word appears every hour."),
    ]
    private let lockSteps = [
        ("lock", "Touch and hold your Lock Screen, then tap Customize."),
        ("rectangle.on.rectangle", "Choose Lock Screen and tap the widget area under the clock."),
        ("magnifyingglass", "Find AI-Cab and add the word widget."),
        ("checkmark.circle", "Tap Done. You'll see a new AI word every time you glance at your phone."),
    ]

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                Text(lockScreen ? "Add a widget to your Lock Screen" : "Add a widget to your Home Screen")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.opacity)
                Text("See a new AI word every time you glance at your phone, no app opening needed.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, mode == .onboarding ? 40 : 28)
            .padding(.horizontal, 12)

            Picker("Where", selection: $lockScreen) {
                Text("Home Screen").tag(false)
                Text("Lock Screen").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)

            if showingSteps {
                stepsCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                PhoneMock {
                    if lockScreen {
                        LockScreenPreview(word: sample)
                    } else {
                        WidgetWordCard(word: sample, fill: Palette.teal)
                    }
                }
                .frame(maxHeight: 420)
                .padding(.horizontal, 20)
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            Button(showingSteps ? (step < 3 ? "Next step" : "I've added it") : "Install widget") {
                if !showingSteps {
                    showingSteps = true
                } else if step < 3 {
                    step += 1
                } else {
                    model.resolve(.widget, .accepted)
                    finish()
                }
            }
            .buttonStyle(PrimaryButtonStyle(.teal))

            Button(mode == .onboarding ? "Skip for now" : "Remind me later") {
                if mode == .nudge { model.resolve(.widget, .snoozed) }
                finish()
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 8)
        .background(Palette.charcoal.ignoresSafeArea())
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showingSteps)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
        .animation(.easeInOut, value: lockScreen)
        .onChange(of: lockScreen) { step = 0 }
        .onAppear { if startOnLockScreen { lockScreen = true } }
    }

    private var stepsCard: some View {
        let steps = lockScreen ? lockSteps : homeSteps
        return VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle().fill(index <= step ? Palette.teal : Palette.surfaceRaised)
                        Image(systemName: index < step ? "checkmark" : item.0)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(index <= step ? Palette.ink : Palette.textSecondary)
                    }
                    .frame(width: 40, height: 40)
                    Text(item.1)
                        .font(.body)
                        .foregroundStyle(index <= step ? Palette.textPrimary : Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
            }
        }
        .padding(22)
        .tactileCard()
    }

    private func finish() {
        if let onDone { onDone() } else { dismiss() }
    }
}

private struct LockScreenPreview: View {
    let word: WidgetWord

    var body: some View {
        VStack(spacing: 10) {
            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.cream)
            VStack(alignment: .leading, spacing: 2) {
                Text(word.term).font(.system(.headline, design: .serif, weight: .bold))
                Text(word.definition).font(.caption).lineLimit(2)
            }
            .foregroundStyle(Palette.cream)
            .padding(12)
            .frame(maxWidth: 260, alignment: .leading)
            .glassRounded(16)
        }
    }
}

/// Overlay nudges: the "Loving the app?" pre-prompt and the Journey intro.
struct NudgeOverlay: View {
    @Environment(AppModel.self) private var model
    @Environment(\.requestReview) private var requestReview
    let nudge: Nudge

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { model.resolve(nudge, .dismissed) }
            Group {
                switch nudge {
                case .review: reviewCard
                case .journey: journeyCard
                case .widget, .paywall: EmptyView()
                }
            }
            .padding(24)
            .tactileCard(fill: Palette.charcoal)
            .padding(.horizontal, 24)
        }
    }

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Loving AI-Cab?")
                .font(.serifTitle2)
                .foregroundStyle(Palette.textPrimary)
            Text("You've saved \(model.state.learnedCount) AI words so far. A quick rating helps other people find us.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            Button {
                model.resolve(.review, .accepted)
                requestReview()
            } label: {
                Label("Love it!", systemImage: "heart.fill")
            }
            .buttonStyle(PrimaryButtonStyle(.olive))
            Button("Not really") {
                model.resolve(.review, .accepted)
                model.sheet = .feedback
            }
            .buttonStyle(SoftButtonStyle())
            Button("Remind me later") { model.resolve(.review, .snoozed) }
                .buttonStyle(SoftButtonStyle())
        }
    }

    private var journeyCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: -18) {
                IsoLessonTile(symbol: "star.fill", state: .completed, size: 96)
                IsoLessonTile(symbol: "puzzlepiece.fill", state: .current, size: 96)
                IsoLessonTile(symbol: "trophy.fill", state: .available, size: 96)
            }
            Eyebrow("New", color: Palette.teal)
            Text("Your AI Journey")
                .font(.serifTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("Ten chapters, six bite-sized lessons each. Learn, match, compare look-alikes, then pass the test.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
            Button("Start chapter 1") {
                model.resolve(.journey, .accepted)
                model.selectedTab = .journey
            }
            .buttonStyle(PrimaryButtonStyle(.teal))
            Button("Later") { model.resolve(.journey, .dismissed) }
                .buttonStyle(QuietButtonStyle(color: Palette.textSecondary))
        }
    }
}

/// Dark pill used for secondary choices in modals.
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, weight: .semibold))
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Capsule().fill(Palette.surface.opacity(configuration.isPressed ? 0.7 : 1)))
    }
}

/// In-app feedback, so unhappy users talk to us instead of the App Store.
struct FeedbackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var message = ""
    @State private var topic = "Suggestion"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("What could be better? We read every message.")
                        .foregroundStyle(Palette.textSecondary)
                }
                Picker("About", selection: $topic) {
                    ForEach(["Suggestion", "A word is wrong", "Missing word", "Bug", "Other"], id: \.self) { Text($0) }
                }
                Section("Message") {
                    TextField("Tell us more", text: $message, axis: .vertical)
                        .lineLimit(5...12)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.charcoal)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        send()
                        dismiss()
                    }
                    .bold()
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationBackground(Palette.charcoal)
    }

    private func send() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = model.config.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "AI-Cab feedback: \(topic)"),
            URLQueryItem(name: "body", value: "\(message)\n\n— AI-Cab \(version), content v\(model.content.version)"),
        ]
        if let url = components.url { openURL(url) }
    }
}
