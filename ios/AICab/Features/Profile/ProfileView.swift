import SwiftUI
import StoreKit
import AVFoundation
import AICabCore
import AICabDesign

enum ProfileRoute: Hashable {
    case stats, reminders, voices, themes, appIcon, alarm
    case widgets(lockScreen: Bool)
}

/// "You": progress at a glance, then grouped settings rows.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var editingTopics = false
    @State private var takingTest = false
    @State private var managingSubscription = false
    @State private var path = NavigationPath(ProfileView.screenshotPath)

    private static var screenshotPath: [ProfileRoute] {
        switch ScreenshotMode.current {
        case .voices: [.voices]
        case .gallery: [.themes]
        case .stats: [.stats]
        default: []
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !model.isPro {
                        UnlockBanner { model.sheet = .paywall(.settings) }
                    }
                    NavigationLink(value: ProfileRoute.stats) {
                        StreakCard(streak: model.streak, days: model.week)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens your stats")

                    SettingsGroup {
                        SettingsRow("Level check", symbol: "graduationcap.fill", tint: Palette.teal, detail: model.level.title) {
                            takingTest = true
                        }
                    }

                    personalizeGroup

                    trackGroup

                    learningGroup

                    libraryGroup

                    membershipGroup

                    aboutGroup

                    Text("AI-Cab \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") · content v\(model.content.version)")
                        .font(.footnote)
                        .foregroundStyle(Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Palette.charcoal.ignoresSafeArea())
            .navigationTitle(model.preferences.name.map { "Hi, \($0)" } ?? "You")
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .stats: StatsView()
                case .reminders: RemindersScreen()
                case .voices: VoicesView()
                case .themes: ThemesView()
                case .appIcon: AppIconView()
                case .alarm: AlarmView()
                case .widgets(let lockScreen):
                    WidgetInstallView(mode: .settings, startOnLockScreen: lockScreen)
                        .navigationTitle(lockScreen ? "Lock Screen widget" : "Home Screen widget")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .navigationDestination(for: LibraryRoute.self) { LibraryDestination(route: $0) }
            .navigationDestination(for: String.self) { TermDetailView(termID: $0) }
            .sheet(isPresented: $editingTopics) { TopicPickerSheet() }
            .fullScreenCover(isPresented: $takingTest) {
                NavigationStack { LevelTestView() }
            }
            .manageSubscriptionsSheet(isPresented: $managingSubscription)
        }
    }

    private var personalizeGroup: some View {
        SettingsGroup("Make it yours") {
            SettingsLink("Themes", symbol: "paintpalette.fill", tint: Palette.coral,
                         detail: model.preferences.feedTheme.title, value: ProfileRoute.themes)
            RowDivider()
            SettingsLink("App icon", symbol: "app.gift.fill", tint: Palette.oliveSoft,
                         detail: AppIconOption.all.first { $0.iconName == model.preferences.appIcon }?.title ?? "Classic",
                         value: ProfileRoute.appIcon)
            RowDivider()
            SettingsLink("Voices", symbol: "speaker.wave.2.fill", tint: Palette.teal, detail: voiceName, value: ProfileRoute.voices)
        }
    }

    private var trackGroup: some View {
        SettingsGroup("Stay on track") {
            SettingsLink("Reminders", symbol: "bell.fill", tint: Palette.gold,
                         detail: model.preferences.reminders.isEnabled ? "\(model.preferences.reminders.perDay)x a day" : "Off",
                         value: ProfileRoute.reminders)
            if PracticeAlarm.isSupported {
                RowDivider()
                SettingsLink("Alarm", symbol: "alarm.fill", tint: Palette.coral, detail: alarmDetail, value: ProfileRoute.alarm)
            }
            RowDivider()
            SettingsLink("Home Screen widget", symbol: "apps.iphone", tint: Palette.teal, value: ProfileRoute.widgets(lockScreen: false))
            RowDivider()
            SettingsLink("Lock Screen widget", symbol: "lock.iphone", tint: Palette.cream, value: ProfileRoute.widgets(lockScreen: true))
        }
    }

    private var learningGroup: some View {
        SettingsGroup("Learning") {
            Menu {
                Picker("Definition depth", selection: Binding(get: { model.preferences.level }, set: { model.setLevel($0) })) {
                    ForEach(Level.allCases) { level in
                        Text(level.isPremium && !model.isPro ? "\(level.title) (Pro)" : level.title).tag(level)
                    }
                }
            } label: {
                SettingsRowLabel("Definition depth", symbol: "dial.medium", tint: Palette.teal, detail: model.level.title, accessory: "chevron.up.chevron.down")
            }
            RowDivider()
            HStack {
                SettingsRowLabel("Daily goal", symbol: "target", tint: Palette.coral, detail: nil, accessory: nil)
                Stepper("\(model.dailyGoal) terms", value: Binding(get: { model.dailyGoal }, set: { model.setDailyGoal($0) }),
                        in: Preferences.dailyGoalRange)
                    .fixedSize()
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.trailing, 14)
            }
            RowDivider()
            SettingsRow("Feed topics", symbol: "square.stack.3d.up.fill", tint: Palette.gold,
                        detail: model.preferences.topicIds.isEmpty ? "All" : "\(model.preferences.topicIds.count)") {
                editingTopics = true
            }
        }
    }

    private var libraryGroup: some View {
        SettingsGroup("Library") {
            SettingsLink("Your deck", symbol: "bookmark.fill", tint: Palette.teal, detail: "\(model.state.learnedCount)", value: LibraryRoute.saved)
            RowDivider()
            SettingsLink("Hearted", symbol: "heart.fill", tint: Palette.coral, detail: "\(model.favorites.count)", value: LibraryRoute.favorites)
            RowDivider()
            SettingsLink("Recently read", symbol: "clock.fill", tint: Palette.gold, detail: "\(model.history.count)", value: LibraryRoute.history)
            RowDivider()
            SettingsLink("Collections", symbol: "folder.fill", tint: Palette.oliveSoft, detail: "\(model.state.collections.count)", value: LibraryRoute.collections)
        }
    }

    private var membershipGroup: some View {
        SettingsGroup("Membership") {
            if model.isPro {
                SettingsRowLabel("AI-Cab Pro is active", symbol: "crown.fill", tint: Palette.gold, detail: nil, accessory: nil)
                if let trialEnd = model.purchases.trialEndDate {
                    RowDivider()
                    Toggle(isOn: Binding(get: { model.preferences.trialReminderEnabled },
                                         set: { value in
                                             model.setTrialReminder(value)
                                             Task { await model.rescheduleNotifications() }
                                         })) {
                        SettingsRowLabel("Remind me before the trial ends", symbol: "calendar.badge.clock", tint: Palette.teal,
                                         detail: trialEnd.formatted(date: .abbreviated, time: .omitted), accessory: nil)
                    }
                    .tint(Palette.teal)
                    .padding(.trailing, 14)
                }
                RowDivider()
                SettingsRow("Manage subscription", symbol: "creditcard.fill", tint: Palette.textSecondary) { managingSubscription = true }
            } else {
                SettingsRow("See AI-Cab Pro", symbol: "crown.fill", tint: Palette.gold) { model.sheet = .paywall(.settings) }
            }
            RowDivider()
            SettingsRow("Restore purchases", symbol: "arrow.clockwise", tint: Palette.textSecondary) {
                Task { await model.purchases.restore() }
            }
        }
    }

    private var aboutGroup: some View {
        SettingsGroup("AI-Cab") {
            SettingsRow("Send feedback", symbol: "bubble.left.fill", tint: Palette.teal) { model.sheet = .feedback }
            RowDivider()
            SettingsRow("Rate AI-Cab", symbol: "star.fill", tint: Palette.gold) { requestReview() }
            if let id = model.config.appStoreID, let url = URL(string: "https://apps.apple.com/app/id\(id)") {
                RowDivider()
                ShareLink(item: url, message: Text("I'm learning the language of AI with AI-Cab")) {
                    SettingsRowLabel("Share AI-Cab", symbol: "square.and.arrow.up.fill", tint: Palette.coral, detail: nil, accessory: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            RowDivider()
            SettingsRow("Privacy policy", symbol: "hand.raised.fill", tint: Palette.textSecondary) { openURL(model.config.privacyURL) }
            RowDivider()
            SettingsRow("Terms of use", symbol: "doc.text.fill", tint: Palette.textSecondary) { openURL(model.config.termsURL) }
        }
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

// MARK: - Grouped rows

/// Rounded card holding a column of rows, with an optional caption above.
struct SettingsGroup<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.footnote.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.leading, 6)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.outline).offset(y: Metrics.hardShadow))
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1).padding(.leading, 62)
    }
}

