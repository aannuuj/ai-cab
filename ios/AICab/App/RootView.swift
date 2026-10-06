import SwiftUI
import AICabCore
import AICabDesign

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.preferences.hasOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: model.preferences.hasOnboarded)
        .sheet(item: $model.sheet, onDismiss: nil) { sheet in
            switch sheet {
            case .term(let id):
                TermDetailSheet(termID: id)
            case .share(let id):
                if let term = model.term(id) { ShareSheetView(term: term) }
            case .paywall(let source):
                PaywallView(source: source)
            case .widgetInstall:
                WidgetInstallView(mode: .nudge)
            case .feedback:
                FeedbackView()
            case .saveDestination(let id):
                SaveDestinationSheet(termID: id)
            }
        }
        .overlay {
            if let nudge = model.overlayNudge {
                NudgeOverlay(nudge: nudge)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.overlayNudge)
        .preferredColorScheme(colorScheme)
    }

    /// Light status bar content only while reading on a light feed theme.
    private var colorScheme: ColorScheme {
        let lightFeed = model.preferences.hasOnboarded && model.selectedTab == .today && model.sheet == nil
            && FeedColors.isLight(model.preferences.feedTheme, custom: model.preferences.customTheme)
        if !model.preferences.hasOnboarded { return .dark }
        return lightFeed ? .light : .dark
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("Today", systemImage: "text.book.closed", value: AppTab.today) {
                WordsFeedView()
            }
            Tab("Explore", systemImage: "safari", value: AppTab.explore) {
                ExploreTopicsView()
            }
            Tab("Train", systemImage: "dumbbell", value: AppTab.train) {
                TrainView()
            }
            .badge(model.showJourneyBadge ? Text("New") : nil)
            Tab("You", systemImage: "person.crop.circle", value: AppTab.you) {
                ProfileView()
            }
        }
        .tint(Palette.teal)
        .modifier(TabBarMinimize())
    }
}

/// Liquid Glass tab bar shrinks while scrolling on iOS 26.
private struct TabBarMinimize: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

/// Path (units of short steps) and Drills (quizzes, timed modes, recall cards) under one tab.
struct TrainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            switch model.trainMode {
            case .path: JourneyView()
            case .drills: PracticeView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Train", selection: $model.trainMode) {
                ForEach(TrainMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Palette.charcoal)
        }
        .sensoryFeedback(.selection, trigger: model.trainMode)
    }
}
