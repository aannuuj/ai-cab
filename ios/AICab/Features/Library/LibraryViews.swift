import SwiftUI
import AICabCore
import AICabDesign

/// Resolves library navigation routes (shared by Topics and Profile).
struct LibraryDestination: View {
    let route: LibraryRoute

    var body: some View {
        switch route {
        case .favorites: FavoritesView()
        case .saved: SavedWordsView()
        case .collections: CollectionsView()
        case .collection(let id): CollectionDetailView(collectionID: id)
        case .ownWords: OwnWordsView()
        case .history: HistoryView()
        case .topic(let id): TopicDetailView(topicID: id)
        case .term(let id): TermDetailView(termID: id)
        }
    }
}

/// Shared chrome for library lists.
private struct LibraryList<Content: View>: View {
    let title: String
    let isEmpty: Bool
    let emptyTitle: String
    let emptySymbol: String
    let emptyMessage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            if isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: emptySymbol)
                } description: {
                    Text(emptyMessage)
                }
                .padding(.top, 80)
            } else {
                LazyVStack(spacing: 10) { content() }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 120)
            }
        }
        .background(Palette.charcoal.ignoresSafeArea())
        .navigationTitle(title)
    }
}

struct FavoritesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        LibraryList(title: "Favorites", isEmpty: model.favorites.isEmpty, emptyTitle: "No favorites yet",
                    emptySymbol: "heart", emptyMessage: "Tap the heart, or double-tap a word, to keep it here.") {
            ForEach(model.favorites) { TermRow(term: $0) }
        }
    }
}

struct SavedWordsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        LibraryList(title: "Your deck", isEmpty: model.savedTerms.isEmpty, emptyTitle: "Your deck is empty",
                    emptySymbol: "bookmark", emptyMessage: "Save words with the bookmark. They come back for review right before you'd forget them.") {
            ForEach(model.savedTerms) { term in
                let p = model.progress(term.id)
                TermRow(term: term, trailing: p.isMastered ? "Mastered" : "Box \(p.box)/5")
            }
        }
    }
}

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        LibraryList(title: "History", isEmpty: model.history.isEmpty, emptyTitle: "Nothing yet",
                    emptySymbol: "clock", emptyMessage: "Words you've seen will show up here.") {
            ForEach(model.history.prefix(200)) { item in
                TermRow(term: item.term, trailing: item.date.formatted(.relative(presentation: .named)))
            }
        }
    }
}

struct CollectionsView: View {
    @Environment(AppModel.self) private var model
    @State private var creating = false
    @State private var name = ""

    var body: some View {
        LibraryList(title: "Collections", isEmpty: model.state.collections.isEmpty, emptyTitle: "No collections",
                    emptySymbol: "folder", emptyMessage: "Group words for a project, a meeting or an exam. Tap + to start one.") {
            ForEach(model.state.collections) { collection in
                NavigationLink(value: LibraryRoute.collection(collection.id)) {
                    HStack {
                        Image(systemName: "folder.fill").foregroundStyle(Palette.gold)
                        Text(collection.name).font(.headline).foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text("\(collection.termIds.count)").foregroundStyle(Palette.textSecondary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.textTertiary)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) { model.deleteCollection(collection.id) }
                }
            }
        }
        .toolbar {
            Button("New collection", systemImage: "plus") {
                if model.isPro || model.state.collections.count < 2 {
                    creating = true
                } else {
                    model.sheet = .paywall(.settings)
                }
            }
        }
        .alert("New collection", isPresented: $creating) {
            TextField("Name", text: $name)
            Button("Create") {
                model.createCollection(named: name)
                name = ""
            }
            Button("Cancel", role: .cancel) { name = "" }
        } message: {
            Text("Free accounts can keep two collections.")
        }
    }
}

struct CollectionDetailView: View {
    @Environment(AppModel.self) private var model
    let collectionID: UUID

    private var collection: UserCollection? { model.state.collections.first { $0.id == collectionID } }

