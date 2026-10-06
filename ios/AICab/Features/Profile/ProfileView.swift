import SwiftUI
import StoreKit
import AICabCore
import AICabDesign

/// Progress (streak, stats, library) on top; settings below.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var editingTopics = false
    @State private var showingWidgetGuide = false
    @State private var managingSubscription = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StreakCard(streak: model.streak, days: model.week)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    statsRow
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    NavigationLink(value: LibraryRoute.saved) { row("Your deck", "bookmark.fill", Palette.teal, detail: "\(model.state.learnedCount)") }
                    NavigationLink(value: LibraryRoute.favorites) { row("Favorites", "heart.fill", Palette.coral, detail: "\(model.favorites.count)") }
                    NavigationLink(value: LibraryRoute.history) { row("History", "clock.fill", Palette.gold, detail: "\(model.history.count)") }
                    NavigationLink(value: LibraryRoute.collections) { row("Collections", "folder.fill", Palette.oliveSoft, detail: "\(model.state.collections.count)") }
                }

                proSection
                learningSection
                RemindersSection()
                appearanceSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Palette.charcoal.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationDestination(for: LibraryRoute.self) { LibraryDestination(route: $0) }
            .navigationDestination(for: String.self) { TermDetailView(termID: $0) }
            .sheet(isPresented: $editingTopics) { TopicPickerSheet() }
            .sheet(isPresented: $showingWidgetGuide) { WidgetInstallView(mode: .settings) }
            .manageSubscriptionsSheet(isPresented: $managingSubscription)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat("\(model.state.learnedCount)", "Words saved", "bookmark.fill")
            stat("\(model.state.masteredCount)", "Mastered", "checkmark.seal.fill")
            stat("\(model.longestStreak)", "Best streak", "flame.fill")
        }
    }

    private func stat(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Palette.teal)
            Text(value).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(Palette.textPrimary)
            Text(label).font(.caption).foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
    }

    private func row(_ title: String, _ symbol: String, _ tint: Color, detail: String? = nil) -> some View {
        HStack {
            Label {
                Text(title).foregroundStyle(Palette.textPrimary)
            } icon: {
                Image(systemName: symbol).foregroundStyle(tint)
            }
            Spacer()
            if let detail { Text(detail).foregroundStyle(Palette.textSecondary) }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if model.isPro {
                row("AI-Cab Pro is active", "crown.fill", Palette.gold)
                if let trialEnd = model.purchases.trialEndDate {
                    Toggle(isOn: Binding(get: { model.preferences.trialReminderEnabled },
                                         set: { value in
                                             model.setTrialReminder(value)
                                             Task { await model.rescheduleNotifications() }
                                         })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remind me before my trial ends")
                            Text("Trial ends \(trialEnd.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(Palette.textSecondary)
                        }
                    }
                    .tint(Palette.teal)
                }
                Button { managingSubscription = true } label: { row("Manage subscription", "creditcard", Palette.textSecondary) }
            } else {
                Button { model.sheet = .paywall(.settings) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Go Pro").font(.headline).foregroundStyle(Palette.ink)
                            Text("All topics, Research depth, every chapter and theme.")
                                .font(.subheadline).foregroundStyle(Palette.ink.opacity(0.75))
                        }
                        Spacer()
                        Image(systemName: "crown.fill").font(.title2).foregroundStyle(Palette.ink)
                    }
                }
                .listRowBackground(Palette.teal)
            }
            Button { Task { await model.purchases.restore() } } label: { row("Restore purchases", "arrow.clockwise", Palette.textSecondary) }
        }
    }

    private var learningSection: some View {
        Section("Learning") {
            Picker(selection: Binding(get: { model.preferences.level }, set: { model.setLevel($0) })) {
                ForEach(Level.allCases) { level in
                    Text(level.isPremium && !model.isPro ? "\(level.title) (Pro)" : level.title).tag(level)
                }
            } label: {
                row("Definition depth", "dial.medium", Palette.teal)
            }
            Stepper(value: Binding(get: { model.dailyGoal }, set: { model.setDailyGoal($0) }), in: Preferences.dailyGoalRange) {
                HStack {
                    row("Daily goal", "target", Palette.coral)
                    Text("\(model.dailyGoal) words").foregroundStyle(Palette.textSecondary)
                }
            }
            Button { editingTopics = true } label: {
                row("Topics in your feed", "square.grid.2x2", Palette.gold,
                    detail: model.preferences.topicIds.isEmpty ? "All" : "\(model.preferences.topicIds.count)")
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Word feed theme").foregroundStyle(Palette.textPrimary)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(FeedTheme.allCases) { theme in
                            ThemeSwatch(theme: theme, selected: model.preferences.feedTheme == theme,
                                        locked: theme.isPremium && !model.isPro) {
                                model.setFeedTheme(theme)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("App icon").foregroundStyle(Palette.textPrimary)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(AppIconOption.all) { option in
                            let selected = model.preferences.appIcon == option.iconName
                            Button { model.setAppIcon(option.iconName) } label: {
                                Image(option.previewAsset)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .padding(3)
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(selected ? Palette.teal : .clear, lineWidth: 2.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(option.title) icon")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
            Button { showingWidgetGuide = true } label: {
                row("Add a widget", "rectangle.3.group", Palette.teal)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Button { requestReview() } label: { row("Rate AI-Cab", "star.fill", Palette.gold) }
            Button { model.sheet = .feedback } label: { row("Send feedback", "envelope.fill", Palette.teal) }
            if let id = model.config.appStoreID, let url = URL(string: "https://apps.apple.com/app/id\(id)") {
                ShareLink(item: url, message: Text("I'm learning the language of AI with AI-Cab")) {
                    row("Share AI-Cab", "square.and.arrow.up", Palette.coral)
                }
            }
            Button { openURL(model.config.privacyURL) } label: { row("Privacy policy", "hand.raised.fill", Palette.textSecondary) }
            Button { openURL(model.config.termsURL) } label: { row("Terms of use", "doc.text.fill", Palette.textSecondary) }
            HStack {
                Text("Version").foregroundStyle(Palette.textSecondary)
                Spacer()
                Text("\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") · content v\(model.content.version)")
                    .foregroundStyle(Palette.textTertiary)
            }
            .font(.footnote)
        }
    }
}

/// Reminder settings with a permission-aware toggle.
private struct RemindersSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var settings = ReminderSettings()
    @State private var loaded = false

    var body: some View {
        Section {
            Toggle(isOn: $settings.isEnabled) {
                Label("Word reminders", systemImage: "bell.badge.fill")
            }
            .tint(Palette.teal)
            if settings.isEnabled {
                Stepper(value: $settings.perDay, in: ReminderSettings.perDayRange) {
                    HStack {
                        Text("How many")
                        Spacer()
                        Text("\(settings.perDay)x a day").foregroundStyle(Palette.textSecondary)
                    }
                }
                DatePicker("Start at", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("End at", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute)
            }
            if model.notificationStatus == .denied {
                Button("Notifications are off. Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .foregroundStyle(Palette.coral)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Words arrive spread across your window. You'll also get a gentle streak reminder in the evening if today's goal isn't done.")
        }
        .onAppear {
            settings = model.preferences.reminders
            loaded = true
        }
        .onChange(of: settings) { _, newValue in
            guard loaded, newValue != model.preferences.reminders else { return }
            Task {
                let enabled = await model.updateReminders(newValue)
                if newValue.isEnabled && !enabled { settings.isEnabled = false }
            }
        }
    }

    private func minuteBinding(_ keyPath: WritableKeyPath<ReminderSettings, Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: settings[keyPath: keyPath] / 60, minute: settings[keyPath: keyPath] % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            settings[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }
}

private struct ThemeSwatch: View {
    let theme: FeedTheme
    let selected: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        let colors = FeedColors.forTheme(theme)
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.background)
                    Text("Aa").font(.system(.title3, design: .serif, weight: .bold)).foregroundStyle(colors.primary)
                    if locked {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(colors.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(6)
                    }
                }
                .frame(width: 62, height: 78)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Palette.teal : Color.white.opacity(0.12), lineWidth: selected ? 3 : 1))
                Text(theme.title).font(.caption).foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.title) theme\(locked ? ", Pro" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
