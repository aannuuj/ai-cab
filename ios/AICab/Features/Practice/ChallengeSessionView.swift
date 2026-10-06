import SwiftUI
import AICabCore
import AICabDesign

/// Sprint / Rush / Perfection: endless quick-fire questions with a clock or lives.
struct ChallengeSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let mode: ChallengeMode

    @State private var run: ChallengeRun
    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var selected: Int?
    @State private var startedAt: Date?
    @State private var elapsed: TimeInterval = 0
    @State private var finished = false
    @State private var isNewBest = false
    @State private var shake = 0
    @State private var burst = 0

    init(mode: ChallengeMode) {
        self.mode = mode
        _run = State(initialValue: ChallengeRun(mode: mode))
    }

    var body: some View {
        ZStack {
            Palette.charcoal.ignoresSafeArea()
            if finished {
                summary
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let question = questions[safe: index] {
                VStack(alignment: .leading, spacing: 18) {
                    statusBar
                    questionView(question)
                        .id(question.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                    Spacer(minLength: 0)
                }
                .padding(Metrics.gutter)
            } else {
                ContentUnavailableView("Not enough words yet", systemImage: "text.book.closed")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: index)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: finished)
        .overlay { ConfettiBurst(trigger: burst) }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
        .task(id: startedAt) { await tick() }
        .onAppear(perform: start)
        .sensoryFeedback(.error, trigger: shake)
        .sensoryFeedback(.success, trigger: run.correct)
    }

    // MARK: Pieces

    private var statusBar: some View {
        HStack {
            Label("\(run.score)", systemImage: "checkmark.circle.fill")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
            Spacer()
            if let left = run.timeLeft(elapsed: elapsed) {
                Label(String(format: "0:%02d", Int(left.rounded(.up))), systemImage: "stopwatch")
                    .font(.system(.title3, weight: .semibold).monospacedDigit())
                    .foregroundStyle(left <= 10 ? Palette.coral : Palette.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
            }
            if let lives = mode.lives, let left = run.livesLeft {
                HStack(spacing: 4) {
                    ForEach(0..<lives, id: \.self) { index in
                        Image(systemName: index < left ? "heart.fill" : "heart")
                            .foregroundStyle(index < left ? Palette.coral : Palette.textTertiary)
                            .symbolEffect(.bounce, value: left)
                    }
                }
                .font(.title3)
                .accessibilityLabel("\(left) lives left")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(Palette.surface))
    }

    private func questionView(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question.prompt)
                .font(.serifTitle2)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = question.detail {
                Text(detail)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
            }
            VStack(spacing: 10) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { offset, choice in
                    choiceButton(choice, offset: offset, question: question)
                }
            }
            .modifier(Shake(animatableData: CGFloat(shake)))
        }
    }

    private func choiceButton(_ choice: String, offset: Int, question: QuizQuestion) -> some View {
        let revealed = selected != nil
        let isAnswer = offset == question.answerIndex
        let isPicked = offset == selected
        let fill: Color = revealed && isAnswer ? Palette.teal : (revealed && isPicked ? Palette.coral : Palette.surface)
        return Button {
            answer(offset, question: question)
        } label: {
            Text(choice)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .foregroundStyle(revealed && (isAnswer || isPicked) ? Palette.ink : Palette.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(TactileButtonStyle(fill: fill, radius: 22))
        .disabled(revealed)
    }

    private var summary: some View {
        VStack(spacing: 18) {
            Spacer()
            IsoDisc(symbol: isNewBest ? "trophy.fill" : "flag.checkered", size: 110, tint: isNewBest ? Palette.gold : Palette.teal)
            Text(isNewBest ? "New personal best!" : "\(mode.title) over")
                .font(.serifTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("\(run.score)")
                .font(.system(size: 72, weight: .bold, design: .serif))
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
            Text("correct · best streak \(run.bestStreak) · best ever \(model.challengeBest(mode))")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Play again") { restart() }
                .buttonStyle(PrimaryButtonStyle(.teal))
            Button("Done") { dismiss() }
                .buttonStyle(QuietButtonStyle())
        }
        .padding(Metrics.gutter)
    }

    // MARK: Flow

    private func start() {
        guard questions.isEmpty else { return }
        questions = model.challengeBatch()
        startedAt = .now
    }

    private func restart() {
        run = ChallengeRun(mode: mode)
        questions = model.challengeBatch()
        index = 0
        selected = nil
        elapsed = 0
        isNewBest = false
        finished = false
        startedAt = .now
    }

    private func tick() async {
        guard mode.timeLimit != nil, let startedAt else { return }
        while !Task.isCancelled && !finished {
            try? await Task.sleep(for: .milliseconds(250))
            elapsed = Date.now.timeIntervalSince(startedAt)
            if run.isOver(elapsed: elapsed) { finish() }
        }
    }

    private func answer(_ offset: Int, question: QuizQuestion) {
        guard selected == nil, !finished else { return }
        selected = offset
        let ok = offset == question.answerIndex
        run.record(correct: ok)
        if !ok { withAnimation(.default) { shake += 1 } }
        model.recordAnswer(termID: question.termId, correct: ok)
        Task {
            try? await Task.sleep(for: .milliseconds(ok ? 450 : 900))
            guard !finished else { return }
            if run.isOver(elapsed: elapsed) {
                finish()
            } else {
                next()
            }
        }
    }

    private func next() {
        selected = nil
        index += 1
        if index >= questions.count - 3 {
            questions += model.challengeBatch()
        }
    }

    private func finish() {
        guard !finished else { return }
        isNewBest = model.recordChallenge(mode, score: run.score)
        finished = true
        if isNewBest { burst += 1 }
    }
}
