import SwiftUI
import AICabCore
import AICabDesign

/// Runs one Journey lesson and records the result.
struct LessonView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let chapter: Chapter
    let lesson: LessonKind

    var body: some View {
        switch lesson {
        case .learn:
            LearnLessonView(chapter: chapter) {
                _ = model.completeLesson(.learn, chapter: chapter, correct: 1, total: 1)
            }
        case .match:
            MatchGameView(title: lesson.title,
                          pairs: QuizGenerator(level: .beginner).matchPairs(for: chapter.termIds.compactMap(model.term).shuffled(), count: 5)) { correct, total in
                _ = model.completeLesson(.match, chapter: chapter, correct: correct, total: total)
            }
        case .use, .recall, .compare, .test:
            QuizSessionView(title: lesson.title, passMark: lesson == .test ? JourneyEngine.passMark : nil) {
                model.questions(for: lesson, in: chapter)
            } onFinish: { correct, total in
                _ = model.completeLesson(lesson, chapter: chapter, correct: correct, total: total)
            }
        }
    }
}

/// Flip through the chapter's words as cards, then finish.
struct LearnLessonView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let chapter: Chapter
    let onFinish: () -> Void
    @State private var index = 0
    @State private var finished = false

    private var terms: [Term] { chapter.termIds.compactMap(model.term) }

    var body: some View {
        ZStack {
            Palette.charcoal.ignoresSafeArea()
            if finished {
                ResultView(correct: terms.count, total: terms.count, passMark: nil) { dismiss() }
            } else {
                VStack(spacing: 18) {
                    ProgressView(value: Double(index + 1), total: Double(max(terms.count, 1))).tint(Palette.teal)
                    Eyebrow("Word \(index + 1) of \(terms.count)")
                    TabView(selection: $index) {
                        ForEach(Array(terms.enumerated()), id: \.element.id) { offset, term in
                            LearnCard(term: term).tag(offset)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    Button(index + 1 < terms.count ? "Next word" : "Finish lesson") {
                        if index + 1 < terms.count {
                            withAnimation { index += 1 }
                        } else {
                            finished = true
                            onFinish()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(.teal))
                }
                .padding(Metrics.gutter)
            }
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Close", systemImage: "xmark") { dismiss() } }
        }
        .sensoryFeedback(.selection, trigger: index)
    }
}

private struct LearnCard: View {
    @Environment(AppModel.self) private var model
    let term: Term

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(term.term)
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.ink)
                if let expansion = term.expansion {
                    Text(expansion).font(.system(.headline, design: .serif).italic()).foregroundStyle(Palette.inkSoft)
                }
                PronunciationPill(ipa: term.ipa, colors: .forTheme(.cream), isSpeaking: model.speech.speakingID == term.id) {
                    model.speech.speak(term.term, id: term.id)
                }
                Text("(\(term.pos)) \(term.definition(at: model.level))")
                    .font(.title3)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let analogy = term.analogy {
                    Label(analogy, systemImage: "lightbulb.fill")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSoft)
                }
                if let example = term.example {
                    Text("\u{201C}\(example)\u{201D}")
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(Palette.inkSoft)
                }
                Button {
                    model.toggleSave(term)
                } label: {
                    Label(model.isSaved(term.id) ? "In your deck" : "Save to deck",
                          systemImage: model.isSaved(term.id) ? "bookmark.fill" : "bookmark")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(model.isSaved(term.id) ? Palette.teal : Palette.ivory))
                        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(TactileBackground(fill: Palette.cream, radius: 30))
        .padding(.bottom, Metrics.hardShadow)
        .padding(.horizontal, 2)
    }
}
