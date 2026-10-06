import SwiftUI
import AICabCore
import AICabDesign

/// The home feed: one AI term per full-screen page, swiped vertically.
struct WordsFeedView: View {
    @Environment(AppModel.self) private var model
    @State private var currentID: String?
    @State private var celebrating = false
    @State private var showingCoach = false

    static let saveTip = "save5"

    private var colors: FeedColors { .forTheme(model.preferences.feedTheme) }

    var body: some View {
        ZStack(alignment: .top) {
            colors.background.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(model.feed) { term in
                        TermPage(term: term, colors: colors)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(term.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $currentID)
            .ignoresSafeArea()

            VStack(spacing: 10) {
                header
                if let toast = model.saveToast {
                    SaveToastView(toast: toast, colors: colors) {
                        model.saveToast = nil
                        model.sheet = .saveDestination(toast.termID)
                    }
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: model.saveToast)
        }
        .sheet(isPresented: $showingCoach, onDismiss: { model.markTipSeen(Self.saveTip) }) {
            SaveCoachSheet { showingCoach = false }
        }
        .task {
            guard !model.hasSeenTip(Self.saveTip), model.savedTerms.count < 5 || model.isScreenshotRun else { return }
            try? await Task.sleep(for: .seconds(model.isScreenshotRun ? 0.3 : 1.5))
            if model.sheet == nil { showingCoach = true }
        }
        .overlay {
            GoalCelebration(isPresented: $celebrating, streak: model.streak, goal: model.dailyGoal, name: model.preferences.name)
        }
        .onAppear {
            model.ensureFeed()
            if currentID == nil, let first = model.feed.first {
                currentID = first.id
            }
        }
        .onChange(of: currentID) { _, id in
            guard let id, let term = model.feed.first(where: { $0.id == id }) else { return }
            model.didShow(term)
        }
        .onChange(of: model.feedScrollTarget) { _, target in
            guard let target else { return }
            withAnimation(.snappy) { currentID = target }
            model.feedScrollTarget = nil
        }
        .onChange(of: model.celebration) {
            celebrating = true
        }
        .sensoryFeedback(.selection, trigger: currentID)
    }

    private var header: some View {
        HStack(alignment: .center) {
            LevelMenu(colors: colors)
            Spacer()
            DailyGoalPill(saved: model.savedToday, goal: model.dailyGoal, tint: colors.chrome)
            Spacer()
            GlassIconButton(model.isPro ? "crown.fill" : "crown", size: 50, tint: colors.chrome,
                            badge: !model.isPro, accessibilityLabel: model.isPro ? "AI-Cab Pro" : "Unlock Pro") {
                if !model.isPro { model.sheet = .paywall(.crown) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

/// Glass pill to switch definition depth.
private struct LevelMenu: View {
    @Environment(AppModel.self) private var model
    let colors: FeedColors

    var body: some View {
        Menu {
            ForEach(Level.allCases) { level in
                Button {
                    model.setLevel(level)
                } label: {
                    Label {
                        Text(level.title)
                        Text(level.blurb)
                    } icon: {
                        if level == model.level {
                            Image(systemName: "checkmark")
                        } else if level.isPremium && !model.isPro {
                            Image(systemName: "lock")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: levelSymbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(colors.chrome)
                .frame(width: 50, height: 50)
                .glassCircle()
        }
        .accessibilityLabel("Definition level: \(model.level.title)")
    }

    private var levelSymbol: String {
        switch model.level {
        case .beginner: "dial.low"
        case .builder: "dial.medium"
        case .research: "dial.high"
        }
    }
}

/// One full-screen word.
struct TermPage: View {
    @Environment(AppModel.self) private var model
    let term: Term
    let colors: FeedColors
    @State private var heartBurst = 0

    var body: some View {
        let level = model.level
        let favorite = model.isFavorite(term.id)
        let saved = model.isSaved(term.id)

        VStack(spacing: 0) {
            Spacer(minLength: 110)

            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    if term.isNew(relativeTo: .now) || term.isCustom {
                        Text(term.isCustom ? "YOUR WORD" : "NEW THIS WEEK")
                            .font(.caption2.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Palette.teal))
                    }
                    Text(term.term)
                        .font(.wordDisplay)
                        .foregroundStyle(colors.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .accessibilityAddTraits(.isHeader)
                    if let expansion = term.expansion {
                        Text(expansion)
                            .font(.system(.headline, design: .serif).italic())
                            .foregroundStyle(colors.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                PronunciationPill(ipa: term.ipa, colors: colors, isSpeaking: model.speech.speakingID == term.id) {
                    model.speech.speak(term.expansion.map { "\(term.term). \($0)" } ?? term.term, id: term.id)
                }

                Text("(\(term.pos)) \(term.definition(at: level))")
                    .font(.definition)
                    .foregroundStyle(colors.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: level)

                if let example = term.example {
                    Text("\u{201C}\(example)\u{201D}")
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(colors.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 30)

            Spacer(minLength: 24)

            HStack {
                actionButton("info.circle", label: "Details") { model.sheet = .term(term.id) }
                actionButton("square.and.arrow.up", label: "Share") { model.sheet = .share(term.id) }
                actionButton(favorite ? "heart.fill" : "heart", label: favorite ? "Unfavorite" : "Favorite",
                             tint: favorite ? Palette.coral : colors.chrome) {
                    model.toggleFavorite(term)
                }
                .symbolEffect(.bounce, value: favorite)
                actionButton(saved ? "bookmark.fill" : "bookmark", label: saved ? "Remove from deck" : "Save to deck",
                             tint: saved ? Palette.tealDeep : colors.chrome) {
                    model.toggleSaveFromFeed(term)
                }
                .symbolEffect(.bounce, value: saved)
            }
            .padding(.horizontal, 26)
            .sensoryFeedback(.impact(weight: .light), trigger: favorite)
            .sensoryFeedback(.success, trigger: saved) { _, isSaved in isSaved }

            Spacer().frame(height: 132)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if !favorite { model.toggleFavorite(term) }
            heartBurst += 1
        }
        .overlay { HeartBurst(trigger: heartBurst) }
        .accessibilityAction(named: "Save to deck") { model.toggleSaveFromFeed(term) }
    }

    private func actionButton(_ symbol: String, label: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(tint ?? colors.chrome)
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// "Saved to **Your deck** · Change" glass toast under the header.
private struct SaveToastView: View {
    let toast: SaveToast
    let colors: FeedColors
    let change: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Saved to \(Text(toast.destination).bold())")
                .font(.subheadline)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: change) {
                Text("Change")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(TactileButtonStyle(fill: Palette.teal, radius: 18))
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.ink.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Change") { change() }
    }
}

/// First-run tip: save five words to personalise the feed.
private struct SaveCoachSheet: View {
    let done: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                IsoObject(symbol: "bookmark.fill", palette: .teal, size: 104)
                IsoDisc(symbol: "sparkles", size: 48, tint: Palette.coral)
                    .offset(x: 58, y: -38)
            }
            .padding(.top, 26)
            Text("Get words that match your interests")
                .font(.serifTitle2)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text("Personalize your feed by saving at least 5 words with \(Image(systemName: "bookmark.fill"))")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button("Got it!", action: done)
                .buttonStyle(PrimaryButtonStyle(.teal))
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.charcoal)
        .presentationCornerRadius(36)
    }
}

/// "Change" from the save toast: choose which collection feed saves go to.
struct SaveDestinationSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let termID: String
    @State private var newName = ""
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Your deck", subtitle: "Saved words only", symbol: "bookmark.fill", selected: model.defaultCollectionID == nil) {
                        model.chooseSaveDestination(nil, for: termID)
                        dismiss()
                    }
                } footer: {
                    Text("Every saved word lands in your deck for review. Pick a collection to also file new saves there.")
                }
                Section("Collections") {
                    ForEach(model.state.collections) { collection in
                        row(collection.name, subtitle: "\(collection.termIds.count) words", symbol: "folder.fill",
                            selected: model.defaultCollectionID == collection.id) {
                            model.chooseSaveDestination(collection.id, for: termID)
                            dismiss()
                        }
                    }
                    Button("New collection…", systemImage: "plus") { creating = true }
                        .foregroundStyle(Palette.teal)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.charcoal)
            .navigationTitle("Save to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .alert("New collection", isPresented: $creating) {
                TextField("Name", text: $newName)
                Button("Create") {
                    model.createCollection(named: newName)
                    if let created = model.state.collections.last { model.chooseSaveDestination(created.id, for: termID) }
                    newName = ""
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.charcoal)
    }

    private func row(_ title: String, subtitle: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).foregroundStyle(Palette.teal).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Palette.textPrimary)
                    Text(subtitle).font(.caption).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(Palette.teal).fontWeight(.semibold) }
            }
        }
    }
}

/// Big heart that pops on double-tap.
private struct HeartBurst: View {
    let trigger: Int
    @State private var visible = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 110))
            .foregroundStyle(Palette.coral)
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .scaleEffect(visible ? 1 : 0.4)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
            .onChange(of: trigger) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { visible = true }
                withAnimation(.easeOut(duration: 0.35).delay(0.6)) { visible = false }
            }
            .accessibilityHidden(true)
    }
}

