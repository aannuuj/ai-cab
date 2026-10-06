import Foundation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Daily "time to practice" alarm via AlarmKit (iOS 26+). Unlike a notification it rings through
/// Silent mode and Focus, so it is opt-in and lives behind its own permission.
enum PracticeAlarm {
    /// One stable id so rescheduling replaces the previous alarm.
    static let id = UUID(uuidString: "6A1C0B1E-0000-4000-8000-A1CAB0000001")!

    static var isSupported: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// Schedules (or replaces) a repeating daily alarm. Returns false if unsupported or not allowed.
    static func schedule(minute: Int, name: String?) async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return await AlarmKitScheduler.schedule(minute: minute, name: name, id: id)
        }
        #endif
        return false
    }

    static func cancel() async {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            AlarmKitScheduler.cancel(id: id)
        }
        #endif
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private enum AlarmKitScheduler {
    struct Metadata: AlarmMetadata {}

    static func schedule(minute: Int, name: String?, id: UUID) async -> Bool {
        let manager = AlarmManager.shared
        do {
            if manager.authorizationState != .authorized {
                guard try await manager.requestAuthorization() == .authorized else { return false }
            }
            let title: LocalizedStringResource
            if let name {
                title = "\(name), time for today's AI words"
            } else {
                title = "Time for today's AI words"
            }
            let stop = AlarmButton(text: "Done", textColor: .white, systemImageName: "checkmark")
            let alert = AlarmPresentation.Alert(title: title, stopButton: stop)
            let attributes = AlarmAttributes<Metadata>(presentation: AlarmPresentation(alert: alert),
                                                       metadata: Metadata(),
                                                       tintColor: Color(red: 0.56, green: 0.76, blue: 0.75))
            let time = Alarm.Schedule.Relative.Time(hour: minute / 60, minute: minute % 60)
            let everyDay: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
            let schedule = Alarm.Schedule.relative(.init(time: time, repeats: .weekly(everyDay)))
            try? manager.cancel(id: id)
            _ = try await manager.schedule(id: id, configuration: .alarm(schedule: schedule, attributes: attributes))
            return true
        } catch {
            return false
        }
    }

    static func cancel(id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }
}
#endif
