import SwiftUI
import AICabCore
import AICabDesign

/// Practice hub: level test, daily quiz, reviews, challenges, game types, flash cards and topic quizzes.
struct PracticeView: View {
    @Environment(AppModel.self) private var model
    @State private var session: PracticeSession?

    private let twoColumns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    levelTestCard
                    deckSummary
                    dailyCard

                    sectionHeader("For you")
                    PracticeRow(title: "Review due words",
                                subtitle: model.dueReviews.isEmpty ? "All caught up. Come back tomorrow." : "\(model.dueReviews.count) words are ready to refresh",
                                symbol: "arrow.triangle.2.circlepath", palette: .coral,
                                badge: model.dueReviews.isEmpty ? nil : "\(model.dueReviews.count)",
                                disabled: model.dueReviews.isEmpty) { session = .review }
                    PracticeRow(title: "Your history", subtitle: model.history.count < 4 ? "Read a few words first" : "Quiz the last words you read",
                                symbol: "clock.arrow.circlepath", palette: .olive, disabled: model.history.count < 4) { session = .history }
                    PracticeRow(title: "Practice favorites", subtitle: model.favorites.count < 4 ? "Favorite at least 4 words to unlock" : "\(model.favorites.count) favorites",
                                symbol: "heart", palette: .teal, disabled: model.favorites.count < 4) { session = .favorites }

                    sectionHeader("Challenges")
                    HStack(spacing: 12) {
                        ForEach(ChallengeMode.allCases) { mode in
                            ChallengeTile(mode: mode, best: model.challengeBest(mode), locked: model.isLocked(mode)) {
                                if model.isLocked(mode) { model.sheet = .paywall(.banner) } else { session = .challenge(mode) }
                            }
                        }
                    }

                    sectionHeader("Games")
                    shuffleCard
                    LazyVGrid(columns: twoColumns, spacing: 14) {
                        GameTile(title: "Match pairs", symbol: "puzzlepiece.extension.fill", palette: .olive) { session = .match }
                        ForEach(PracticeGame.singles) { game in
                            GameTile(title: game.title, symbol: game.symbol, palette: game.palette) { session = .game(game) }
                        }
                    }

                    sectionHeader("Study")
                    flashCardsCard

                    sectionHeader("Categories")
                    ForEach(model.topics.prefix(8)) { topic in
                        CategoryRow(topic: topic, locked: model.isLocked(topic)) {
                            if model.isLocked(topic) { model.sheet = .paywall(.lockedTopic) } else { session = .topic(topic.id) }
                        }
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Palette.charcoal.ignoresSafeArea())
            .navigationTitle("Practice")
            .toolbar {
                if !model.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Unlock all") { model.sheet = .paywall(.banner) }
                    }
                }
            }
            .navigationDestination(for: LibraryRoute.self) { LibraryDestination(route: $0) }
            .navigationDestination(for: String.self) { TermDetailView(termID: $0) }
            .fullScreenCover(item: $session) { session in
                NavigationStack { sessionView(session) }
            }
            .onAppear(perform: openScreenshotSession)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(Palette.textSecondary)
            .padding(.top, 10)
            .accessibilityAddTraits(.isHeader)
    }

    private var levelTestCard: some View {
        Button { session = .levelTest } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What's your level?")
                        .font(.serifTitle3)
                        .foregroundStyle(Palette.textPrimary)
                    Text("9 quick questions set your definition depth")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                    Text("Take free test")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Palette.teal))
                        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
                StairsIllustration()
                    .scaleEffect(0.3)
                    .frame(width: 96, height: 100)
                    .accessibilityHidden(true)
            }
            .padding(20)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: Metrics.tileRadius))
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

    private var shuffleCard: some View {
        Button { session = .game(.shuffle) } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Try Game shuffle")
                        .font(.serifTitle3)
                        .foregroundStyle(Palette.textPrimary)
                    Text("A mix of all games")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                    Text("Start")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Palette.teal))
                        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
                        .padding(.top, 8)
                }
                Spacer(minLength: 0)
                ZStack {
                    IsoObject(symbol: "shuffle", palette: .cream, size: 84)
                    IsoDisc(symbol: "questionmark", size: 40, tint: Palette.coral)
                        .offset(x: 40, y: 30)
                }
            }
            .padding(20)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: Metrics.tileRadius))
    }

    private var flashCardsCard: some View {
        Button { session = .flashCards } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Flash cards")
                        .font(.serifTitle3)
                        .foregroundStyle(Palette.textPrimary)
                    Text("The best way to practice and learn words")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                IsoObject(symbol: "rectangle.on.rectangle.angled", palette: .teal, size: 84)
            }
            .padding(20)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: Metrics.tileRadius))
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
        case .history:
            QuizSessionView(title: "Your history") { model.quiz(for: Array(model.history.prefix(30).map(\.term)), count: 10) } onFinish: { _, _ in }
        case .favorites:
            QuizSessionView(title: "Favorites") { model.quiz(for: model.favorites, count: min(10, model.favorites.count)) } onFinish: { _, _ in }
        case .match:
            let pool = model.savedTerms.count >= 4 ? model.savedTerms : model.quizPool()
            MatchGameView(title: "Match pairs", pairs: QuizGenerator(level: .beginner).matchPairs(for: pool.shuffled(), count: 5)) { _, _ in }
        case .game(let game):
            QuizSessionView(title: game.title) { model.gameQuestions(kinds: game.kinds) } onFinish: { _, _ in }
        case .challenge(let mode):
            ChallengeSessionView(mode: mode)
        case .flashCards:
            FlashCardsView()
        case .levelTest:
            LevelTestView()
        case .topic(let id):
            let terms = model.topic(id).map { model.terms(in: $0).filter { !model.isLocked($0) } } ?? []
            QuizSessionView(title: model.topic(id)?.title ?? "Topic") { model.quiz(for: terms, count: 10) } onFinish: { _, _ in }
        }
    }

    private func openScreenshotSession() {
        guard session == nil else { return }
        switch ScreenshotMode.current {
        case .challenge: session = .challenge(.sprint)
        case .flashcards: session = .flashCards
        case .levelTest: session = .levelTest
        default: break
        }
    }
}

