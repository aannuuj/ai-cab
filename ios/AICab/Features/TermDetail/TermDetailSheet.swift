import SwiftUI
import AICabCore
import AICabDesign

/// Everything about one term: all three levels, analogy, example, origin, related terms.
struct TermDetailSheet: View {
    let termID: String

    var body: some View {
        NavigationStack {
            TermDetailView(termID: termID)
                .navigationDestination(for: String.self) { id in
                    TermDetailView(termID: id)
                }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.charcoal)
    }
}

struct TermDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let termID: String
    @State private var newCollectionName = ""
    @State private var showingNewCollection = false

    var body: some View {
        if let term = model.term(termID) {
            content(term)
        } else {
            ContentUnavailableView("Word not found", systemImage: "questionmark.circle")
        }
    }

    private func content(_ term: Term) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(term)
                levels(term)
                if let analogy = term.analogy {
                    infoCard(title: "Think of it like", symbol: "lightbulb", text: analogy, tint: Palette.gold)
                }
                if let example = term.example {
                    infoCard(title: "In a sentence", symbol: "text.quote", text: "\u{201C}\(example)\u{201D}", tint: Palette.teal, serif: true)
                }
                if let origin = term.origin {
                    infoCard(title: "Origin", symbol: "clock.arrow.circlepath", text: origin, tint: Palette.coral)
                }
                related(term)
                progress(term)
            }
            .padding(Metrics.gutter)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Palette.charcoal)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done", systemImage: "xmark") { dismiss() }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                collectionMenu(term)
                Button("Share", systemImage: "square.and.arrow.up") { model.sheet = .share(term.id) }
            }
        }
        .alert("New collection", isPresented: $showingNewCollection) {
            TextField("Name", text: $newCollectionName)
            Button("Create") {
                model.createCollection(named: newCollectionName, with: term.id)
                newCollectionName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func header(_ term: Term) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(term.difficulty.title.uppercased())
                    .font(.caption.weight(.bold)).tracking(1.2)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(difficultyColor(term.difficulty)))
                ForEach(term.topics.compactMap { id in model.topics.first { $0.id == id } }.prefix(2)) { topic in
                    Text(topic.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().strokeBorder(Color.white.opacity(0.15)))
                }
            }
            Text(term.term)
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            if let expansion = term.expansion {
                Text(expansion)
                    .font(.system(.title3, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary)
            }
            HStack(spacing: 12) {
                PronunciationPill(ipa: term.ipa, colors: .forTheme(.charcoal), isSpeaking: model.speech.speakingID == term.id) {
                    model.speech.speak(term.term, id: term.id)
                }
                Spacer()
                Button {
                    model.toggleFavorite(term)
                } label: {
                    Image(systemName: model.isFavorite(term.id) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(model.isFavorite(term.id) ? Palette.coral : Palette.textPrimary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel("Favorite")
                Button {
                    model.toggleSave(term)
                } label: {
                    Image(systemName: model.isSaved(term.id) ? "bookmark.fill" : "bookmark")
                        .font(.title2)
                        .foregroundStyle(model.isSaved(term.id) ? Palette.teal : Palette.textPrimary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel("Save to deck")
            }
        }
    }

    private func levels(_ term: Term) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Level.allCases) { level in
                let locked = level.isPremium && !model.isPro
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(level.title.uppercased())
                            .font(.caption.weight(.bold)).tracking(1.5)
                            .foregroundStyle(level == model.level ? Palette.teal : Palette.textSecondary)
                        Spacer()
                        if locked { LockBadge(color: Palette.textSecondary).font(.caption) }
                    }
                    Text(term.definition(at: level))
                        .font(.body)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .blur(radius: locked ? 6 : 0)
                        .overlay {
                            if locked {
                                Button("Unlock research definitions") { model.sheet = .paywall(.researchLevel) }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.teal)
                            }
                        }
                }
                if level != .research { Divider().overlay(Color.white.opacity(0.08)) }
            }
        }
        .padding(20)
        .tactileCard()
    }

    private func infoCard(title: String, symbol: String, text: String, tint: Color, serif: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(serif ? .system(.body, design: .serif).italic() : .body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
    }

    @ViewBuilder
    private func related(_ term: Term) -> some View {
        let links = (term.contrastWith + term.related).compactMap(model.term)
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Related")
                    .font(.serifTitle3)
                    .foregroundStyle(Palette.textPrimary)
                FlowLayout(spacing: 8) {
                    ForEach(links) { link in
                        NavigationLink(value: link.id) {
                            Chip(term.contrastWith.contains(link.id) ? "vs. \(link.term)" : link.term,
                                 systemImage: term.contrastWith.contains(link.id) ? "arrow.left.arrow.right" : nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func progress(_ term: Term) -> some View {
        let p = model.progress(term.id)
        return HStack(spacing: 0) {
            stat("\(p.seenCount)", "Seen")
            stat(p.isSaved ? (p.isMastered ? "Mastered" : "Box \(p.box)") : "–", "Review")
            stat("\(p.correct)/\(p.correct + p.wrong)", "Quiz")
        }
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundStyle(Palette.textPrimary)
            Text(label).font(.caption).foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func collectionMenu(_ term: Term) -> some View {
        Menu {
            ForEach(model.state.collections) { collection in
                Button {
                    model.toggle(term.id, in: collection.id)
                } label: {
                    Label(collection.name, systemImage: collection.termIds.contains(term.id) ? "checkmark.circle.fill" : "circle")
                }
            }
            Divider()
            Button("New collection…", systemImage: "plus") { showingNewCollection = true }
        } label: {
            Label("Add to collection", systemImage: "folder.badge.plus")
        }
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .beginner: Palette.lime
        case .intermediate: Palette.gold
        case .pro: Palette.coral
        }
    }
}
