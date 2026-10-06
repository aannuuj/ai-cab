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
                examples(term)
                if let origin = term.origin {
                    if model.isPro {
                        infoCard(title: "Origin", symbol: "clock.arrow.circlepath", text: origin, tint: Palette.coral)
                    } else {
                        LockedSection(title: "Origin", symbol: "clock.arrow.circlepath", lines: 3) {
                            model.sheet = .paywall(.researchLevel)
                        }
                    }
                }
                related(term)
                progress(term)
                if !model.isPro {
                    Button {
                        model.sheet = .paywall(.banner)
                    } label: {
                        Label("Unlock everything", systemImage: "crown.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(.teal))
                    .padding(.top, 4)
                }
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
                ForEach(term.topics.compactMap(model.topic).prefix(2)) { topic in
                    Text(topic.title)
                        .lineLimit(1)
                        .fixedSize()
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
                    if locked {
                        Button {
                            model.sheet = .paywall(.researchLevel)
                        } label: {
                            SkeletonLines(count: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Research definition, Pro. Unlock")
                    } else {
                        Text(term.definition(at: level))
                            .font(.body)
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
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

    /// "Examples" with numbered sentences and the word in bold.
    @ViewBuilder
    private func examples(_ term: Term) -> some View {
        let sentences = [term.example].compactMap { $0 }
        if !sentences.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Examples", systemImage: "text.quote")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.teal)
                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Palette.teal))
                        Text(Self.highlight(term.term, in: sentence))
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
        }
    }

    /// Bolds every case-insensitive occurrence of the word.
    static func highlight(_ word: String, in sentence: String) -> AttributedString {
        var attributed = AttributedString(sentence)
        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex,
              let range = attributed[searchStart...].range(of: word, options: .caseInsensitive) {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
            searchStart = range.upperBound
        }
        return attributed
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

/// Placeholder bars standing in for Pro-only text.
struct SkeletonLines: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 12)
                    .frame(maxWidth: index == count - 1 ? 180 : .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .center) {
            Image(systemName: "lock.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Palette.gold))
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}

/// A detail card whose contents are Pro: header plus skeleton bars.
struct LockedSection: View {
    let title: String
    let symbol: String
    let lines: Int
    let unlock: () -> Void

    var body: some View {
        Button(action: unlock) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(title, systemImage: symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text("PRO").font(.caption2.weight(.heavy)).tracking(1.2)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.gold))
                }
                SkeletonLines(count: lines)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), Pro")
        .accessibilityHint("Opens the upgrade screen")
    }
}
