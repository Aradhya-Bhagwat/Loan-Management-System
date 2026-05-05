import SwiftUI

struct BorrowerChatView: View {
    let applicationId: UUID
    let borrowerId: UUID
    let officerId: UUID
    let officerName: String

    @State private var controller: BorrowerChatController
    @FocusState private var isInputFocused: Bool
    @State private var selectedDocType: DocumentRequestType?

    init(applicationId: UUID, borrowerId: UUID, officerId: UUID, officerName: String) {
        self.applicationId = applicationId
        self.borrowerId = borrowerId
        self.officerId = officerId
        self.officerName = officerName
        _controller = State(wrappedValue: BorrowerChatController(
            applicationId: applicationId,
            borrowerId: borrowerId,
            officerId: officerId,
            officerName: officerName
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            inputBar
        }
        .dismissKeyboardOnTap()
        .background(BorrowerTheme.background)
        .navigationTitle(officerName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ChatNotificationMonitor.shared.currentlyViewedApplicationId = applicationId
            await controller.loadMessages()
        }
        .onDisappear {
            ChatNotificationMonitor.shared.currentlyViewedApplicationId = nil
            controller.disconnect()
        }
        .sheet(item: $selectedDocType) { docType in
            ChatDocumentUploadSheet(
                docType: docType,
                applicationId: applicationId,
                borrowerId: borrowerId,
                controller: controller,
                onDismiss: {
                    selectedDocType = nil
                }
            )
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    if controller.isLoading {
                        ProgressView()
                            .tint(BorrowerTheme.accentGreen)
                            .padding(.top, 40)
                    } else if controller.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(controller.messages) { message in
                            BorrowerMessageBubble(
                                message: message,
                                officerInitials: controller.officerInitials,
                                docStatus: message.messageType == .documentRequest && message.documentType != nil ? controller.uploadedDocStatuses[message.documentType!] : nil,
                                onUploadRequest: {
                                    selectedDocType = message.documentType
                                }
                            )
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: controller.messages.count) { _, _ in
                if let lastId = controller.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(BorrowerTheme.accentGreen.opacity(0.5))
            Text("No messages yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(BorrowerTheme.textSecondary)
            Text("Chat with your loan officer about your loan application")
                .font(.system(size: 13))
                .foregroundStyle(BorrowerTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Type a message\u{2026}", text: $controller.newMessageText, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(BorrowerTheme.filterBackground)
                .clipShape(Capsule())

            Button {
                Task { await controller.sendTextMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        controller.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? BorrowerTheme.textSecondary.opacity(0.4)
                            : BorrowerTheme.accentGreen
                    )
            }
            .buttonStyle(.plain)
            .disabled(controller.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(BorrowerTheme.card)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct BorrowerMessageBubble: View {
    let message: ChatMessage
    let officerInitials: String
    let docStatus: String? 
    let onUploadRequest: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromOfficer {
                avatar
                bubbleContent
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 60)
                bubbleContent
            }
        }
    }

    private var avatar: some View {
        Circle()
            .fill(BorrowerTheme.accentBlue.opacity(0.15))
            .frame(width: 30, height: 30)
            .overlay(
                Text(officerInitials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BorrowerTheme.accentBlue)
            )
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.messageType == .documentRequest {
            documentRequestBubble
        } else {
            textBubble
        }
    }

    private var textBubble: some View {
        VStack(alignment: message.isFromOfficer ? .leading : .trailing, spacing: 4) {
            Text(message.content)
                .font(.system(size: 15))
                .foregroundStyle(message.isFromOfficer ? BorrowerTheme.textPrimary : .white)
            Text(message.createdAt, style: .time)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(message.isFromOfficer ? BorrowerTheme.textSecondary : .white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            message.isFromOfficer
                ? BorrowerTheme.card
                : BorrowerTheme.accentGreen
        )
        .clipShape(BubbleShape(isOnRight: !message.isFromOfficer))
        .overlay(
            BubbleShape(isOnRight: !message.isFromOfficer)
                .stroke(
                    message.isFromOfficer ? BorrowerTheme.softLine : Color.clear,
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    private var documentRequestBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Document Requested by Loan Officer")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(BorrowerTheme.accentBlue)

            if let docType = message.documentType {
                HStack(spacing: 8) {
                    Image(systemName: docType.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(BorrowerTheme.accentBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(docType.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BorrowerTheme.textPrimary)

                        if let status = docStatus {
                            HStack(spacing: 4) {
                                Image(systemName: status == "Verified" ? "checkmark.seal.fill" : (status == "Rejected" ? "exclamationmark.octagon.fill" : "clock.fill"))
                                    .font(.system(size: 11, weight: .semibold))
                                Text(status)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(status == "Verified" ? BorrowerTheme.accentGreen : (status == "Rejected" ? .red : BorrowerTheme.accentBlue))
                        } else {
                            Text("Upload required")
                                .font(.system(size: 11))
                                .foregroundStyle(BorrowerTheme.textSecondary)
                        }
                    }
                }
            }

            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(BorrowerTheme.textSecondary)

            if docStatus == nil || docStatus == "Rejected" {
                Button {
                    onUploadRequest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Upload Document")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(BorrowerTheme.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Text(message.createdAt, style: .time)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(BorrowerTheme.textSecondary.opacity(0.6))
        }
        .padding(14)
        .background(BorrowerTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(docStatus == "Verified" ? BorrowerTheme.accentGreen.opacity(0.4) : (docStatus == "Rejected" ? Color.red.opacity(0.4) : BorrowerTheme.accentBlue.opacity(0.3)), lineWidth: 1.5)
        )
        .shadow(color: docStatus == "Verified" ? BorrowerTheme.accentGreen.opacity(0.1) : (docStatus == "Rejected" ? Color.red.opacity(0.1) : BorrowerTheme.accentBlue.opacity(0.1)), radius: 8, y: 4)
    }
}

private struct BubbleShape: Shape {
    let isOnRight: Bool

    func path(in rect: CGRect) -> SwiftUI.Path {
        let cornerRadius: CGFloat = 18
        let tailSize: CGFloat = 6
        var path = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)

        if isOnRight {
            let tailRect = CGRect(
                x: rect.maxX - tailSize,
                y: rect.maxY - cornerRadius,
                width: tailSize + 2,
                height: tailSize + 2
            )
            path.addRoundedRect(in: tailRect, cornerSize: CGSize(width: 3, height: 3))
        } else {
            let tailRect = CGRect(
                x: rect.minX - 2,
                y: rect.maxY - cornerRadius,
                width: tailSize + 2,
                height: tailSize + 2
            )
            path.addRoundedRect(in: tailRect, cornerSize: CGSize(width: 3, height: 3))
        }

        return path
    }
}