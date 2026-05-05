import SwiftUI
import Foundation
import SafariServices


// MARK: - Data Model

struct LoanDocument: Identifiable {
    let id = UUID()
    let name: String
    let category: DocumentCategory
    let uploadedOn: String
    let status: DocStatus
    let url: String?

    enum DocumentCategory: String, CaseIterable {
        case idProof       = "ID PROOF"
        case addressProof  = "ADDRESS PROOF"
        case incomeDoc     = "INCOME DOCUMENT"

        var displayName: String { rawValue }
    }
}

// MARK: - Build documents from real DB data

extension LoanDocument {
    static func fromLoanCase(_ loan: LoanCase) -> [LoanDocument] {
        let docs = loan.documents
        let createdDate = loan.application.createdAt ?? "—"

        return [
            LoanDocument(
                name: "PAN Card",
                category: .idProof,
                uploadedOn: createdDate,
                status: docs?.hasPanDoc == true ? .pending : .pending,
                url: docs?.panDocUrl
            ),
            LoanDocument(
                name: "Aadhaar Card",
                category: .addressProof,
                uploadedOn: createdDate,
                status: docs?.hasAadhaarDoc == true ? .pending : .pending,
                url: docs?.aadhaarDocUrl
            ),
            LoanDocument(
                name: "Income Proof",
                category: .incomeDoc,
                uploadedOn: createdDate,
                status: docs?.hasIncomeProof == true ? .pending : .pending,
                url: docs?.incomeProofUrl
            ),
        ]
    }
}

// MARK: - Main Screen

struct DocumentsReviewScreen: View {
    let loan: LoanCase
    let applicationId: UUID
    var officerId: UUID = UUID()
    var onDocumentsUpdated: (() -> Void)? = nil

    @State private var documents: [ApplicationDocument] = []
    @State private var isLoading = true
    @State private var viewingDoc: IdentifiableDoc?
    @State private var errorMessage: String?

    private var verifiedCount: Int { documents.filter { $0.status == "Verified" }.count }
    private var pendingCount:  Int { documents.filter { $0.status == "Pending"  }.count }

