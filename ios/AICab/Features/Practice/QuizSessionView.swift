import SwiftUI
import AICabCore
import AICabDesign

/// Runs a multiple-choice quiz: progress, tactile answer tiles, instant feedback, results.
struct QuizSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let title: String
    let source: () -> [QuizQuestion]
    let passMark: Double?
    let onFinish: (Int, Int) -> Void
    /// Called after each answer (level test uses it to track which words were known).
    var onAnswer: ((QuizQuestion, Bool) -> Void)?
    /// Overrides the result headline and message.
    var summary: ((Int, Int) -> (headline: String, message: String))?

    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var selected: Int?
    @State private var correct = 0
    @State private var finished = false
    @State private var shake = 0

    init(title: String, passMark: Double? = nil, source: @escaping () -> [QuizQuestion], onFinish: @escaping (Int, Int) -> Void,
         onAnswer: ((QuizQuestion, Bool) -> Void)? = nil,
         summary: ((Int, Int) -> (headline: String, message: String))? = nil) {
        self.title = title
        self.passMark = passMark
        self.source = source
        self.onFinish = onFinish
        self.onAnswer = onAnswer
        self.summary = summary
    }

    var body: some View {
        ZStack {
            Palette.charcoal.ignoresSafeArea()
            if finished {
                ResultView(correct: correct, total: questions.count, passMark: passMark,
                           summary: summary?(correct, questions.count)) { dismiss() }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if let question = questions[safe: index] {
                questionView(question)
                    .id(question.id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            } else if !questions.isEmpty || finished {
                EmptyView()
            } else {
                ContentUnavailableView("Not enough words yet", systemImage: "text.book.closed",
                                       description: Text("Bookmark a few terms in Today, then come back."))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: index)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: finished)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
        .onAppear {
            if questions.isEmpty { questions = source() }
        }
        .sensoryFeedback(.error, trigger: shake)
    }

    private func questionView(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressView(value: Double(index + (selected == nil ? 0 : 1)), total: Double(max(questions.count, 1)))
                .tint(Palette.teal)
                .animation(.easeInOut, value: selected)
            Eyebrow("Question \(index + 1) of \(questions.count)")
            Text(question.prompt)
                .font(.serifTitle2)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = question.detail {
                Text(detail)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
            }
            VStack(spacing: 12) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { offset, choice in
                    choiceButton(choice, offset: offset, question: question)
                }
            }
            .modifier(Shake(animatableData: CGFloat(shake)))
            if selected != nil {
                VStack(alignment: .leading, spacing: 14) {
                    Label(selected == question.answerIndex ? "Nice!" : "Not quite",
                          systemImage: selected == question.answerIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(selected == question.answerIndex ? Palette.lime : Palette.coral)
                    Text(question.explanation)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(index + 1 < questions.count ? "Continue" : "See results") { advance() }
                        .buttonStyle(PrimaryButtonStyle(.teal))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.gutter)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected)
    }

    private func choiceButton(_ choice: String, offset: Int, question: QuizQuestion) -> some View {
        let isAnswer = offset == question.answerIndex
        let isPicked = offset == selected
        let fill: Color = {
            guard selected != nil else { return Palette.surface }
            if isAnswer { return Palette.teal }
            if isPicked { return Palette.coral }
            return Palette.surface
        }()
        return Button {
            answer(offset, question: question)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(choice)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if selected != nil && (isAnswer || isPicked) {
                    Image(systemName: isAnswer ? "checkmark" : "xmark").font(.headline)
                }
            }
            .foregroundStyle(selected != nil && (isAnswer || isPicked) ? Palette.ink : Palette.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(TactileButtonStyle(fill: fill, radius: 22))
        .disabled(selected != nil)
        .opacity(selected != nil && !isAnswer && !isPicked ? 0.55 : 1)
    }

    private func answer(_ offset: Int, question: QuizQuestion) {
        selected = offset
        let ok = offset == question.answerIndex
        if ok {
            correct += 1
        } else {
            withAnimation(.default) { shake += 1 }
        }
        model.recordAnswer(termID: question.termId, correct: ok)
        onAnswer?(question, ok)
    }

    private func advance() {
        if index + 1 < questions.count {
            selected = nil
            index += 1
        } else {
            finished = true
            onFinish(correct, questions.count)
        }
    }
}

/// End-of-quiz score card.
struct ResultView: View {
    let correct: Int
    let total: Int
    let passMark: Double?
    var summary: (headline: String, message: String)?
    let done: () -> Void
    @State private var burst = 0

    private var score: Double { total == 0 ? 0 : Double(correct) / Double(total) }
    private var passed: Bool { passMark.map { score >= $0 } ?? true }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().stroke(Palette.surface, lineWidth: 14)
                Circle().trim(from: 0, to: score)
                    .stroke(passed ? Palette.teal : Palette.coral, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(correct)/\(total)").font(.system(size: 44, weight: .bold, design: .serif))
                    Text("\(Int((score * 100).rounded()))%").font(.headline).foregroundStyle(Palette.textSecondary)
                }
                .foregroundStyle(Palette.textPrimary)
            }
            .frame(width: 190, height: 190)
            Text(summary?.headline ?? headline)
                .font(.serifTitle)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(summary?.message ?? message)
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(passed ? "Done" : "Back to the path", action: done)
                .buttonStyle(PrimaryButtonStyle(passed ? .teal : .coral))
        }
        .padding(Metrics.gutter)
        .overlay { ConfettiBurst(trigger: burst) }
        .onAppear { if passed && score >= 0.8 { burst += 1 } }
        .sensoryFeedback(passed ? .success : .warning, trigger: burst)
    }

    private var headline: String {
        if !passed { return "So close" }
        switch score {
        case 1: return "Flawless"
        case 0.8...: return "Great work"
        case 0.5...: return "Getting there"
        default: return "Keep practising"
        }
    }

    private var message: String {
        if let passMark, !passed {
            return "You need \(Int(passMark * 100))% to open the next unit. Missed terms come back in your reviews."
        }
        return "Missed words come back in your reviews so they stick."
    }
}

/// Horizontal shake for a wrong answer.
struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
