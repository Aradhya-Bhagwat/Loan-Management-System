import SwiftUI

struct ChatView: View {
    let loan: LoanCase
    let officerId: UUID
    @State private var controller: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var scrollViewID = UUID()
    @State private var navigateToDocs = false

    init(loan: LoanCase, officerId: UUID) {
        self.loan = loan
        self.officerId = officerId
        let borrowerId = loan.application.borrowerId ?? UUID()
        let borrowerName = loan.borrower.displayName
        _controller = State(wrappedValue: ChatViewModel(
            applicationId: loan.application.id,
            officerId: officerId,
            borrowerId: borrowerId,
            borrowerName: borrowerName
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            documentRequestBar
            inputBar
        }
        .background(OfficerTheme.background)
        .navigationTitle(loan.borrower.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("Application \(loan.application.id.uuidString.prefix(8))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(OfficerTheme.textSecondary)
            }
        }
        .navigationDestination(isPresented: $navigateToDocs) {
            DocumentsReviewScreen(
                loan: loan,
                applicationId: loan.application.id,
                officerId: officerId
            )
        }
        .task {
            await controller.loadMessages()
        }
        .onDisappear {
            controller.disconnect()
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    if controller.isLoading {
                        ProgressView()
                            .tint(OfficerTheme.accentGreen)
                            .padding(.top, 40)
                    } else if controller.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(controller.messages) { message in
                            MessageBubble(
                                message: message,
                                borrowerInitials: controller.borrowerInitials,
                                isDocUploaded: message.messageType == .documentRequest && message.documentType != nil
                                    ? controller.isDocumentUploaded(message.documentType!)
                                    : (message.messageType == .documentRequest ? false : nil),
                                onDocStatusTap: { navigateToDocs = true }
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
                .foregroundStyle(OfficerTheme.accentGreen.opacity(0.5))
            Text("No messages yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OfficerTheme.textSecondary)
            Text("Start the conversation or request documents using the buttons below")
                .font(.system(size: 13))
                .foregroundStyle(OfficerTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }

    // MARK: - Relevant Document Types

    /// Filters document request buttons to only show documents
    /// required by this loan's product, falling back to all types
    private var relevantDocTypes: [DocumentRequestType] {
        let reqs = (loan.requiredDocuments == nil || loan.requiredDocuments!.isEmpty)
            ? DocumentSummary.defaultRequirements
            : loan.requiredDocuments!

        let filtered = DocumentRequestType.allCases.filter { docType in
            reqs.contains { req in
                docType.matchingDocTypes.contains { keyword in
                    req.name.localizedCaseInsensitiveContains(keyword) ||
                    keyword.localizedCaseInsensitiveContains(req.name)
                }
            }
        }
        return filtered.isEmpty ? Array(DocumentRequestType.allCases) : filtered
    }

    private var documentRequestBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Request:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OfficerTheme.textSecondary)

                ForEach(relevantDocTypes) { docType in
                    Button {
                        Task { await controller.sendDocumentRequest(docType: docType) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: docType.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(docType.displayName)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(OfficerTheme.accentGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(OfficerTheme.accentGreen.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(OfficerTheme.accentGreen.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(controller.isSending)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(OfficerTheme.card)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Type a message…", text: $controller.newMessageText, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(OfficerTheme.filterBackground)
                .clipShape(Capsule())

            Button {
                Task { await controller.sendTextMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        controller.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? OfficerTheme.textSecondary.opacity(0.4)
                            : OfficerTheme.accentGreen
                    )
            }
            .buttonStyle(.plain)
            .disabled(controller.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OfficerTheme.card)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let borrowerInitials: String
    var isDocUploaded: Bool?
    var onDocStatusTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !message.isFromOfficer {
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
            .fill(OfficerTheme.accentGreen.opacity(0.15))
            .frame(width: 30, height: 30)
            .overlay(
                Text(borrowerInitials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(OfficerTheme.accentGreen)
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
        VStack(alignment: message.isFromOfficer ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .font(.system(size: 15))
                .foregroundStyle(message.isFromOfficer ? .white : OfficerTheme.textPrimary)
            Text(message.createdAt, style: .time)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(message.isFromOfficer ? .white.opacity(0.7) : OfficerTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            message.isFromOfficer
                ? OfficerTheme.accentGreen
                : OfficerTheme.card
        )
        .clipShape(BubbleShape(isFromOfficer: message.isFromOfficer))
        .overlay(
            BubbleShape(isFromOfficer: message.isFromOfficer)
                .stroke(
                    message.isFromOfficer ? Color.clear : OfficerTheme.softLine,
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    private var documentRequestBubble: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Document Request")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.85))

            if let typeString = message.documentType {
                let resolvedType = DocumentRequestType.from(string: typeString)
                HStack(spacing: 6) {
                    Image(systemName: resolvedType?.icon ?? "doc.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(resolvedType?.displayName ?? typeString)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
            }

            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))

            if let isUploaded = isDocUploaded {
                Button {
                    onDocStatusTap?()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isUploaded ? "checkmark.circle.fill" : "clock.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isUploaded ? "Document Uploaded" : "Document Pending")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(isUploaded ? .white : .white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isUploaded ? Color.white.opacity(0.25) : Color.white.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Text(message.createdAt, style: .time)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [OfficerTheme.accentGreen, OfficerTheme.accentGreen.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(BubbleShape(isFromOfficer: true))
        .shadow(color: OfficerTheme.accentGreen.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Bubble Shape

private struct BubbleShape: Shape {
    let isFromOfficer: Bool

    func path(in rect: CGRect) -> SwiftUI.Path {
        let cornerRadius: CGFloat = 18
        let tailSize: CGFloat = 6
        var path = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)

        if isFromOfficer {
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
