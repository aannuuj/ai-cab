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
        let lightFeed = model.preferences.hasOnboarded && model.selectedTab == .words && model.sheet == nil
            && FeedColors.isLight(model.preferences.feedTheme)
        if !model.preferences.hasOnboarded { return .dark }
        return lightFeed ? .light : .dark
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("Words", systemImage: "house", value: AppTab.words) {
                WordsFeedView()
            }
            Tab("Topics", systemImage: "square.grid.2x2", value: AppTab.topics) {
                ExploreTopicsView()
            }
            Tab("Journey", systemImage: "map", value: AppTab.journey) {
                JourneyView()
            }
            .badge(model.showJourneyBadge ? Text("New") : nil)
            Tab("Practice", systemImage: "graduationcap", value: AppTab.practice) {
                PracticeView()
            }
            Tab("Profile", systemImage: "person", value: AppTab.profile) {
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