/// Icon chip, title, optional detail and accessory.
struct SettingsRowLabel: View {
    let title: String
    let symbol: String
    let tint: Color
    let detail: String?
    let accessory: String?

    init(_ title: String, symbol: String, tint: Color, detail: String?, accessory: String?) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.detail = detail
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint))
            Text(title)
                .font(.body)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            if let detail {
                Text(detail).foregroundStyle(Palette.textSecondary).lineLimit(1)
            }
            if let accessory {
                Image(systemName: accessory).font(.footnote.weight(.semibold)).foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

struct SettingsRow: View {
    let title: String
    let symbol: String
    let tint: Color
    var detail: String?
    let action: () -> Void

    init(_ title: String, symbol: String, tint: Color, detail: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.detail = detail
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(title, symbol: symbol, tint: tint, detail: detail, accessory: "chevron.right")
        }
        .buttonStyle(RowPressStyle())
    }
}

struct SettingsLink<Value: Hashable>: View {
    let title: String
    let symbol: String
    let tint: Color
    var detail: String?
    let value: Value

    init(_ title: String, symbol: String, tint: Color, detail: String? = nil, value: Value) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.detail = detail
        self.value = value
    }

    var body: some View {
        NavigationLink(value: value) {
            SettingsRowLabel(title, symbol: symbol, tint: tint, detail: detail, accessory: "chevron.right")
        }
        .buttonStyle(RowPressStyle())
    }
}