    var body: some View {
        ZStack {
            OfficerTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    borrowerHeader

                    if isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Fetching documents from vault...")
                                .font(.subheadline)
                                .foregroundStyle(OfficerTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(OfficerTheme.iconRed)
                            Text(error)
                                .multilineTextAlignment(.center)
                            Button("Retry") { loadDocuments() }
                                .buttonStyle(.bordered)
                        }
                        .padding(.top, 100)
                    } else if documents.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundStyle(OfficerTheme.textSecondary.opacity(0.3))
                            Text("No documents uploaded yet")
                                .font(.headline)
                                .foregroundStyle(OfficerTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        summaryRow

                        VStack(alignment: .leading, spacing: 10) {
                            Text("ALL DOCUMENTS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(OfficerTheme.textSecondary)
                                .padding(.top, 4)

                            ForEach(documents) { doc in
                                DocumentCard(
                                    document: doc,
                                    borrowerId: loan.application.borrowerId,
                                    officerId: officerId
                                ) {
                                    if let url = URL(string: doc.fileUrl) {
                                        self.viewingDoc = IdentifiableDoc(url: url)
                                    }
                                } onUpdate: {
                                    loadDocuments()
                                    onDocumentsUpdated?()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewingDoc) { doc in
            DocumentViewer(url: doc.url)
        }
        .task {
            loadDocuments()
        }
    }

    private func loadDocuments() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                guard let borrowerId = loan.application.borrowerId else {
                    await MainActor.run {
                        self.errorMessage = "Borrower ID not available for this loan."
                        self.isLoading = false
                    }
                    return
                }

                // Fetch uploaded documents from BOTH sources:
                // 1. Legacy `documents` table (column-based: PAN, Aadhaar, Income, Business)
                let legacyDocs = (try? await DatabaseService.shared.fetchUploadedDocuments(borrowerId: borrowerId)) ?? []
                // 2. `loan_application_documents` table (row-based: GST, ITR, Balance Sheet, etc.)
                let appDocs = ((try? await DatabaseService.shared.fetchLoanApplicationDocuments(applicationId: applicationId)) ?? [])
                    .sorted { lhs, rhs in
                        Self.parseDate(lhs.createdAt) < Self.parseDate(rhs.createdAt)
                    }
                
                let uploadedDocs = legacyDocs + appDocs.map { $0.toUploadedDocument() }

                // Build a lookup for status/remarks from loan_application_documents rows
                // Key: normalized document name → (status, remarks, original DB id)
                var appDocStatusMap: [UUID: (status: String, remarks: String?)] = [:]
                for doc in appDocs {
                    appDocStatusMap[doc.id] = (status: doc.status ?? "Pending", remarks: doc.remarks)
                }

                let createdDate = loan.application.createdAt ?? "—"

                // Use the product's required documents, or fall back to defaults
                let requirements: [LoanDocumentRequirement]
                if let reqs = loan.requiredDocuments, !reqs.isEmpty {
                    requirements = reqs
                } else {
                    requirements = DocumentSummary.defaultRequirements
                }

                var converted: [ApplicationDocument] = []

                // 1. Process required documents
                for req in requirements {
                    let matchingAppDoc = appDocs.last { doc in
                        DocumentSummary.namesMatch(req.name, doc.documentType)
                    }
                    let uploadedUrl = matchingAppDoc?.fileUrl
                        ?? DocumentSummary.findUploadedUrl(name: req.name, uploadedDocs: uploadedDocs)
                    let resolvedUrl = Self.resolveDocUrl(uploadedUrl)

                    let docStatus: String
                    let docRemarks: String?
                    let docId: UUID
                    let realDbId: UUID?

                    if let match = matchingAppDoc, let entry = appDocStatusMap[match.id] {
                        docStatus = entry.status
                        docRemarks = entry.remarks
                        docId = match.id
                        realDbId = match.id
                    } else {
                        docStatus = "Pending"
                        docRemarks = nil
                        docId = UUID()
                        realDbId = nil
                    }

                    converted.append(ApplicationDocument(
                        id: docId,
                        applicationId: applicationId,
                        name: req.name,
                        fileUrl: resolvedUrl,
                        status: docStatus,
                        remarks: docRemarks,
                        uploadedAt: Self.parseDate(createdDate),
                        dbDocumentId: realDbId
                    ))
                }

                await MainActor.run {
                    self.documents = converted
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load documents: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private static func parseDate(_ string: String) -> Date {
        guard !string.isEmpty else { return Date.distantPast }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: string) {
            return parsed
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: string) ?? Date.distantPast
    }

    private static func parseDate(_ string: String?) -> Date {
        guard let string else { return Date.distantPast }
        return parseDate(string)
    }

    private static func resolveDocUrl(_ storedValue: String?) -> String {
        guard let path = storedValue, !path.isEmpty else { return "" }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return path
        }
        return DatabaseService.shared.getDocumentUrl(storagePath: path).absoluteString
    }

    private var borrowerHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loan.borrower.displayName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(OfficerTheme.textPrimary)
            Text(loan.application.purpose ?? "Loan Application")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OfficerTheme.textSecondary)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 14) {
            SummaryChip(
                icon: "checkmark.circle.fill",
                label: "Verified",
                value: "\(verifiedCount)",
                tint: OfficerTheme.iconGreen
            )
            SummaryChip(
                icon: "clock.fill",
                label: "Pending",
                value: "\(pendingCount)",
                tint: OfficerTheme.iconAmber
            )
        }
    }
}

// MARK: - Summary Chip