enum PracticeSession: Identifiable, Hashable {
    case daily, review, history, favorites, match, flashCards, levelTest
    case game(PracticeGame)
    case challenge(ChallengeMode)
    case topic(String)

    var id: String {
        switch self {
        case .daily: "daily"
        case .review: "review"
        case .history: "history"
        case .favorites: "favorites"
        case .match: "match"
        case .flashCards: "flash"
        case .levelTest: "level"
        case .game(let game): "game.\(game.rawValue)"
        case .challenge(let mode): "challenge.\(mode.rawValue)"
        case .topic(let id): "topic.\(id)"
        }
    }
}

/// Multiple-choice game types, each a slice of the quiz generator.
enum PracticeGame: String, CaseIterable, Identifiable {
    case shuffle, meaning, gap, guess, acronym

    var id: String { rawValue }
    static var singles: [PracticeGame] { [.meaning, .gap, .guess] }

    var title: String {
        switch self {
        case .shuffle: "Game shuffle"
        case .meaning: "Meaning match"
        case .gap: "Fill in the gap"
        case .guess: "Guess the word"
        case .acronym: "Expand it"
        }
    }

    var kinds: [QuizQuestion.Kind] {
        switch self {
        case .shuffle: QuizQuestion.Kind.allCases
        case .meaning: [.pickDefinition]
        case .gap: [.useInSentence]
        case .guess: [.pickTerm]
        case .acronym: [.expansion]
        }
    }

    var symbol: String {
        switch self {
        case .shuffle: "shuffle"
        case .meaning: "text.bubble.fill"
        case .gap: "character.cursor.ibeam"
        case .guess: "questionmark.square.dashed"
        case .acronym: "textformat.abc"
        }
    }

    var palette: ArtPalette {
        switch self {
        case .shuffle: .cream
        case .meaning: .coral
        case .gap: .teal
        case .guess: .cream
        case .acronym: .olive
        }
    }
}

/// Square illustrated tile with the title bottom-left.
private struct GameTile: View {
    let title: String
    let symbol: String
    let palette: ArtPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                IsoObject(symbol: symbol, palette: palette, size: 96)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: Metrics.tileRadius))
    }
}

/// Sprint / Rush / Perfection tile with the personal best.
private struct ChallengeTile: View {
    let mode: ChallengeMode
    let best: Int
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    IsoDisc(symbol: symbol, size: 46, tint: tint)
                    Spacer(minLength: 0)
                    if locked { LockBadge(color: Palette.textSecondary).font(.caption) }
                }
                Spacer(minLength: 0)
                Text(mode.title)
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(best > 0 ? "Best \(best)" : mode.tagline)
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: 24))
        .accessibilityLabel("\(mode.title). \(mode.tagline)\(best > 0 ? ". Best \(best)" : "")\(locked ? ". Pro" : "")")
    }

    private var symbol: String {
        switch mode {
        case .sprint: "stopwatch.fill"
        case .rush: "heart.fill"
        case .perfection: "seal.fill"
        }
    }

    private var tint: Color {
        switch mode {
        case .sprint: Palette.teal
        case .rush: Palette.coral
        case .perfection: Palette.gold
        }
    }
}

/// Wide topic row for topic quizzes.
private struct CategoryRow: View {
    let topic: Topic
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(topic.title)
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if locked { LockBadge(color: Palette.textSecondary).font(.caption) }
                Spacer(minLength: 0)
                IsoObject(symbol: topic.symbol, palette: topic.palette, size: 70)
            }
            .padding(.leading, 22)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 92)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: 26))
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
