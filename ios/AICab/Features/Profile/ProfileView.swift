import SwiftUI
import StoreKit
import AVFoundation
import AICabCore
import AICabDesign

enum ProfileRoute: Hashable {
    case settings, stats, reminders, voices, themes, appIcon, alarm
    case widgets(lockScreen: Bool)
}

/// Go Premium, a level test and "Customize the app" tiles; the gear opens full settings.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var editingTopics = false
    @State private var takingTest = false
    @State private var path = NavigationPath(ProfileView.screenshotPath)

    private static var screenshotPath: [ProfileRoute] {
        switch ScreenshotMode.current {
        case .voices: [.voices]
        case .gallery: [.themes]
        case .stats: [.stats]
        default: []
        }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !model.isPro {
                        UnlockBanner(title: "Go Premium",
                                     message: "Access all topics, Research depth, every chapter, theme and game.") {
                            model.sheet = .paywall(.settings)
                        }
                    }
                    testRow

                    Text("Customize the app")
                        .font(.serifTitle2)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: columns, spacing: 14) {
                        NavigationLink(value: ProfileRoute.stats) {
                            ProfileTile(title: "Stats", symbol: "chart.bar.fill", palette: .teal,
                                        detail: model.streak > 0 ? "\(model.streak)-day streak" : "\(model.state.learnedCount) words saved")
                        }
                        Button { editingTopics = true } label: {
                            ProfileTile(title: "Topics you follow", symbol: "square.stack.3d.up.fill", palette: .cream,
                                        detail: model.preferences.topicIds.isEmpty ? "All topics" : "\(model.preferences.topicIds.count) topics")
                        }
                        NavigationLink(value: ProfileRoute.reminders) {
                            ProfileTile(title: "Reminders", symbol: "bell.badge.fill", palette: .teal,
                                        detail: model.preferences.reminders.isEnabled ? "\(model.preferences.reminders.perDay)x a day" : "Off")
                        }
                        NavigationLink(value: ProfileRoute.voices) {
                            ProfileTile(title: "Voices", symbol: "waveform", palette: .cream, detail: voiceName)
                        }
                        NavigationLink(value: ProfileRoute.widgets(lockScreen: false)) {
                            ProfileTile(title: "Home Screen widgets", symbol: "apps.iphone", palette: .teal, detail: nil)
                        }
                        NavigationLink(value: ProfileRoute.widgets(lockScreen: true)) {
                            ProfileTile(title: "Lock Screen widgets", symbol: "lock.iphone", palette: .cream, detail: nil)
                        }
                        if PracticeAlarm.isSupported {
                            NavigationLink(value: ProfileRoute.alarm) {
                                ProfileTile(title: "Alarm", symbol: "alarm.fill", palette: .coral, detail: alarmDetail)
                            }
                        }
                        NavigationLink(value: ProfileRoute.themes) {
                            ProfileTile(title: "Themes", symbol: "textformat", palette: .coral, detail: model.preferences.feedTheme.title)
                        }
                        NavigationLink(value: ProfileRoute.appIcon) {
                            ProfileTile(title: "App icon", symbol: "app.gift.fill", palette: .olive,
                                        detail: AppIconOption.all.first { $0.iconName == model.preferences.appIcon }?.title ?? "Classic")
                        }
                    }
                    .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: Metrics.tileRadius))
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
                case .stats: StatsView()
                case .reminders: RemindersScreen()
                case .voices: VoicesView()
                case .themes: ThemesView()
                case .appIcon: AppIconView()
                case .alarm: AlarmView()
                case .widgets(let lockScreen):
                    WidgetInstallView(mode: .settings, startOnLockScreen: lockScreen)
                        .navigationTitle(lockScreen ? "Lock Screen widgets" : "Home Screen widgets")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .navigationDestination(for: LibraryRoute.self) { LibraryDestination(route: $0) }
            .navigationDestination(for: String.self) { TermDetailView(termID: $0) }
            .sheet(isPresented: $editingTopics) { TopicPickerSheet() }
            .fullScreenCover(isPresented: $takingTest) {
                NavigationStack { LevelTestView() }
            }
        }
    }

    private var testRow: some View {
        Button { takingTest = true } label: {
            HStack(spacing: 16) {
                IsoObject(symbol: "graduationcap.fill", palette: .teal, size: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Take a test")
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("to see your current level · \(model.level.title) now")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Palette.textTertiary)
            }
            .padding(16)
        }
        .buttonStyle(TactileButtonStyle(fill: Palette.surface, radius: 26))
    }

    private var voiceName: String {
        model.preferences.voiceIdentifier.flatMap { AVSpeechSynthesisVoice(identifier: $0)?.name } ?? "Default"
    }

    private var alarmDetail: String {
        guard let minute = model.alarmMinute else { return "Off" }
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// Streak, totals and the last two weeks of saves.
struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StreakCard(streak: model.streak, days: model.week)
                HStack(spacing: 12) {
                    stat("\(model.state.learnedCount)", "Words saved", "bookmark.fill")
                    stat("\(model.state.masteredCount)", "Mastered", "checkmark.seal.fill")
                    stat("\(model.longestStreak)", "Best streak", "flame.fill")
                }
                fortnight
                HStack(spacing: 12) {
                    stat("\(model.history.count)", "Words read", "eye.fill")
                    stat("\(model.state.journey.completed.count)", "Lessons done", "map.fill")
                    stat("\(model.challengeBest(.sprint))", "Sprint best", "stopwatch.fill")
                }
            }
            .padding(Metrics.gutter)
            .padding(.bottom, 100)
        }
        .background(Palette.charcoal.ignoresSafeArea())
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fortnight: some View {
        let calendar = Calendar.current
        let days: [(String, Int)] = (0..<14).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            return (DayKey.string(for: date, calendar: calendar), model.state.activity.savedByDay[DayKey.string(for: date, calendar: calendar)] ?? 0)
        }
        let peak = max(days.map { $0.1 }.max() ?? 0, model.dailyGoal, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Words saved · last 14 days")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days.indices, id: \.self) { index in
                    let count = days[index].1
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(count >= model.dailyGoal ? Palette.teal : Palette.surfaceRaised)
                        .frame(height: max(6, 110 * CGFloat(count) / CGFloat(peak)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Goal met on \(days.filter { $0.1 >= model.dailyGoal }.count) of the last 14 days")
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
    }

    private func stat(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Palette.teal)
            Text(value).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(Palette.textPrimary)
            Text(label).font(.caption).foregroundStyle(Palette.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
    }
}

/// Daily AlarmKit alarm that rings through Silent mode.
struct AlarmView: View {
    @Environment(AppModel.self) private var model
    @State private var isOn = false
    @State private var time = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: .now) ?? .now
    @State private var failed = false
    @State private var loaded = false

    var body: some View {
        List {
            Section {
                Toggle("Alarm", isOn: $isOn).tint(Palette.teal)
                if isOn {
                    DatePicker("Rings at", selection: $time, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Set an alarm that reminds you to practice words every day")
                    .textCase(nil)
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.bottom, 8)
            } footer: {
                Text(failed ? "Alarms aren't allowed. Turn them on in Settings › AI-Cab › Alarms & Timers."
                     : "Unlike reminders, the alarm rings even in Silent mode or a Focus. Stop it from the Lock Screen.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.charcoal.ignoresSafeArea())
        .navigationTitle("Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let minute = model.alarmMinute {
                isOn = true
                time = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? time
            }
            loaded = true
        }
        .onChange(of: isOn) { apply() }
        .onChange(of: time) { if isOn { apply() } }
    }

    private func apply() {
        guard loaded else { return }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let minute = isOn ? (parts.hour ?? 8) * 60 + (parts.minute ?? 30) : nil
        Task {
            let on = await model.setAlarm(minute: minute)
            failed = isOn && !on
            if !on { isOn = false }
        }
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
            NavigationLink(value: ProfileRoute.themes) {
                row("Word feed theme", "textformat", Palette.coral, detail: model.preferences.feedTheme.title)
            }
            NavigationLink(value: ProfileRoute.appIcon) {
                row("App icon", "app.gift.fill", Palette.oliveSoft)
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

/// Theme gallery: category chips, sections, Free badges, and "Create" for a custom colour + font.
struct ThemesView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: ThemeCategory?
    @State private var creating = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !model.isPro {
                    UnlockBanner(title: "Unlock all themes", message: "Browse themes and pick the one that fits your vibe.") {
                        model.sheet = .paywall(.shareTheme)
                    }
                }
                chips
                if model.preferences.customTheme != nil && filter == nil {
                    section(ThemeCategory.custom.title, themes: [.custom])
                }
                ForEach(ThemeCategory.galleryOrder.filter { filter == nil || filter == $0 }) { category in
                    section(category.title, themes: FeedTheme.gallery.filter { $0.category == category })
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(Palette.charcoal.ignoresSafeArea())
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $creating) { CustomThemeEditor() }
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                Button { creating = true } label: { Chip("Create", systemImage: "plus") }
                Button { filter = nil } label: { Chip("All", isSelected: filter == nil) }
                ForEach(ThemeCategory.galleryOrder) { category in
                    Button { filter = category } label: { Chip(category.title, isSelected: filter == category) }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Metrics.gutter)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Metrics.gutter)
    }

    private func section(_ title: String, themes: [FeedTheme]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.serifTitle3)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(themes) { theme in
                    ThemePreviewTile(theme: theme, custom: model.preferences.customTheme,
                                     selected: model.preferences.feedTheme == theme,
                                     showFreeBadge: !model.isPro && !theme.isPremium,
                                     locked: theme.isPremium && !model.isPro) {
                        if theme == .custom && model.preferences.feedTheme == .custom {
                            creating = true
                        } else {
                            model.setFeedTheme(theme)
                        }
                    }
                }
            }
        }
    }
}

