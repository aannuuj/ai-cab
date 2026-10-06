import SwiftUI
import StoreKit
import AVFoundation
import AICabCore
import AICabDesign

enum ProfileRoute: Hashable {
    case settings, reminders, voices, themes, appIcon
}

/// Streak and stats on top, then illustrated tiles for the things people tweak most; the gear opens full settings.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var widgetGuide: WidgetGuide?

    enum WidgetGuide: String, Identifiable {
        case home, lock
        var id: String { rawValue }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    StreakCard(streak: model.streak, days: model.week)
                    statsRow
                    LazyVGrid(columns: columns, spacing: 14) {
                        NavigationLink(value: ProfileRoute.reminders) {
                            ProfileTile(title: "Reminders", symbol: "bell.badge.fill", palette: .teal,
                                        detail: model.preferences.reminders.isEnabled ? "\(model.preferences.reminders.perDay)x a day" : "Off")
                        }
                        NavigationLink(value: ProfileRoute.voices) {
                            ProfileTile(title: "Voices", symbol: "waveform", palette: .cream, detail: voiceName)
                        }
                        Button { widgetGuide = .home } label: {
                            ProfileTile(title: "Home Screen widgets", symbol: "apps.iphone", palette: .teal, detail: nil)
                        }
                        Button { widgetGuide = .lock } label: {
                            ProfileTile(title: "Lock Screen widgets", symbol: "lock.iphone", palette: .cream, detail: nil)
                        }
                        NavigationLink(value: ProfileRoute.themes) {
                            ProfileTile(title: "Themes", symbol: "textformat", palette: .coral, detail: model.preferences.feedTheme.title)
                        }
                        NavigationLink(value: ProfileRoute.appIcon) {
                            ProfileTile(title: "App icon", symbol: "app.gift.fill", palette: .olive,
                                        detail: AppIconOption.all.first { $0.iconName == model.preferences.appIcon }?.title)
                        }
                    }
                    .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: Metrics.tileRadius))

                    if !model.isPro {
                        UnlockBanner { model.sheet = .paywall(.settings) }
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Palette.charcoal.ignoresSafeArea())
            .navigationTitle(model.preferences.name.map { "Hi, \($0)" } ?? "Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: ProfileRoute.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .settings: SettingsView()
                case .reminders: RemindersScreen()
                case .voices: VoicesView()
                case .themes: ThemesView()
                case .appIcon: AppIconView()
                }
            }
            .navigationDestination(for: LibraryRoute.self) { LibraryDestination(route: $0) }
            .navigationDestination(for: String.self) { TermDetailView(termID: $0) }
            .sheet(item: $widgetGuide) { guide in
                WidgetInstallView(mode: .settings, startOnLockScreen: guide == .lock)
            }
            .navigationDestination(isPresented: $screenshotVoices) { VoicesView() }
        }
    }

    @State private var screenshotVoices = ScreenshotMode.current == .voices

    private var voiceName: String {
        model.preferences.voiceIdentifier.flatMap { AVSpeechSynthesisVoice(identifier: $0)?.name } ?? "Default"
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

}

