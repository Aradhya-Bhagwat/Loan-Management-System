import SwiftUI
import UserNotifications

@Observable
class BorrowerChatController {
    let applicationId: UUID
    let borrowerId: UUID
    let officerId: UUID
    let officerName: String

    var messages: [ChatMessage] = []
    var newMessageText: String = ""
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    var uploadedDocStatuses: [DocumentRequestType: String] = [:] 
    var isUploading = false
    var uploadErrorMessage: String?

    private let db = SupabaseManager.shared

    init(applicationId: UUID, borrowerId: UUID, officerId: UUID, officerName: String) {
        self.applicationId = applicationId
        self.borrowerId = borrowerId
        self.officerId = officerId
        self.officerName = officerName
        ChatNotificationMonitor.shared.currentlyViewedApplicationId = applicationId
        print("💬 BorrowerChatController init — appId=\(applicationId.uuidString.prefix(8)) borrowerId=\(borrowerId.uuidString.prefix(8)) officerId=\(officerId.uuidString.prefix(8))")
    }

    var officerInitials: String {
        officerName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }

    func loadMessages() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let dbMessages = try await db.fetchMessages(applicationId: applicationId)
            print("💬 fetchMessages: got \(dbMessages.count) messages for applicationId=\(applicationId.uuidString.prefix(8))")
            for msg in dbMessages {
                print("   msg id=\(msg.id.uuidString.prefix(8)) sender=\(msg.senderId.uuidString.prefix(8)) type=\(msg.messageType.rawValue)")
            }
            let chatMessages = dbMessages.map { ChatMessage(from: $0, currentUserId: borrowerId, officerId: officerId) }
            await MainActor.run {
                self.messages = chatMessages
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load messages"
                self.isLoading = false
            }
            print("❌ Error loading messages: \(error)")
        }

        await checkExistingDocuments()

        await db.subscribeToMessages(applicationId: applicationId, subscriberId: "chat_view") { [weak self] dbMsg in
            Task { @MainActor in
                guard let self else { return }
                let msg = ChatMessage(from: dbMsg, currentUserId: self.borrowerId, officerId: self.officerId)
                print("📨 Realtime message received — sender: \(dbMsg.senderId), isFromOfficer: \(msg.isFromOfficer)")
                if !self.messages.contains(where: { $0.id == msg.id }) {
                    self.messages.append(msg)
                    if msg.isFromOfficer {
                        self.scheduleLocalNotification(from: self.officerName, body: msg.content)
                    }
                }
            }
        }
    }

    func sendTextMessage() async {
        let text = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        await MainActor.run {
            isSending = true
            newMessageText = ""
        }

        do {
            let saved = try await db.sendMessage(
                applicationId: applicationId,
                senderId: borrowerId,
                content: text,
                messageType: .text,
                documentType: nil
            )
            let msg = ChatMessage(from: saved, currentUserId: borrowerId, officerId: officerId)
            await MainActor.run {
                if !self.messages.contains(where: { $0.id == msg.id }) {
                    self.messages.append(msg)
                }
                self.isSending = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to send message"
                self.isSending = false
            }
            print("Error sending message: \(error)")
        }
    }

    func disconnect() {
        let appId = applicationId
        let database = db
        Task {
            await database.unsubscribeFromMessages(applicationId: appId, subscriberId: "chat_view")
        }
        ChatNotificationMonitor.shared.currentlyViewedApplicationId = nil
    }

    // MARK: - Local Notification
    private func scheduleLocalNotification(from sender: String, body: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Notification auth status: \(settings.authorizationStatus.rawValue)")
            guard settings.authorizationStatus == .authorized else {
                print("❌ Notifications not authorized — requesting again")
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = sender
            content.body = body.count > 100 ? String(body.prefix(100)) + "…" : body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("❌ Failed to schedule notification: \(error)")
                } else {
                    print("✅ Notification scheduled for message from \(sender)")
                }
            }
        }
    }

    func checkExistingDocuments() async {

        let requestedTypes: Set<DocumentRequestType> = Set(
            messages
                .filter { $0.messageType == .documentRequest }
                .compactMap { $0.documentType }
        )

        guard !requestedTypes.isEmpty else { return }

        do {
            let docMap = try await db.fetchUploadedDocuments(applicationId: applicationId, borrowerId: borrowerId)
            var matched: [DocumentRequestType: String] = [:]
            for (dbType, status) in docMap {
                if let docType = DocumentRequestType.fromDBType(dbType),
                   requestedTypes.contains(docType) {

                    matched[docType] = status
                }
            }
            await MainActor.run {
                self.uploadedDocStatuses = matched
            }
        } catch {
            print("Error checking existing documents: \(error)")
        }
    }

    func uploadDocument(data: Data, isPDF: Bool, docType: DocumentRequestType) async {
        await MainActor.run {
            isUploading = true
            uploadErrorMessage = nil
        }

        do {
            let fileUrl = try await db.uploadChatDocument(
                data: data,
                isPDF: isPDF,
                docType: docType,
                applicationId: applicationId,
                borrowerId: borrowerId
            )

            let notifyText = "📎 I've uploaded my \(docType.displayName). Please review it."
            let saved = try await db.sendMessage(
                applicationId: applicationId,
                senderId: borrowerId,
                content: notifyText,
                messageType: .text,
                documentType: docType
            )
            let msg = ChatMessage(from: saved, currentUserId: borrowerId, officerId: officerId)

            await MainActor.run {
                self.uploadedDocStatuses[docType] = "Pending"
                self.isUploading = false
                if !self.messages.contains(where: { $0.id == msg.id }) {
                    self.messages.append(msg)
                }
            }
        } catch {
            await MainActor.run {
                self.uploadErrorMessage = "Failed to upload document"
                self.isUploading = false
            }
            print("Error uploading document: \(error)")
        }
    }

    deinit {

        let appId = applicationId
        let database = db
        Task {
            await database.unsubscribeFromMessages(applicationId: appId, subscriberId: "chat_view")
        }
        ChatNotificationMonitor.shared.currentlyViewedApplicationId = nil
    }
}