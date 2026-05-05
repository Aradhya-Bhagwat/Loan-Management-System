

import SwiftUI
import Supabase

struct DocumentUploadView: View {
    @Environment(\.dismiss) var dismiss

    // MARK: - Variables from Form
    var loanAmount: Double
    var tenureMonths: Int
    var purpose: String

    // MARK: - Upload States
    @State private var isPanUploaded = false
    @State private var isAadhaarUploaded = false
    @State private var panURL: String?
    @State private var aadhaarURL: String?
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false

    let mockData = "dummy_file_content".data(using: .utf8)!

    var body: some View {
        ZStack {
            Color.theme.appBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Verify your identity to complete your \(purpose) application.")
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.textSecondary)
                    .padding(.horizontal)

                VStack(spacing: 16) {

                    UploadRow(title: "PAN Card", isDone: $isPanUploaded) {
                        await uploadFile(type: "PAN")
                    }

                    UploadRow(title: "Aadhaar Card", isDone: $isAadhaarUploaded) {
                        await uploadFile(type: "Address")
                    }
                }
                .padding(.horizontal)

                Spacer()

                // MARK: Final Submit Button
                Button {
                    Task {
                        isSubmitting = true
                        do {

                            let appId = try await SupabaseManager.shared.submitApplicationWithAssignment(
                                loanAmount: loanAmount,
                                tenure: tenureMonths,
                                purpose: purpose,
                                employer: "Self Employed",
                                income: 50000
                            )

                            var docsToSave: [String: String] = [:]
                            if let pan = panURL { docsToSave["PAN"] = pan }
                            if let aadhaar = aadhaarURL { docsToSave["Address"] = aadhaar }

                            if !docsToSave.isEmpty {
                                try await SupabaseManager.shared.saveApplicationDocuments(applicationId: appId, documents: docsToSave)
                            }

                            showSuccessAlert = true
                        } catch {
                            print("Submission error: \(error)")
                        }
                        isSubmitting = false
                    }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Finish & Submit")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isPanUploaded && isAadhaarUploaded ? Color.theme.primaryAccent : Color.gray.opacity(0.15))
                .foregroundStyle(isPanUploaded && isAadhaarUploaded ? Color.theme.primaryText : Color.theme.textSecondary.opacity(0.8))
                .clipShape(Capsule())
                .disabled(!isPanUploaded || !isAadhaarUploaded || isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Verification")
        .alert("Application Submitted! 🎉", isPresented: $showSuccessAlert) {
            Button("Got it") { dismiss() }
        } message: {
            Text("We've received your application and documents. You can track the status in the Loans tab.")
        }
    }

    func uploadFile(type: String) async {
        do {
            let url = try await SupabaseManager.shared.uploadDocumentAndUpdateTable(
                docType: type,
                data: mockData,
                isPDF: false
            )
            if type == "PAN" { 
                isPanUploaded = true
                panURL = url
            }
            if type == "Address" { 
                isAadhaarUploaded = true
                aadhaarURL = url
            }
        } catch {
            print("Upload failed for \(type): \(error)")
        }
    }
}

// MARK: - Local Helper Row
struct UploadRow: View {
    let title: String
    @Binding var isDone: Bool
    let action: () async -> Void
    @State private var loading = false

    var body: some View {
        HStack {
            Text(title).foregroundStyle(Color.theme.textPrimary)
            Spacer()
            if loading {
                ProgressView().tint(Color.theme.primaryAccent)
            } else {
                Button(isDone ? "Uploaded" : "Upload") {
                    loading = true
                    Task {
                        await action()
                        loading = false
                    }
                }
                .font(.caption).bold()
                .foregroundStyle(isDone ? Color.theme.success : Color.theme.primaryText)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isDone ? Color.theme.successBackground : Color.theme.primaryAccent)
                .clipShape(Capsule())
            }
        }
        .padding()
        .cardStyle()
    }
}