    var body: some View {
        let terms = collection?.termIds.compactMap(model.term) ?? []
        LibraryList(title: collection?.name ?? "Collection", isEmpty: terms.isEmpty, emptyTitle: "Empty collection",
                    emptySymbol: "folder", emptyMessage: "Open any word's details and use the folder button to add it here.") {
            NavigationLink {
                QuizSessionView(title: collection?.name ?? "Collection") {
                    model.quiz(for: terms, count: min(10, terms.count))
                } onFinish: { _, _ in }
            } label: {
                Label("Practice this collection", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(TactileButtonStyle(fill: Palette.teal, radius: 26))
            .disabled(terms.count < 2)
            ForEach(terms) { TermRow(term: $0) }
        }
    }
}

struct TopicDetailView: View {
    @Environment(AppModel.self) private var model
    let topicID: String

    var body: some View {
        if let topic = model.topic(topicID) {
            let terms = model.terms(in: topic)
            let saved = terms.filter { model.isSaved($0.id) }.count
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            if let eyebrow = topic.eyebrow { Eyebrow(eyebrow) }
                            Text(topic.title).font(.serifLargeTitle).foregroundStyle(Palette.textPrimary)
                            Text("\(saved) of \(terms.count) in your deck")
                                .font(.subheadline).foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                        IsoObject(symbol: topic.symbol, palette: topic.palette, size: 110)
                    }
                    ProgressView(value: Double(saved), total: Double(max(terms.count, 1)))
                        .tint(Palette.teal)
                    Button {
                        model.learn(topic: topic)
                    } label: {
                        Label(model.isLocked(topic) ? "Unlock this topic" : "Learn these words", systemImage: model.isLocked(topic) ? "lock.open" : "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(.teal))
                    ForEach(terms) { TermRow(term: $0) }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 120)
            }
            .background(Palette.charcoal.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// "Your own words": add a term you came across, optionally drafted by AI.
struct OwnWordsView: View {
    @Environment(AppModel.self) private var model
    @State private var adding = false

    var body: some View {
        LibraryList(title: "Your own words", isEmpty: model.state.customTerms.isEmpty, emptyTitle: "Add a word you heard",
                    emptySymbol: "pencil.line", emptyMessage: "Heard a term in a meeting or a podcast? Add it and it joins your feed and reviews.") {
            ForEach(model.state.customTerms) { term in
                TermRow(term: term)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { model.deleteCustomTerm(term.id) }
                    }
            }
        }
        .toolbar {
            Button("Add word", systemImage: "plus") { adding = true }
        }
        .sheet(isPresented: $adding) { AddWordView() }
    }
}

struct AddWordView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var pos = "n."
    @State private var beginner = ""
    @State private var builder = ""
    @State private var research = ""
    @State private var example = ""
    @State private var drafting = false
    @State private var error: String?

    private var canSave: Bool {
        !term.trimmingCharacters(in: .whitespaces).isEmpty && !beginner.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Term, e.g. \u{201C}context rot\u{201D}", text: $term)
                        .textInputAutocapitalization(.never)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                    Picker("Part of speech", selection: $pos) {
                        ForEach(["n.", "v.", "adj.", "adv."], id: \.self) { Text($0) }
                    }
                    if model.drafter != nil {
                        Button {
                            Task { await draft() }
                        } label: {
                            HStack {
                                Label("Draft with AI", systemImage: "sparkles")
                                if drafting { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty || drafting)
                    }
                    if let error { Text(error).font(.footnote).foregroundStyle(Palette.coral) }
                }
                Section("Plain English") {
                    TextField("What it means, simply", text: $beginner, axis: .vertical)
                }
                Section("For builders (optional)") {
                    TextField("How engineers use it", text: $builder, axis: .vertical)
                }
                Section("Research depth (optional)") {
                    TextField("The technical detail", text: $research, axis: .vertical)
                }
                Section("Example (optional)") {
                    TextField("Use it in a sentence", text: $example, axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.charcoal)
            .navigationTitle("New word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let b = beginner.trimmingCharacters(in: .whitespacesAndNewlines)
                        model.addCustomTerm(
                            term: term,
                            pos: pos,
                            definitions: Definitions(beginner: b,
                                                     builder: builder.isEmpty ? b : builder,
                                                     research: research.isEmpty ? (builder.isEmpty ? b : builder) : research),
                            example: example
                        )
                        dismiss()
                    }
                    .bold()
                    .disabled(!canSave)
                }
            }
        }
        .presentationBackground(Palette.charcoal)
    }

    private func draft() async {
        guard let drafter = model.drafter else { return }
        guard model.isPro else {
            model.sheet = .paywall(.ownWords)
            return
        }
        drafting = true
        error = nil
        defer { drafting = false }
        do {
            let result = try await drafter.draft(term: term)
            pos = result.pos
            beginner = result.beginner
            builder = result.builder
            research = result.research
            example = result.example ?? example
        } catch {
            self.error = error.localizedDescription
        }
    }
}
