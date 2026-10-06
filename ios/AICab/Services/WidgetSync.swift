import Foundation
import WidgetKit
import AICabCore

/// Publishes the widget snapshot and asks WidgetKit to refresh.
protocol WidgetSyncing: Sendable {
    func publish(_ snapshot: WidgetSnapshot)
    func drainInbox() -> [WidgetInboxItem]
    func enqueue(_ item: WidgetInboxItem)
    func installedWidgetCount() async -> Int
}

struct WidgetKitSync: WidgetSyncing {
    let store: WidgetStore

    func publish(_ snapshot: WidgetSnapshot) {
        try? store.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func drainInbox() -> [WidgetInboxItem] {
        store.drainInbox()
    }

    func enqueue(_ item: WidgetInboxItem) {
        store.enqueue(item)
    }

    func installedWidgetCount() async -> Int {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                continuation.resume(returning: (try? result.get())?.count ?? 0)
            }
        }
    }
}
