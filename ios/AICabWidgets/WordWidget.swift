import SwiftUI
import WidgetKit
import AppIntents
import AICabCore
import AICabDesign

struct WordEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord
    let isSaved: Bool
    let snapshot: WidgetSnapshot
    let theme: WidgetTheme
    let showExample: Bool
}

/// Rotates through the snapshot hourly. The cursor (advanced by "Next") offsets the rotation.
struct WordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        makeEntry(snapshot: .placeholder, cursor: 0, date: .now, config: WordWidgetIntent())
    }

    func snapshot(for configuration: WordWidgetIntent, in context: Context) async -> WordEntry {
        let store = WidgetStore()
        return makeEntry(snapshot: store.snapshot() ?? .placeholder, cursor: store.cursor(), date: .now, config: configuration)
    }

    func timeline(for configuration: WordWidgetIntent, in context: Context) async -> Timeline<WordEntry> {
        let store = WidgetStore()
        let snapshot = store.snapshot() ?? .placeholder
        let cursor = store.cursor()
        let calendar = Calendar.current
        let now = Date()
        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let entries = (0..<12).map { offset -> WordEntry in
            let date = offset == 0 ? now : calendar.date(byAdding: .hour, value: offset, to: hourStart) ?? now
            return makeEntry(snapshot: snapshot, cursor: cursor, date: date, config: configuration)
        }
        return Timeline(entries: entries, policy: .after(entries.last?.date ?? now.addingTimeInterval(3600)))
    }

    private func makeEntry(snapshot: WidgetSnapshot, cursor: Int, date: Date, config: WordWidgetIntent) -> WordEntry {
        let hours = max(Int(date.timeIntervalSince(snapshot.generatedAt) / 3600), 0)
        let word = WidgetStore.word(in: snapshot, at: cursor + hours) ?? WidgetSnapshot.placeholder.words[0]
        return WordEntry(date: date, word: word, isSaved: snapshot.savedIds.contains(word.id), snapshot: snapshot,
                         theme: config.theme, showExample: config.showExample)
    }
}

struct WordWidget: Widget {
    let kind = "AICabWordWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WordWidgetIntent.self, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Word of the hour")
        .description("A new AI word every hour. Save it with one tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

private struct ThemeColors {
    let background: Color
    let primary: Color
    let secondary: Color

    init(_ theme: WidgetTheme) {
        switch theme {
        case .paper:
            background = Palette.paper
            primary = Palette.ink
            secondary = Palette.inkSoft
        case .night:
            background = Palette.charcoal
            primary = Palette.textPrimary
            secondary = Palette.textSecondary
        case .teal:
            background = Palette.teal
            primary = Palette.ink
            secondary = Palette.ink.opacity(0.7)
        }
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private var colors: ThemeColors { ThemeColors(entry.theme) }
    private var word: WidgetWord { entry.word }

    var body: some View {
        content
            .widgetURL(URL(string: "aicab://term/\(word.id)"))
            .containerBackground(for: .widget) {
                if family.isAccessory {
                    AccessoryWidgetBackground().opacity(family == .accessoryRectangular ? 0 : 1)
                } else {
                    colors.background
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text("\(word.term): \(word.definition)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(word.term)
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .widgetAccentable()
                Text(word.definition)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryCircular:
            Gauge(value: Double(min(entry.snapshot.savedToday(on: entry.date), entry.snapshot.dailyGoal)),
                  in: 0...Double(max(entry.snapshot.dailyGoal, 1))) {
                Image(systemName: "bookmark.fill")
            } currentValueLabel: {
                Text("\(entry.snapshot.savedToday(on: entry.date))")
            }
            .gaugeStyle(.accessoryCircular)
        case .systemSmall:
            small
        case .systemLarge:
            large
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                AppMark(size: 22)
                Spacer()
                saveButton(size: 30)
            }
            Spacer(minLength: 0)
            Text(word.term)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .foregroundStyle(colors.primary)
            Text("(\(word.pos)) \(word.definition)")
                .font(.system(size: 12))
                .lineLimit(3)
                .foregroundStyle(colors.secondary)
        }
        .padding(14)
    }

    private var medium: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Text(word.term)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(colors.primary)
                Text("(\(word.pos)) \(word.definition)")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .lineLimit(entry.showExample ? 2 : 3)
                    .foregroundStyle(colors.primary)
                if entry.showExample, let example = word.example {
                    Text(example)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .foregroundStyle(colors.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 4) {
                saveButton(size: 28)
                nextButton(size: 28)
            }
            .padding(10)
        }
    }

    private var large: some View {
        let saved = entry.snapshot.savedToday(on: entry.date)
        let goal = max(entry.snapshot.dailyGoal, 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppMark(size: 26)
                Text("Word of the hour").font(.caption.weight(.semibold)).foregroundStyle(colors.secondary)
                Spacer()
                Label("\(entry.snapshot.streak)", systemImage: "flame.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.coral)
            }
            Spacer(minLength: 0)
            Text(word.term)
                .font(.system(size: 36, weight: .bold, design: .serif))
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .foregroundStyle(colors.primary)
            if let ipa = word.ipa {
                Text(ipa).font(.subheadline).foregroundStyle(colors.secondary)
            }
            Text("(\(word.pos)) \(word.definition)")
                .font(.system(size: 17))
                .foregroundStyle(colors.primary)
                .lineLimit(4)
            if entry.showExample, let example = word.example {
                Text("\u{201C}\(example)\u{201D}")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundStyle(colors.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(min(saved, goal))/\(goal) saved today").font(.caption.weight(.semibold)).foregroundStyle(colors.secondary)
                    ProgressView(value: Double(min(saved, goal)), total: Double(goal)).tint(Palette.tealDeep)
                }
                Spacer()
                saveButton(size: 36)
                nextButton(size: 36)
            }
        }
        .padding(18)
    }

    private func saveButton(size: CGFloat) -> some View {
        Button(intent: ToggleSaveWordIntent(termID: word.id)) {
            Image(systemName: entry.isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(entry.isSaved ? Palette.tealDeep : colors.primary)
                .frame(width: size, height: size)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.isSaved ? "Remove from deck" : "Save to deck")
    }

    private func nextButton(size: CGFloat) -> some View {
        Button(intent: NextWordIntent()) {
            Image(systemName: "arrow.forward")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(colors.primary)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Next word")
    }
}

extension WidgetFamily {
    var isAccessory: Bool {
        self == .accessoryInline || self == .accessoryRectangular || self == .accessoryCircular
    }
}
