import SwiftUI
import AICabCore
import AICabDesign

/// Practice hub: daily quiz, spaced-repetition reviews, tests and the match game.
struct PracticeView: View {
    @Environment(AppModel.self) private var model
    @State private var session: PracticeSession?

    enum PracticeSession: String, Identifiable {
        case daily, review, test, favorites, match
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    deckSummary
                    dailyCard
                    PracticeRow(title: "Review due words",
                                subtitle: model.dueReviews.isEmpty ? "All caught up. Come back tomorrow." : "\(model.dueReviews.count) words are ready to refresh",
                                symbol: "arrow.triangle.2.circlepath", palette: .coral,
                                badge: model.dueReviews.isEmpty ? nil : "\(model.dueReviews.count)",
                                disabled: model.dueReviews.isEmpty) { session = .review }
                    PracticeRow(title: "Take a test", subtitle: "10 questions across everything you've seen",
                                symbol: "book.pages", palette: .cream) { session = .test }
                    PracticeRow(title: "Match game", subtitle: "Pair terms with their meanings, against the clock",
                                symbol: "puzzlepiece.extension", palette: .olive) { session = .match }
                    PracticeRow(title: "Practice favorites", subtitle: model.favorites.count < 4 ? "Favorite at least 4 words to unlock" : "\(model.favorites.count) favorites",
                                symbol: "heart", palette: .teal, disabled: model.favorites.count < 4) { session = .favorites }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Palette.charcoal.ignoresSafeArea())
            .navigationTitle("Practice")
            .navigationDestination(for: LibraryRoute.self) { LibraryDestination(route: $0) }
            .navigationDestination(for: String.self) { TermDetailView(termID: $0) }
            .fullScreenCover(item: $session) { session in
                NavigationStack { sessionView(session) }
            }
        }
    }

    private var deckSummary: some View {
        NavigationLink(value: LibraryRoute.saved) {
            HStack(spacing: 0) {
                summaryStat("\(model.state.learnedCount)", "In your deck")
                Divider().frame(height: 36).overlay(Color.white.opacity(0.1))
                summaryStat("\(model.state.masteredCount)", "Mastered")
                Divider().frame(height: 36).overlay(Color.white.opacity(0.1))
                summaryStat("\(model.streak)", "Day streak")
            }
            .padding(.vertical, 18)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: 26))
    }

    private func summaryStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var dailyCard: some View {
        let done = model.dailyQuizDoneToday
        return Button {
            if !done { session = .daily }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(done ? "Done for today" : "Daily quiz", color: Palette.ink.opacity(0.6))
                    Text(done ? "\(model.state.dailyQuiz?.correct ?? 0)/\(model.state.dailyQuiz?.total ?? 3) correct" : "3 questions, 1 minute")
                        .font(.serifTitle2)
                        .foregroundStyle(Palette.ink)
                    Text(done ? "A new quiz unlocks tomorrow." : "Active recall makes words stick 2x better than rereading.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                IsoObject(symbol: done ? "checkmark.seal.fill" : "bolt.fill", palette: .coral, size: 86)
            }
            .padding(20)
        }
        .buttonStyle(TactileButtonStyle(fill: done ? Palette.lime : Palette.teal, radius: Metrics.tileRadius))
    }

    @ViewBuilder
    private func sessionView(_ session: PracticeSession) -> some View {
        switch session {
        case .daily:
            QuizSessionView(title: "Daily quiz") { model.dailyQuizQuestions() } onFinish: { correct, total in
                model.completeDailyQuiz(correct: correct, total: total)
            }
        case .review:
            QuizSessionView(title: "Review") { model.quiz(for: model.dueReviews, count: min(10, model.dueReviews.count)) } onFinish: { _, _ in }
        case .test:
            QuizSessionView(title: "Test") {
                let seen = model.history.map(\.term) + model.savedTerms
                return model.quiz(for: seen.count >= 10 ? seen : model.quizPool(), count: 10)
            } onFinish: { _, _ in }
        case .favorites:
            QuizSessionView(title: "Favorites") { model.quiz(for: model.favorites, count: min(10, model.favorites.count)) } onFinish: { _, _ in }
        case .match:
            let pool = model.savedTerms.count >= 4 ? model.savedTerms : model.quizPool()
            MatchGameView(title: "Match", pairs: QuizGenerator(level: .beginner).matchPairs(for: pool.shuffled(), count: 5)) { _, _ in }
        }
    }
}

struct PracticeRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let palette: ArtPalette
    var badge: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.art(palette).fill))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(Palette.textPrimary)
                    Text(subtitle).font(.subheadline).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if let badge {
                    Text(badge).font(.caption.bold()).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.coral))
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Palette.textTertiary)
            }
            .padding(16)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: 26))
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}
