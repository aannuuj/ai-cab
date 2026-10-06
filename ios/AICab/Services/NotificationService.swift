import Foundation
import UserNotifications
import AICabCore

enum NotificationAuthorization: Equatable {
    case notDetermined, denied, authorized
}

/// Abstraction over the system scheduler so `AppModel` stays testable.
protocol NotificationScheduling: Sendable {
    func authorization() async -> NotificationAuthorization
    func requestAuthorization() async -> Bool
    func replacePending(with plan: [PlannedNotification]) async
}

struct UserNotificationScheduler: NotificationScheduling {
    static let wordCategory = "WORD"
    static let saveAction = "SAVE_WORD"

    private var center: UNUserNotificationCenter { .current() }

    static func registerCategories() {
        let save = UNNotificationAction(identifier: saveAction, title: "Save word", options: [],
                                        icon: UNNotificationActionIcon(systemImageName: "bookmark"))
        let category = UNNotificationCategory(identifier: wordCategory, actions: [save], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func authorization() async -> NotificationAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .authorized
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func replacePending(with plan: [PlannedNotification]) async {
        center.removeAllPendingNotificationRequests()
        let calendar = Calendar.current
        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = item.kind == .word ? nil : .default
            content.userInfo = ["deepLink": item.deepLink, "termId": item.termId ?? ""]
            content.threadIdentifier = item.kind.rawValue
            if item.kind == .word {
                content.categoryIdentifier = Self.wordCategory
                content.interruptionLevel = .passive
                content.relevanceScore = 0.4
            }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}