private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.06 : 0))
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
                    stat("\(model.challengeBest(.blitz))", "Blitz best", "stopwatch.fill")
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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !model.isPro {
                    UnlockBanner(title: "Every theme with Pro", message: "Scenes, typefaces and your own colours for the Today feed.") {
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
                Button { creating = true } label: { Chip("New", systemImage: "plus") }
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
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    FeedBackground(theme: theme, custom: custom)
                    VStack(spacing: 6) {
                        Text("agent")
                            .font(colors.font.display(size: 30))
                            .foregroundStyle(colors.primary)
                        Capsule().fill(colors.secondary.opacity(0.5)).frame(width: 64, height: 4)
                        Capsule().fill(colors.secondary.opacity(0.35)).frame(width: 44, height: 4)
                    }
                    VStack {
                        HStack {
                            Spacer()
                            if showFreeBadge {
                                Text("FREE")
                                    .font(.caption2.weight(.heavy))
                                    .tracking(1)
                                    .foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(Palette.teal))
                            } else if locked {
                                Image(systemName: "lock.fill").font(.caption).foregroundStyle(colors.secondary)
                            }
                        }
                        Spacer()
                        if selected && theme == .custom {
                            Label("Edit", systemImage: "slider.horizontal.3")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(Palette.teal))
                        }
                    }
                    .padding(10)
                }
                .aspectRatio(0.82, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? Palette.teal : Palette.outline, lineWidth: selected ? 3 : 2))
                HStack(spacing: 6) {
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.teal) }
                    Text(theme.title)
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
            }
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