/// Everything else: library, Pro, learning, reminders, appearance, about.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var editingTopics = false
    @State private var showingWidgetGuide = false
    @State private var managingSubscription = false

    var body: some View {
        List {
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingTopics) { TopicPickerSheet() }
        .sheet(isPresented: $showingWidgetGuide) { WidgetInstallView(mode: .settings) }
        .manageSubscriptionsSheet(isPresented: $managingSubscription)
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

/// Illustrated profile tile: art on top, title bottom-left.
private struct ProfileTile: View {
    let title: String
    let symbol: String
    let palette: ArtPalette
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IsoObject(symbol: symbol, palette: palette, size: 92)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            Spacer(minLength: 0)
            Text(title)
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

struct RemindersScreen: View {
    var body: some View {
        List { RemindersSection() }
            .scrollContentBackground(.hidden)
            .background(Palette.charcoal.ignoresSafeArea())
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Pronunciation voice and speed.
struct VoicesView: View {
    @Environment(AppModel.self) private var model
    @State private var rate = SpeechService.defaultRate
    @State private var voices: [AVSpeechSynthesisVoice] = []

    private let sample = "Retrieval-augmented generation"

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Speed")
                        Spacer()
                        Text(rateLabel).foregroundStyle(Palette.textSecondary)
                    }
                    Slider(value: $rate, in: 0.5...1.3, step: 0.1) {
                        Text("Speed")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise.fill")
                    } maximumValueLabel: {
                        Image(systemName: "hare.fill")
                    } onEditingChanged: { editing in
                        if !editing {
                            model.setVoice(model.preferences.voiceIdentifier, rate: rate)
                            preview(id: "voice.rate")
                        }
                    }
                    .tint(Palette.teal)
                }
                .padding(.vertical, 4)
            }

            Section {
                voiceRow(name: "System default", detail: "English (US)", id: nil)
                ForEach(voices, id: \.identifier) { voice in
                    voiceRow(name: voice.name, detail: detail(for: voice), id: voice.identifier)
                }
            } header: {
                Text("Voice")
            } footer: {
                Text("Download Enhanced and Premium voices in Settings › Accessibility › Spoken Content › Voices › English.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.charcoal.ignoresSafeArea())
        .navigationTitle("Voices")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rate = model.preferences.speechRate ?? SpeechService.defaultRate
            if voices.isEmpty { voices = SpeechService.englishVoices }
        }
    }

    private var rateLabel: String {
        switch rate {
        case ..<0.75: "Slow"
        case ..<1.05: "Normal"
        default: "Fast"
        }
    }

    private func voiceRow(name: String, detail: String, id: String?) -> some View {
        let selected = model.preferences.voiceIdentifier == id
        let rowID = "voice.\(id ?? "default")"
        return Button {
            model.setVoice(id, rate: rate)
            preview(id: rowID)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: model.speech.speakingID == rowID ? "speaker.wave.3.fill" : "speaker.wave.2")
                    .foregroundStyle(Palette.teal)
                    .frame(width: 26)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).foregroundStyle(Palette.textPrimary)
                    Text(detail).font(.caption).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if selected { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Palette.teal) }
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func detail(for voice: AVSpeechSynthesisVoice) -> String {
        let region = Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
        switch voice.quality {
        case .premium: return "\(region) · Premium"
        case .enhanced: return "\(region) · Enhanced"
        default: return region
        }
    }

    private func preview(id: String) {
        model.speech.speak(sample, id: id)
    }
}

/// Word feed themes as large previews.
struct ThemesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(FeedTheme.allCases) { theme in
                    let colors = FeedColors.forTheme(theme)
                    let selected = model.preferences.feedTheme == theme
                    let locked = theme.isPremium && !model.isPro
                    Button { model.setFeedTheme(theme) } label: {
                        VStack(spacing: 10) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(colors.background)
                                VStack(spacing: 6) {
                                    Text("token")
                                        .font(.system(size: 30, weight: .bold, design: .serif))
                                        .foregroundStyle(colors.primary)
                                    Text("The unit a model reads")
                                        .font(.caption)
                                        .foregroundStyle(colors.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                if locked {
                                    LockBadge(color: colors.secondary).padding(12)
                                }
                            }
                            .frame(height: 200)
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(selected ? Palette.teal : Color.white.opacity(0.12), lineWidth: selected ? 3 : 1))
                            Text(theme.title)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.title) theme\(locked ? ", Pro" : "")")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(Metrics.gutter)
            .padding(.bottom, 100)
        }
        .background(Palette.charcoal.ignoresSafeArea())
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Alternate app icons.
struct AppIconView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 18)], spacing: 22) {
                ForEach(AppIconOption.all) { option in
                    let selected = model.preferences.appIcon == option.iconName
                    Button { model.setAppIcon(option.iconName) } label: {
                        VStack(spacing: 8) {
                            Image(option.previewAsset)
                                .resizable()
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .padding(4)
                                .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous)
                                    .strokeBorder(selected ? Palette.teal : .clear, lineWidth: 3))
                            Text(option.title)
                                .font(.caption)
                                .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.title) icon")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(Metrics.gutter)
        }
        .background(Palette.charcoal.ignoresSafeArea())
        .navigationTitle("App icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}
