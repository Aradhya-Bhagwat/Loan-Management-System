import Foundation
import Observation
import UserNotifications

@Observable
class NotificationService {
    static let shared = NotificationService()

    var notifications: [LoanOfficerNotification] = []
    var isLoading = false
    private var officerId: UUID?
    private let db = DatabaseService.shared

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    // MARK: - Setup

    /// Call once when the officer logs in / dashboard appears
    func configure(officerId: UUID) {
        guard self.officerId != officerId else { return }
        self.officerId = officerId
        
        requestPermissions()
        Task { await loadNotifications() }
        startRealtimeSubscription()
    }

    private func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else if let error = error {
                print("Notification permissions error: \(error)")
            }
        }
        
        // Allow notifications to show even when app is in foreground
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    // MARK: - Load

    func loadNotifications() async {
        guard let officerId else { return }
        await MainActor.run { isLoading = true }

        do {
            let dbNotifs = try await db.fetchOfficerNotifications(userId: officerId)
            let mapped = dbNotifs.map { LoanOfficerNotification(from: $0) }
            await MainActor.run {
                self.notifications = mapped
                self.isLoading = false
            }
        } catch {
            print("Error loading notifications: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }

    // MARK: - Actions

    func markAsRead(_ notificationId: UUID) {
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].isRead = true
        }
        Task {
            do {
                try await db.markNotificationRead(id: notificationId)
            } catch {
                print("Error marking notification read: \(error)")
            }
        }
    }

    func markAllRead() {
        guard let officerId else { return }
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        Task {
            do {
                try await db.markAllNotificationsRead(userId: officerId)
            } catch {
                print("Error marking all notifications read: \(error)")
            }
        }
    }

    func deleteNotification(_ notificationId: UUID) {
        notifications.removeAll { $0.id == notificationId }
        Task {
            do {
                try await db.deleteNotification(id: notificationId)
            } catch {
                print("Error deleting notification: \(error)")
            }
        }
    }

    func deleteAllNotifications() {
        guard let officerId else { return }
        notifications.removeAll()
        Task {
            do {
                try await db.deleteAllNotifications(userId: officerId)
            } catch {
                print("Error deleting all notifications: \(error)")
            }
        }
    }

    // MARK: - Realtime

    private func startRealtimeSubscription() {
        guard let officerId else { return }
        db.subscribeToNotifications(userId: officerId) { [weak self] dbNotif in
            Task { @MainActor in
                guard let self else { return }
                let notif = LoanOfficerNotification(from: dbNotif)
                // Insert at the top (newest first)
                if !self.notifications.contains(where: { $0.id == notif.id }) {
                    self.notifications.insert(notif, at: 0)
                    self.showLocalBanner(for: notif)
                }
            }
        }
    }

    private func showLocalBanner(for notification: LoanOfficerNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.subtitle
        content.sound = .default

        // Add metadata for deep linking if needed
        if let appId = notification.applicationId {
            content.userInfo = ["application_id": appId.uuidString]
        }

        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    func disconnect() {
        db.unsubscribeFromNotifications()
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner and play sound even if app is in foreground
        completionHandler([.banner, .list, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap (e.g. deep link to a specific loan)
        let userInfo = response.notification.request.content.userInfo
        if let appIdString = userInfo["application_id"] as? String,
           let appId = UUID(uuidString: appIdString) {
            print("User tapped notification for app: \(appId)")
            // Future: Trigger navigation via AppRouter
        }
        completionHandler()
    }
}
