

import SwiftUI
import Auth
import Supabase
import AppIntents

@main
struct Team6LMSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authManager = AuthManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appLanguage") private var appLanguage = "en"

    init() {
        LMSShortcutsProvider.updateAppShortcutParameters()
        print("✅ [Siri] AppShortcutParameters updated — shortcuts registered with system.")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(\.locale, Locale(identifier: appLanguage))
                .onOpenURL { url in
                    print("🔗 [App] Received URL: \(url.absoluteString)")
                    Task {
                        await authManager.handleDeepLink(url: url)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        print("📱 App became active — refreshing session & monitor")
                        NotificationManager.shared.checkAuthorization()
                        Task {
                            await ChatNotificationMonitor.shared.start()
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            await authManager.checkSession()
                        }
                    }
                }
                .task {
                    NotificationManager.shared.requestAuthorization()
                }

        }
    }
}
