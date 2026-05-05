import Foundation
import UserNotifications
import Supabase
import Observation

@Observable
final class ChatNotificationMonitor {
    static let shared = ChatNotificationMonitor()
    private var monitorTask: Task<Void, Never>?
    private var activeChannel: RealtimeChannelV2?
    var currentlyViewedApplicationId: UUID?

    private var seenIds: Set<UUID> = []
    private var myApplicationIds: Set<UUID> = []

    private init() {}

    func start() async {

        monitorTask?.cancel()
        monitorTask = nil

        if let old = activeChannel {
            await SupabaseManager.shared.client.removeChannel(old)
            activeChannel = nil
        }

        monitorTask = Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                let borrowerId = session.user.id

                let apps = try await SupabaseManager.shared.fetchMyApplications()
                guard !apps.isEmpty else {
                    print("ℹ️ [ChatMonitor] No apps found to watch.")
                    return
                }

                self.myApplicationIds = Set(apps.compactMap { $0.id })
                let appIdStrings = myApplicationIds.map { $0.uuidString }

                let existing = try await SupabaseManager.shared.client
                    .from("chat_messages")
                    .select("id")
                    .in("application_id", values: appIdStrings)
                    .execute()
                    .value as [[String: String]]

                var initialSeen: Set<UUID> = []
                for row in existing {
                    if let idStr = row["id"], let uuid = UUID(uuidString: idStr) {
                        initialSeen.insert(uuid)
                    }
                }
                self.seenIds = initialSeen

                print("✅ [ChatMonitor] Started — watching \(apps.count) apps, seeded \(seenIds.count) messages")

                let channelName = "global_chat_updates_\(UUID().uuidString.prefix(8))"
                let channel = SupabaseManager.shared.client.channel(channelName)

                let stream = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "chat_messages"
                )

                try await channel.subscribeWithError()
                self.activeChannel = channel
                print("✅ [ChatMonitor] Subscribed on channel: \(channelName)")

                for await insertion in stream {
                    guard !Task.isCancelled else { break }

                    do {
                        let msg = try insertion.decodeRecord(as: DBChatMessage.self, decoder: AnyJSON.decoder)

                        guard myApplicationIds.contains(msg.applicationId) else { continue }

                        guard msg.senderId != borrowerId else { continue }

                        guard !seenIds.contains(msg.id) else { continue }

                        seenIds.insert(msg.id)

                        if msg.applicationId != self.currentlyViewedApplicationId {
                            fireNotification(body: msg.content, applicationId: msg.applicationId)

                            try? await SupabaseManager.shared.sendNotification(
                                title: "New Message from Loan Officer",
                                message: msg.content.count > 200 ? String(msg.content.prefix(200)) + "…" : msg.content,
                                type: "chat",
                                metadata: ["application_id": msg.applicationId.uuidString]
                            )
                        }
                    } catch {
                        print("❌ [ChatMonitor] Error processing message: \(error)")
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    print("❌ [ChatMonitor] Monitor failed: \(error)")
                }
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        Task {
            if let ch = activeChannel {
                await SupabaseManager.shared.client.removeChannel(ch)
                activeChannel = nil
            }
        }
    }

    private func fireNotification(body: String, applicationId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "New Message from Loan Officer"
        content.body = body.count > 100 ? String(body.prefix(100)) + "…" : body
        content.sound = .default
        content.userInfo = [
            "type": "chat_message",
            "application_id": applicationId.uuidString
        ]

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("❌ [ChatMonitor] iOS Notification error: \(error)") }
            else { print("✅ [ChatMonitor] iOS Notification fired for app: \(applicationId.uuidString.prefix(8))") }
        }
    }
}
