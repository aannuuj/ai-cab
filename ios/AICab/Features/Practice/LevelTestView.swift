import SwiftUI
import AICabCore
import AICabDesign

/// "What's your level?": three meaning questions per level, then sets the definition depth.
struct LevelTestView: View {
    @Environment(AppModel.self) private var model
    @State private var test: (rounds: [PlacementTest.Round], questions: [QuizQuestion])?
    @State private var tracker = Tracker()

    /// Reference box so answers recorded mid-quiz are visible to the summary closure.
    final class Tracker {
        var correctIds: Set<String> = []
        var level: Level?
    }

    var body: some View {
        Group {
            if let test {
                QuizSessionView(title: "Level check") {
                    test.questions
                } onFinish: { _, _ in
                    tracker.level = model.applyLevelTest(correctIds: tracker.correctIds, rounds: test.rounds)
                } onAnswer: { question, correct in
                    if correct { tracker.correctIds.insert(question.termId) }
                } summary: { _, _ in
                    let level = tracker.level ?? .beginner
                    let note = level.isPremium && !model.isPro
                        ? "Research definitions are part of Pro, so you'll see Builder depth until you upgrade."
                        : "Your Words feed now explains terms at this depth. Change it anytime from the dial."
                    return ("Your depth: \(level.title)", note)
                }
            } else {
                Palette.charcoal.ignoresSafeArea()
            }
        }
        .onAppear { if test == nil { test = model.levelTest() } }
    }
}
