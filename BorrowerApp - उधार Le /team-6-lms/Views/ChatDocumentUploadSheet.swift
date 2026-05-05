import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import VisionKit
import PDFKit

struct ChatDocumentUploadSheet: View {
    let docType: DocumentRequestType
    let applicationId: UUID
    let borrowerId: UUID
    let controller: BorrowerChatController
    let onDismiss: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPDFPicker = false
    @State private var showPhotoPicker = false
    @State private var showSourcePicker = false
    @State private var uploadState: UploadState = .idle

    enum UploadState {
        case idle
        case uploading
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.appBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    Image(systemName: docType.icon)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Color.theme.primaryAccent)
                        .frame(width: 80, height: 80)
                        .background(Color.theme.primaryAccent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(spacing: 6) {
                        Text(docType.displayName)
                            .font(.title3.bold())
                            .foregroundStyle(Color.theme.textPrimary)
                        Text("Upload the requested document")
                            .font(.subheadline)
                            .foregroundStyle(Color.theme.textSecondary)
                    }

                    if case .failure(let message) = uploadState {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(message)
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 20)
                    }

                    switch uploadState {
                    case .idle, .failure:
                        uploadOptions
                    case .uploading:
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(Color.theme.primaryAccent)
                            Text("Uploading document…")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.theme.textSecondary)
                        }
                        .padding(.top, 20)
                    case .success:
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(Color.theme.success)
                            Text("Document uploaded successfully")
                                .font(.headline)
                                .foregroundStyle(Color.theme.textPrimary)
                            Text("Your loan officer has been notified")
                                .font(.caption)
                                .foregroundStyle(Color.theme.textSecondary)
                        }
                        .padding(.top, 12)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Upload Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.theme.primaryAccent)
                }
            }
            .alert("Upload \(docType.displayName)", isPresented: $showSourcePicker) {
                Button("Scan using Camera") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showCamera = true
                    }
                }
                Button("Choose from Photos") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showPhotoPicker = true
                    }
                }
                Button("Upload PDF from Files") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showPDFPicker = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                DocumentScannerView { pdfData, isPDF in
                    handleUploadData(data: pdfData, isPDF: isPDF)
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            .sheet(isPresented: $showPDFPicker) {
                PDFPickerViewController { result in
                    switch result {
                    case .success(let data):
                        handleUploadData(data: data, isPDF: true)
                    case .failure:
                        uploadState = .failure("Failed to read PDF file")
                    }
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                if let newValue {
                    handlePhotoSelection(newValue)
                }
            }
            .onChange(of: controller.uploadedDocStatuses) { _, newMap in
                if newMap.keys.contains(docType) && !controller.isUploading {
                    uploadState = .success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        onDismiss()
                    }
                }
            }
        }
    }

    private var uploadOptions: some View {
        VStack(spacing: 12) {

            Button {
                showSourcePicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.theme.primaryAccent.opacity(0.12))
                        .foregroundStyle(Color.theme.primaryAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upload Document")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.theme.textPrimary)
                        Text("Camera scan, photo, or PDF")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.theme.textSecondary.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            }
            .buttonStyle(.plain)

            Text("Supported formats: PDF, JPEG, PNG")
                .font(.caption2)
                .foregroundStyle(Color.theme.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 20)
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem) {
        uploadState = .uploading
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    uploadState = .failure("Could not read image data")
                    return
                }
                await performUpload(data: data, isPDF: false)
            } catch {
                uploadState = .failure("Failed to load image")
            }
        }
    }

    private func handleUploadData(data: Data, isPDF: Bool) {
        uploadState = .uploading
        Task {
            await performUpload(data: data, isPDF: isPDF)
        }
    }

    private func performUpload(data: Data, isPDF: Bool) async {
        await controller.uploadDocument(data: data, isPDF: isPDF, docType: docType)
        if let error = controller.uploadErrorMessage {
            uploadState = .failure(error)
            controller.uploadErrorMessage = nil
        }
    }
}

struct PDFPickerViewController: UIViewControllerRepresentable {
    let onPick: (Result<Data, Error>) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Result<Data, Error>) -> Void

        init(onPick: @escaping (Result<Data, Error>) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                onPick(.success(data))
            } catch {
                onPick(.failure(error))
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(.failure(NSError(domain: "PDFPicker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cancelled"])))
        }
    }
}