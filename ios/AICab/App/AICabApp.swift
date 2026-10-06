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
    @MainActor private var pending: [(link: DeepLink, save: Bool)] = []

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
        let save = response.actionIdentifier == UserNotificationScheduler.saveAction
        await MainActor.run {
            pending.append((link, save))
            flushPending()
        }
    }

    @MainActor private func flushPending() {
        guard let model else { return }
        for item in pending {
            if item.save, case .term(let id) = item.link, let term = model.term(id) {
                if !model.isSaved(id) { model.toggleSave(term) }
            } else {
                model.handle(item.link)
            }
        }
        pending.removeAll()
    }
}
