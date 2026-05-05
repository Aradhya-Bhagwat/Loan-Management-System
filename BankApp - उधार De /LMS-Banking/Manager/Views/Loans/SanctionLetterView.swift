import SwiftUI
import PDFKit

struct SanctionLetterView: View {
    let loan: Loan
    @Environment(AuthViewModel.self) var authController
    @State private var pdfData: Data? = nil
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var showShareSheet = false
    @State private var isAlreadySigned = false
    @Environment(\.horizontalSizeClass) var sizeClass

    var isPad: Bool { sizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            if let data = pdfData {
                PDFKitView(data: data)
                    .ignoresSafeArea(edges: .horizontal)

                VStack(spacing: 12) {
                    if let error = uploadError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appRed)
                            .multilineTextAlignment(.center)
                    }

                    if isUploading {
                        HStack(spacing: 10) {
                            ProgressView().tint(Color.appGreen)
                            Text("Saving letter…")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    else {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.appGreen)
                            Text("Digitally Signed & Approved")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appGreen)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
                .padding(.horizontal, isPad ? 28 : 20)
                .padding(.vertical, 16)
                .background(Color.appBackground)

            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(isUploading ? "Saving to server…" : "Generating letter…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Sanction Letter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20))
                }
                .disabled(pdfData == nil || isUploading)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = pdfData {
                SanctionLetterShareSheet(
                    data: data,
                    fileName: "SanctionLetter_\(loan.borrowerName.replacingOccurrences(of: " ", with: "_")).pdf"
                )
            }
        }
        .task {
            await loadOrGenerate()
        }
    }

    // MARK: - Load or Generate

    private func loadOrGenerate() async {
        // Check if already uploaded to DB
        if let existingUrl = try? await DatabaseService.shared.fetchSanctionLetterUrl(loanId: loan.id),
           let url = URL(string: existingUrl),
           let data = try? Data(contentsOf: url) {
            await MainActor.run {
                self.pdfData = data
                self.isAlreadySigned = true
            }
            return
        }

        // Generate fresh — signature is baked in
        let managerName = authController.currentUser?.name ?? "Branch Manager"
        let generated = SanctionLetterPDFGenerator.generate(for: loan, managerName: managerName)
        await MainActor.run {
            self.pdfData = generated
            self.isUploading = true
        }

        // Auto-upload immediately
        do {
            _ = try await DatabaseService.shared.uploadSanctionLetter(
                pdfData: generated,
                loanId: loan.id
            )
            await MainActor.run {
                self.isUploading = false
            }
        } catch {
            await MainActor.run {
                self.uploadError = "Could not save to server. You can still download it."
                self.isUploading = false
            }
            print("Sanction letter upload error: \(error)")
        }
    }
}

// MARK: - PDFKit View Wrapper

//struct PDFKitView: UIViewRepresentable {
//    let data: Data
//
//    func makeUIView(context: Context) -> PDFView {
//        let pdfView = PDFView()
//        pdfView.autoScales = true
//        pdfView.displayMode = .singlePageContinuous
//        pdfView.displayDirection = .vertical
//        pdfView.backgroundColor = UIColor.systemGroupedBackground
//        return pdfView
//    }
//
//    func updateUIView(_ pdfView: PDFView, context: Context) {
//        pdfView.document = PDFDocument(data: data)
//    }
//}

// MARK: - Share Sheet

struct SanctionLetterShareSheet: UIViewControllerRepresentable {
    let data: Data
    let fileName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        return UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
