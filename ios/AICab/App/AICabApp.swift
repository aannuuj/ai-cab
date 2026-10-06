import SwiftUI
import UserNotifications
import AICabCore

@main
struct AICabApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.live()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    appDelegate.model = model
                    await model.start()
                }
                .onOpenURL { model.handle($0) }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: Task { await model.sceneDidBecomeActive() }
                    case .background: Task { await model.sceneDidEnterBackground() }
                    default: break
                    }
                }
        }
    }
}

/// Routes notification taps and the "Save word" action into the app model.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor weak var model: AppModel? {
        didSet { flushPending() }
    }
    @MainActor private var pending: [DeepLink] = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let string = info["deepLink"] as? String, let url = URL(string: string), let link = DeepLink(url: url) else { return }
        if response.actionIdentifier == UserNotificationScheduler.saveAction, case .term(let id) = link {
            // Persist first, so the save survives even if no UI scene ever connects.
            WidgetStore().enqueue(WidgetInboxItem(termId: id, action: .save, date: Date()))
            await MainActor.run { model?.applyExternalSaves() }
            return
        }
        await MainActor.run {
            pending.append(link)
            flushPending()
        }
    }

    @MainActor private func flushPending() {
        guard let model else { return }
        for link in pending { model.handle(link) }
        pending.removeAll()
    }
}