private struct SummaryChip: View {
    let icon: String; let label: String; let value: String; let tint: Color
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundStyle(tint)
                    Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(OfficerTheme.textSecondary)
                }
                Text(value)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(OfficerTheme.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(OfficerTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Document Viewer
// MARK: - Helper Models

struct IdentifiableDoc: Identifiable {
    let id = UUID()
    let url: URL
}

struct DocumentViewer: View {
    let url: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        SafariDocumentView(url: url)
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(OfficerTheme.accentBlue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
    }
}

private struct SafariDocumentView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Document Card

private struct DocumentCard: View {
    let document: ApplicationDocument
    let borrowerId: UUID?
    var officerId: UUID = UUID()
    var onView: () -> Void
    var onUpdate: () -> Void

    @State private var showVerifyConfirm = false
    @State private var showRejectSheet = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var chatSent = false

    // Tracks the remark entered/saved for this card locally
    // (the real source of truth is ApplicationDocument.remarks from DB)
    @State private var savedRemark: String = ""

    private var isRejected: Bool { document.status == "Rejected" }
    private var isVerified: Bool { document.status == "Verified" }

    var body: some View {
        WhiteCard {
            VStack(alignment: .leading, spacing: 16) {

                // ── Header ───────────────────────────────────────────────
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(statusIconColor)
                        .frame(width: 48, height: 48)
                        .background(statusIconColor.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.name)
                            .font(.system(size: 16, weight: .bold))

                        Text("Uploaded \(document.uploadedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 13))
                            .foregroundStyle(OfficerTheme.textSecondary)

                        Tag(
                            text: document.status.uppercased(),
                            foreground: statusTagColor,
                            background: statusTagColor.opacity(0.12)
                        )
                        .padding(.top, 4)
                    }

                    Spacer()
                }

                // ── Rejection remark banner ──────────────────────────────
                // Shows when the doc has been rejected and a remark exists.
                let remark = savedRemark.isEmpty ? (document.remarks ?? "") : savedRemark
                if isRejected && !remark.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(OfficerTheme.iconRed)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rejection Reason")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(OfficerTheme.iconRed)
                            Text(remark)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OfficerTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OfficerTheme.iconRed.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // ── Preview placeholder ──────────────────────────────────
                documentPreviewPlaceholder

                // ── Action buttons ───────────────────────────────────────
                actionButtons
            }
        }
        .onAppear {
            savedRemark = document.remarks ?? ""
        }
        // ── Verify confirmation alert ────────────────────────────────────
        .alert("Verify Document", isPresented: $showVerifyConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Mark as Verified") { verifyDoc() }
        } message: {
            Text("Confirm that you have reviewed '\(document.name)'.")
        }
        // ── Reject sheet ─────────────────────────────────────────────────
        .sheet(isPresented: $showRejectSheet) {
            RejectDocumentSheet(documentName: document.name) { remark in
                savedRemark = remark
                rejectDoc(remark: remark)
            }
        }
        // ── Error alert ──────────────────────────────────────────────────
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: Computed colours

    private var statusTagColor: Color {
        switch document.status {
        case "Verified": return OfficerTheme.iconGreen
        case "Rejected": return OfficerTheme.iconRed
        default:         return OfficerTheme.iconAmber
        }
    }

    private var statusIconColor: Color {
        switch document.status {
        case "Verified": return OfficerTheme.iconGreen
        case "Rejected": return OfficerTheme.iconRed
        default:         return OfficerTheme.textSecondary
        }
    }

    // MARK: Sub-views

    private var documentPreviewPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(OfficerTheme.filterBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .overlay(
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                        .foregroundStyle(OfficerTheme.textSecondary.opacity(0.5))
                        .frame(width: 64, height: 64)
                        .background(OfficerTheme.softLine.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text(!document.fileUrl.isEmpty ? "Document Available" : "No Document Uploaded")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(OfficerTheme.textSecondary)
                }
            )
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Row 1: View Original (only if URL exists)
            if !document.fileUrl.isEmpty {
                Button(action: onView) {
                    Label("View Original", systemImage: "eye.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(OfficerTheme.accentBlue.opacity(0.10))
                        .foregroundColor(OfficerTheme.accentBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            // Row 2: Logic for Verify / Reject
            if isVerified {
                // Verified state: Still allow Reject
                Button {
                    showRejectSheet = true
                } label: {
                    Label("Reject", systemImage: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(OfficerTheme.iconRed.opacity(0.10))
                        .foregroundColor(OfficerTheme.iconRed)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else if !isRejected {
                // Pending state: both Verify and Reject
                HStack(spacing: 10) {
                    // Reject button
                    Button {
                        showRejectSheet = true
                    } label: {
                        Label("Reject", systemImage: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(OfficerTheme.iconRed.opacity(0.10))
                            .foregroundColor(OfficerTheme.iconRed)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Verify button
                    Button {
                        showVerifyConfirm = true
                    } label: {
                        if isProcessing {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Label("Verify", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .background(OfficerTheme.iconGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                }
            } else {
                // Rejected state: Edit Remark button
                Button {
                    showRejectSheet = true
                } label: {
                    Label("Edit Rejection Reason", systemImage: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(OfficerTheme.iconRed.opacity(0.10))
                        .foregroundColor(OfficerTheme.iconRed)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Actions

    private func verifyDoc() {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                try await DatabaseService.shared.upsertDocumentStatus(
                    documentId: document.dbDocumentId,
                    applicationId: document.applicationId,
                    borrowerId: borrowerId ?? UUID(),
                    documentType: document.name,
                    fileUrl: document.fileUrl,
                    status: "Verified"
                )
                await MainActor.run {
                    isProcessing = false
                    onUpdate()
                }
            } catch {
                print("❌ Error verifying document: \(error)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to verify: \(error.localizedDescription)"
                }
            }
        }
    }

    private func rejectDoc(remark: String) {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                try await DatabaseService.shared.upsertDocumentStatus(
                    documentId: document.dbDocumentId,
                    applicationId: document.applicationId,
                    borrowerId: borrowerId ?? UUID(),
                    documentType: document.name,
                    fileUrl: document.fileUrl,
                    status: "Rejected",
                    remarks: remark
                )

                // Find matching DocumentRequestType for this document name using robust matching
                let docType = DocumentRequestType.allCases.first { dt in
                    dt.matchingDocTypes.contains { keyword in
                        DocumentSummary.namesMatch(document.name, keyword)
                    }
                }

                // 1. Send the rejection reason as a text message
                let reasonContent = "⚠️ Document Rejected: \(document.name)\nReason: \(remark)"
                try await DatabaseService.shared.sendMessage(
                    applicationId: document.applicationId,
                    senderId: officerId,
                    content: reasonContent,
                    messageType: .text,
                    documentType: nil
                )

                // 2. Send the EXACT SAME upload request that the manual button sends
                // This bypasses any bugs in the borrower app that rely on exact string matching
                let requestContent = "Please upload your \(docType?.displayName ?? document.name)"
                try await DatabaseService.shared.sendMessage(
                    applicationId: document.applicationId,
                    senderId: officerId,
                    content: requestContent,
                    messageType: .documentRequest,
                    documentType: docType?.rawValue ?? document.name
                )

                await MainActor.run {
                    isProcessing = false
                    chatSent = true
                    onUpdate()
                }
            } catch {
                print("❌ Error rejecting document: \(error)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to reject: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Reject Document Sheet

private struct RejectDocumentSheet: View {
    let documentName: String
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var remarkText: String = ""
    @FocusState private var isFocused: Bool

    private var canSubmit: Bool { !remarkText.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                OfficerTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Context banner ───────────────────────────────
                        HStack(spacing: 14) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(OfficerTheme.iconRed)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reject Document")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(OfficerTheme.textPrimary)
                                Text(documentName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OfficerTheme.iconRed.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // ── Remark field ─────────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rejection Reason")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(OfficerTheme.textSecondary)

                            Text("Explain clearly why this document is invalid so the borrower knows exactly what to resubmit.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(OfficerTheme.card)
                                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)

                                if remarkText.isEmpty {
                                    Text("e.g. Image is blurry, name doesn't match PAN records…")
                                        .font(.system(size: 15))
                                        .foregroundStyle(OfficerTheme.textSecondary.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                }

                                TextEditor(text: $remarkText)
                                    .font(.system(size: 15))
                                    .foregroundStyle(OfficerTheme.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                                    .padding(12)
                                    .focused($isFocused)
                            }
                            .frame(minHeight: 140)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        isFocused ? OfficerTheme.iconRed.opacity(0.5) : OfficerTheme.softLine,
                                        lineWidth: isFocused ? 1.5 : 1
                                    )
                            )

                            // Character hint
                            HStack {
                                Spacer()
                                Text("\(remarkText.count) characters")
                                    .font(.system(size: 12))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                            }
                        }

                        // ── Common reasons quick-fill ─────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("COMMON REASONS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(OfficerTheme.textSecondary)

                            let reasons = [
                                "Image is blurry or unreadable",
                                "Document is expired",
                                "Name does not match application",
                                "Document appears tampered or altered",
                                "Wrong document type uploaded",
                            ]

                            ForEach(reasons, id: \.self) { reason in
                                Button {
                                    remarkText = reason
                                } label: {
                                    HStack {
                                        Text(reason)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(OfficerTheme.textPrimary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(OfficerTheme.iconRed.opacity(0.6))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(OfficerTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // ── Confirm button ────────────────────────────────
                        Button {
                            let trimmed = remarkText.trimmingCharacters(in: .whitespaces)
                            onConfirm(trimmed)
                            dismiss()
                        } label: {
                            Text("Confirm Rejection")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    canSubmit
                                        ? OfficerTheme.iconRed
                                        : OfficerTheme.iconRed.opacity(0.35)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmit)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Reject Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(OfficerTheme.textSecondary)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
