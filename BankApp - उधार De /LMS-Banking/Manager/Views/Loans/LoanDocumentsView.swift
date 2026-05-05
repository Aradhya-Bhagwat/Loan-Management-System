import SwiftUI
import SafariServices

struct LoanDocumentsView: View {
    let loan: Loan
    @State private var documentRecord: BorrowerDocumentRecord?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var safariUrl: IdentifiableURL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView("Loading documents\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ErrorView(message: errorMessage) {
                    await loadDocuments()
                }
            } else {
                documentContent
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDocuments()
        }
        .sheet(item: $safariUrl) { urlWrapper in
            SafariView(url: urlWrapper.url)
        }
    }

    private var documentContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                borrowerHeader
                summaryRow
                documentListGroup
            }
            .padding(20)
        }
    }

    private var borrowerHeader: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.appGreen.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(loan.borrowerName.prefix(1))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.appGreen)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(loan.borrowerName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Text(loan.purpose)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var documentListGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Uploaded Documents")

            if let record = documentRecord {
                ForEach(record.documentSlots) { slot in
                    BorrowerDocumentCard(slot: slot) {
                        openDocument(storagePath: slot.storagePath ?? "")
                    }
                }
            } else {
                noDocumentsView
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            SummaryChip(
                icon: "checkmark.circle.fill",
                label: "Uploaded",
                value: "\(uploadedCount)",
                color: Color.appGreen
            )
            SummaryChip(
                icon: "xmark.circle.fill",
                label: "Missing",
                value: "\(missingCount)",
                color: Color.appRed
            )
        }
    }

    private var noDocumentsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No documents on file")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Documents for this borrower have not been uploaded yet.")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var uploadedCount: Int {
        documentRecord?.documentSlots.filter { $0.isUploaded }.count ?? 0
    }

    private var missingCount: Int {
        documentRecord?.documentSlots.filter { !$0.isUploaded }.count ?? 3
    }

    private func loadDocuments() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let borrowerId = loan.borrowerId else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Borrower ID not available for this loan."
                }
                return
            }
            let record = try await DatabaseService.shared.fetchBorrowerDocuments(borrowerId: borrowerId)
            await MainActor.run {
                self.documentRecord = record
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load documents: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func openDocument(storagePath: String) {
        guard !storagePath.isEmpty else { return }
        
        let url: URL
        if storagePath.hasPrefix("http://") || storagePath.hasPrefix("https://") {
            url = URL(string: storagePath) ?? DatabaseService.shared.getDocumentUrl(storagePath: storagePath)
        } else {
            url = DatabaseService.shared.getDocumentUrl(storagePath: storagePath)
        }
        
        safariUrl = IdentifiableURL(url: url)
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct BorrowerDocumentCard: View {
    let slot: BorrowerDocumentSlot
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: slot.isUploaded ? "doc.fill" : "doc")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(slot.isUploaded ? Color.appGreen : .secondary)
                    .frame(width: 48, height: 48)
                    .background(slot.isUploaded ? Color.appGreen.opacity(0.1) : Color.appSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(slot.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)

                    if slot.isUploaded {
                        Text("Uploaded")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.appGreen)
                    } else {
                        Text("Not uploaded")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if slot.isUploaded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.appGreen)
                } else {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
            }

            if slot.isUploaded {
                Divider()
                    .padding(.top, 14)
                    .padding(.bottom, 14)

                Button(action: onOpen) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Open Document")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color.appGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appGreen.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SummaryChip: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ErrorView: View {
    let message: String
    let onRetry: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.appOrange)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await onRetry() }
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.appGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(40)
    }
}