/// Celebration shown when today's goal is met.
struct GoalCelebration: View {
    @Binding var isPresented: Bool
    let streak: Int
    let goal: Int
    var name: String?
    @State private var burst = 0

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.35).ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Palette.teal).frame(width: 96, height: 96)
                            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(Palette.ink)
                            .symbolEffect(.bounce, value: burst)
                    }
                    Text(name.map { "Nice work, \($0)" } ?? "Daily goal complete")
                        .font(.serifTitle)
                        .foregroundStyle(Palette.textPrimary)
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").foregroundStyle(Palette.coral)
                        Text(streak == 1 ? "Your streak starts today" : "\(streak)-day streak")
                    }
                    .font(.headline)
                    .foregroundStyle(Palette.textSecondary)
                    Text("\(goal) new AI words in your deck. See you tomorrow.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Keep going") { isPresented = false }
                        .buttonStyle(PrimaryButtonStyle(.teal))
                        .padding(.top, 6)
                }
                .padding(28)
                .tactileCard(fill: Palette.charcoal)
                .padding(.horizontal, 28)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            ConfettiBurst(trigger: burst)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isPresented)
        .onChange(of: isPresented) { _, shown in
            if shown { burst += 1 }
        }
        .sensoryFeedback(.success, trigger: burst)
    }
}
