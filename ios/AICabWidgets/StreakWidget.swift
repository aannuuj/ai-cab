import SwiftUI
import WidgetKit
import AICabCore
import AICabDesign

struct StreakEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: .now, snapshot: WidgetStore().snapshot() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let snapshot = WidgetStore().snapshot() ?? .placeholder
        let now = Date()
        // Refresh just after midnight so "today" resets.
        let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600 * 6)
        completion(Timeline(entries: [StreakEntry(date: now, snapshot: snapshot), StreakEntry(date: midnight, snapshot: snapshot)],
                            policy: .after(midnight)))
    }
}

struct StreakWidget: Widget {
    let kind = "AICabStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak & goal")
        .description("Your streak and today's progress toward your word goal.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    private var saved: Int { entry.snapshot.savedToday(on: entry.date) }
    private var goal: Int { max(entry.snapshot.dailyGoal, 1) }
    private var streak: Int { entry.snapshot.streak }

    var body: some View {
        Group {
            if family == .accessoryCircular {
                Gauge(value: Double(min(saved, goal)), in: 0...Double(goal)) {
                    Image(systemName: "flame.fill")
                } currentValueLabel: {
                    Text("\(streak)")
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.title)
                            .foregroundStyle(LinearGradient(colors: [Palette.gold, Palette.coral], startPoint: .top, endPoint: .bottom))
                        Spacer()
                        AppMark(size: 22)
                    }
                    Spacer(minLength: 0)
                    Text("\(streak)")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.textPrimary)
                    Text("day streak")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                    ProgressView(value: Double(min(saved, goal)), total: Double(goal))
                        .tint(saved >= goal ? Palette.lime : Palette.teal)
                    Text(saved >= goal ? "Goal done today" : "\(goal - saved) to go today")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(2)
            }
        }
        .widgetURL(URL(string: "aicab://words"))
        .containerBackground(for: .widget) {
            if family == .accessoryCircular { AccessoryWidgetBackground() } else { Palette.charcoal }
        }
    }
}
