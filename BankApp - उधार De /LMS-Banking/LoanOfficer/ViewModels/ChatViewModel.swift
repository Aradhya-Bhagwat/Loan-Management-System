import SwiftUI

@Observable
class ChatViewModel {
    let applicationId: UUID
    let officerId: UUID
    let borrowerId: UUID
    let borrowerName: String

    var messages: [ChatMessage] = []
    var newMessageText: String = ""
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    var documentUploadStatuses: [String: Bool] = [:]

    private let db = DatabaseService.shared

    init(applicationId: UUID, officerId: UUID, borrowerId: UUID, borrowerName: String) {
        self.applicationId = applicationId
        self.officerId = officerId
        self.borrowerId = borrowerId
        self.borrowerName = borrowerName
    }

    var borrowerInitials: String {
        borrowerName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }

    func isDocumentUploaded(_ type: String) -> Bool {
        documentUploadStatuses[type] ?? false
    }

    func loadMessages() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            async let messagesTask: [DBChatMessage] = db.fetchMessages(applicationId: applicationId)
            async let docsTask: [DBLoanApplicationDocument] =
                db.fetchLoanApplicationDocuments(applicationId: applicationId)

            let (dbMessages, loanDocs) = try await (messagesTask, docsTask)

            let chatMessages = dbMessages.map { dbMsg in
                ChatMessage(from: dbMsg, currentUserId: officerId, officerId: officerId)
            }

            var statuses: [String: Bool] = [:]
            for docType in DocumentRequestType.allCases {
                let matchKeywords = docType.matchingDocTypes
                let hasUpload = loanDocs.contains { doc in
                    let isMatchingType = matchKeywords.contains { keyword in
                        doc.documentType.localizedCaseInsensitiveContains(keyword)
                    }
                    return isMatchingType && doc.status != "Rejected"
                }
                statuses[docType.rawValue] = hasUpload
            }
            
            // Add custom doc types from DB
            for doc in loanDocs {
                if statuses[doc.documentType] == nil {
                    statuses[doc.documentType] = (doc.status != "Rejected")
                }
            }

            await MainActor.run {
                self.messages = chatMessages
                self.documentUploadStatuses = statuses
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load messages"
                self.isLoading = false
            }
            print("Error loading messages: \(error)")
        }

        db.subscribeToMessages(applicationId: applicationId) { [weak self] dbMsg in
            Task { @MainActor in
                guard let self else { return }
                let msg = ChatMessage(from: dbMsg, currentUserId: self.officerId, officerId: self.officerId)
                if !self.messages.contains(where: { $0.id == msg.id }) {
                    self.messages.append(msg)
                    // Refresh statuses when a new message arrives (it might be a new request or upload)
                    Task { await self.refreshDocumentStatuses() }
                }
            }
        }
    }

    func refreshDocumentStatuses() async {
        do {
            let loanDocs = try await db.fetchLoanApplicationDocuments(applicationId: applicationId)
            var statuses: [String: Bool] = [:]
            
            // Core types
            for docType in DocumentRequestType.allCases {
                let matchKeywords = docType.matchingDocTypes
                let hasUpload = loanDocs.contains { doc in
                    let isMatchingType = matchKeywords.contains { keyword in
                        doc.documentType.localizedCaseInsensitiveContains(keyword)
                    }
                    return isMatchingType && doc.status != "Rejected"
                }
                statuses[docType.rawValue] = hasUpload
            }
            
            // Custom types
            for doc in loanDocs {
                if statuses[doc.documentType] == nil {
                    statuses[doc.documentType] = (doc.status != "Rejected")
                }
            }

            await MainActor.run {
                self.documentUploadStatuses = statuses
            }
        } catch {
            print("Error refreshing document statuses: \(error)")
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
                senderId: officerId,
                content: text,
                messageType: .text,
                documentType: nil
            )
            let msg = ChatMessage(from: saved, currentUserId: officerId, officerId: officerId)
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

    func sendDocumentRequest(docType: DocumentRequestType) async {
        await MainActor.run { isSending = true }

        let content = "Please upload your \(docType.displayName)"

        do {
            let saved = try await db.sendMessage(
                applicationId: applicationId,
                senderId: officerId,
                content: content,
                messageType: .documentRequest,
                documentType: docType.rawValue
            )
            let msg = ChatMessage(from: saved, currentUserId: officerId, officerId: officerId)
            await MainActor.run {
                if !self.messages.contains(where: { $0.id == msg.id }) {
                    self.messages.append(msg)
                }
                self.isSending = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to send document request"
                self.isSending = false
            }
            print("Error sending document request: \(error)")
        }
    }

    func disconnect() {
        db.unsubscribeFromMessages()
    }

    deinit {
        db.unsubscribeFromMessages()
    }
}
