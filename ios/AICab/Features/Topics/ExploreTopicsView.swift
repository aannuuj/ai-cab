import SwiftUI
import AICabCore
import AICabDesign

enum LibraryRoute: Hashable {
    case favorites, collections, ownWords, history, saved
    case collection(UUID)
    case topic(String)
    case term(String)
}

/// "Explore topics": search, unlock banner, library tiles and illustrated topic sections.
struct ExploreTopicsView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var editingTopics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if query.isEmpty {
                    browse
                } else {
                    SearchResults(query: query)
                }
            }
            .scrollIndicators(.hidden)
            .background(Palette.charcoal.ignoresSafeArea())
            .navigationTitle("Explore topics")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search 300+ AI words")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editingTopics = true }
                }
            }
            .sheet(isPresented: $editingTopics) { TopicPickerSheet() }
            .navigationDestination(for: LibraryRoute.self) { route in
                LibraryDestination(route: route)
            }
            .navigationDestination(for: String.self) { id in
                TermDetailView(termID: id)
            }
        }
    }

    private var browse: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !model.isPro {
                UnlockBanner { model.sheet = .paywall(.banner) }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                LibraryTile(title: "Favorites", symbol: "heart.fill", palette: .teal, count: model.favorites.count, route: .favorites)
                LibraryTile(title: "Collections", symbol: "folder.fill", palette: .cream, count: model.state.collections.count, route: .collections)
                LibraryTile(title: "Your own words", symbol: "pencil.line", palette: .coral, count: model.state.customTerms.count, route: .ownWords)
                LibraryTile(title: "History", symbol: "clock.fill", palette: .olive, count: model.history.count, route: .history)
            }

            ForEach(TopicSection.allCases, id: \.self) { section in
                topicSection(section.title, topics: model.topics(in: section))
            }

            topicSection("By level", topics: model.levelTopics)

            if !model.isPro {
                PremiumFooter { model.sheet = .paywall(.banner) }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 120)
    }
}

extension ExploreTopicsView {
    @ViewBuilder
    fileprivate func topicSection(_ title: String, topics: [Topic]) -> some View {
        if !topics.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.serifTitle2)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(topics) { topic in
                        NavigationLink(value: LibraryRoute.topic(topic.id)) {
                            TopicCard(topic: topic, count: model.terms(in: topic).count, locked: model.isLocked(topic),
                                      selected: model.preferences.topicIds.contains(topic.id))
                        }
                        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: Metrics.tileRadius))
                    }
                }
            }
        }
    }
}

/// "Go Premium — Unlock all topics" footer at the end of the catalog.
private struct PremiumFooter: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 30))
                .foregroundStyle(Palette.gold)
                .frame(width: 68, height: 68)
                .background(Circle().fill(Palette.surface))
                .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
            Text("Go Premium")
                .font(.serifTitle2)
                .foregroundStyle(Palette.textPrimary)
            Text("Unlock all topics, Research definitions and every Journey chapter.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button("Unlock all topics", action: action)
                .buttonStyle(PrimaryButtonStyle(.teal))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

/// Teal "Unlock everything" banner.
struct UnlockBanner: View {
    var title = "Unlock everything"
    var message = "Every topic, Research-level definitions, all Journey chapters and themes."
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(.title2, weight: .bold))
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                IsoObject(symbol: "target", palette: .coral, size: 92)
            }
            .padding(.leading, 22)
            .padding(.trailing, 12)
            .padding(.vertical, 18)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.teal, radius: Metrics.tileRadius))
    }
}

private struct LibraryTile: View {
    let title: String
    let symbol: String
    let palette: ArtPalette
    let count: Int
    let route: LibraryRoute

    var body: some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.outline)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.art(palette).fill))
                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Text("\(count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: 26))
    }
}

/// Large illustrated topic card with a padlock when premium.
struct TopicCard: View {
    let topic: Topic
    let count: Int
    let locked: Bool
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                IsoObject(symbol: topic.symbol, palette: topic.palette, size: 84)
                Spacer()
                if locked {
                    LockBadge()
                } else if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Palette.teal)
                        .accessibilityLabel("In your feed")
                }
            }
            Spacer(minLength: 4)
            if let eyebrow = topic.eyebrow {
                Text(eyebrow)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            Text(topic.title)
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("\(count) words")
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityHint(locked ? "Pro topic" : "Opens the topic")
    }
}

/// Search across the whole catalog plus your own words.
private struct SearchResults: View {
    @Environment(AppModel.self) private var model
    let query: String

    private var results: [Term] {
        let q = query.lowercased()
        return model.allTerms
            .filter { $0.term.lowercased().contains(q) || ($0.expansion?.lowercased().contains(q) ?? false)
                || $0.definitions.beginner.lowercased().contains(q) }
            .sorted { lhs, rhs in
                let l = lhs.term.lowercased().hasPrefix(q), r = rhs.term.lowercased().hasPrefix(q)
                return l == r ? lhs.term < rhs.term : l
            }
    }

    var body: some View {
        LazyVStack(spacing: 10) {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 60)
            }
            ForEach(results) { term in
                TermRow(term: term)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 120)
    }
}

/// Reusable list row: word, short definition, saved/locked state. Taps open details.
struct TermRow: View {
    @Environment(AppModel.self) private var model
    let term: Term
    var trailing: String?

    var body: some View {
        let locked = model.isLocked(term)
        Button {
            model.sheet = locked ? .paywall(.lockedTopic) : .term(term.id)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(term.term)
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(term.definition(at: .beginner))
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing).font(.caption).foregroundStyle(Palette.textTertiary)
                }
                if locked {
                    LockBadge(color: Palette.textSecondary)
                } else if model.isSaved(term.id) {
                    Image(systemName: "bookmark.fill").foregroundStyle(Palette.teal)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !locked {
                Button(model.isSaved(term.id) ? "Remove from deck" : "Save to deck",
                       systemImage: model.isSaved(term.id) ? "bookmark.slash" : "bookmark") { model.toggleSave(term) }
                Button(model.isFavorite(term.id) ? "Unfavorite" : "Favorite",
                       systemImage: model.isFavorite(term.id) ? "heart.slash" : "heart") { model.toggleFavorite(term) }
                Button("Show in Words", systemImage: "house") { model.show(termID: term.id) }
            }
        }
    }
}

/// Choose which topics feed the Words tab.
struct TopicPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your Words feed mixes words from the topics you pick. Leave everything off to get a bit of all.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                ForEach(TopicSection.allCases, id: \.self) { section in
                    Section(section.title) {
                        ForEach(model.topics(in: section)) { topic in
                            let locked = model.isLocked(topic)
                            Button {
                                if locked {
                                    model.sheet = .paywall(.lockedTopic)
                                } else if selection.contains(topic.id) {
                                    selection.remove(topic.id)
                                } else {
                                    selection.insert(topic.id)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: topic.symbol).frame(width: 28).foregroundStyle(Palette.teal)
                                    Text(topic.title).foregroundStyle(Palette.textPrimary)
                                    Spacer()
                                    Image(systemName: locked ? "lock" : (selection.contains(topic.id) ? "checkmark.circle.fill" : "circle"))
                                        .foregroundStyle(selection.contains(topic.id) ? Palette.teal : Palette.textTertiary)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.charcoal)
            .navigationTitle("Your topics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.setTopics(model.topics.map(\.id).filter(selection.contains))
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear { selection = Set(model.preferences.topicIds) }
        }
        .presentationBackground(Palette.charcoal)
    }
}