/// Tall "Aa" theme preview.
struct ThemePreviewTile: View {
    let theme: FeedTheme
    var custom: CustomFeedTheme?
    let selected: Bool
    let showFreeBadge: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        let colors = FeedColors.forTheme(theme, custom: custom)
        Button(action: action) {
            ZStack {
                FeedBackground(theme: theme, custom: custom)
                Text("Aa")
                    .font(colors.font.display(size: 34))
                    .foregroundStyle(colors.primary)
                VStack {
                    HStack {
                        Spacer()
                        if showFreeBadge {
                            Text("Free")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Capsule().fill(.white))
                        } else if locked {
                            Image(systemName: "lock.fill").font(.caption).foregroundStyle(colors.secondary)
                        }
                    }
                    Spacer()
                    if selected {
                        Text(theme == .custom ? "Edit" : "Selected")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(.white))
                    }
                }
                .padding(10)
            }
            .aspectRatio(0.68, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(selected ? Palette.teal : Color.white.opacity(0.1), lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.title) theme\(locked ? ", Pro" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "Create": pick a background colour and a typeface, with a live preview.
struct CustomThemeEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CustomFeedTheme()
    @State private var color = Color(hex: 0x2F3A4A)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    Text("Background").font(.headline).foregroundStyle(Palette.textPrimary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(CustomFeedTheme.swatches, id: \.self) { hex in
                            Button { draft.background = hex; color = Color(hex: UInt32(hex)) } label: {
                                Circle().fill(Color(hex: UInt32(hex)))
                                    .frame(height: 48)
                                    .overlay(Circle().strokeBorder(draft.background == hex ? Palette.teal : Color.white.opacity(0.15),
                                                                   lineWidth: draft.background == hex ? 3 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(format: "Colour #%06lX", hex))
                        }
                    }
                    ColorPicker("Any colour", selection: $color, supportsOpacity: false)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Font").font(.headline).foregroundStyle(Palette.textPrimary)
                    FlowLayout(spacing: 8) {
                        ForEach(FeedFont.allCases) { font in
                            Button { draft.font = font } label: {
                                Chip(font.title, isSelected: draft.font == font)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.charcoal.ignoresSafeArea())
            .navigationTitle("Create theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isPro ? "Save" : "Unlock") {
                        model.setCustomTheme(draft)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                if let saved = model.preferences.customTheme {
                    draft = saved
                    color = Color(hex: UInt32(saved.background))
                }
            }
            .onChange(of: color) { _, newColor in
                if let hex = newColor.rgbHex, hex != draft.background { draft.background = hex }
            }
        }
        .presentationBackground(Palette.charcoal)
    }

    private var preview: some View {
        let colors = FeedColors.forTheme(.custom, custom: draft)
        return ZStack {
            FeedBackground(theme: .custom, custom: draft)
            VStack(spacing: 10) {
                Text("embedding").font(colors.font.display(size: 40)).foregroundStyle(colors.primary)
                Text("(n.) A list of numbers that captures what a piece of text means.")
                    .font(.definition)
                    .foregroundStyle(colors.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.easeInOut, value: draft)
    }
}

private extension Color {
    /// 0xRRGGBB from a resolved colour.
    var rgbHex: Int? {
        let resolved = resolve(in: EnvironmentValues())
        func byte(_ value: Float) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return byte(resolved.red) << 16 | byte(resolved.green) << 8 | byte(resolved.blue)
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
