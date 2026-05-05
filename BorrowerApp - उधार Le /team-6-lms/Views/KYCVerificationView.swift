import SwiftUI
import VisionKit

struct KYCVerificationView: View {
    @Environment(\.dismiss) var dismiss
    let profile: BorrowerProfile
    let docs: BorrowerDocuments?
    let onVerified: () -> Void

    @State private var selectedTab: KYCTab = .pan

    enum KYCTab { case pan, aadhaar }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("KYC Type", selection: $selectedTab) {
                    Text("PAN").tag(KYCTab.pan)
                    Text("Aadhaar").tag(KYCTab.aadhaar)
                }
                .pickerStyle(.segmented)
                .padding(16)

                if selectedTab == .pan {
                    PANVerificationSection(
                        existingPAN: profile.panNumber,
                        isAlreadyVerified: profile.panVerified,
                        onVerified: onVerified,
                        uploadedDocURL: docs?.panDocUrl
                    )
                } else {
                    AadhaarVerificationSection(
                        existingAadhaar: profile.aadhaarNumber,
                        isAlreadyVerified: profile.aadhaarVerified,
                        onVerified: onVerified,
                        uploadedDocURL: docs?.aadhaarDocUrl
                    )
                }

                Spacer()
            }
            .dismissKeyboardOnTap()
            .background(Color.theme.appBackground.ignoresSafeArea())
            .navigationTitle("KYC Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.theme.primaryAccent)
                }
            }
        }
    }
}

// MARK: - PAN Section

private struct PANVerificationSection: View {
    let existingPAN: String?
    let isAlreadyVerified: Bool
    let onVerified: () -> Void
    var uploadedDocURL: String? = nil

    @State private var panInput: String = ""
    @State private var isSaving = false
    @State private var isExtracting = false
    @State private var showScanner = false
    @State private var scanError: String? = nil
    @State private var isVerified = false

    var isValidFormat: Bool { KYCValidator.isValidPAN(panInput) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isAlreadyVerified || isVerified {
                    verifiedBanner(text: "PAN Verified", detail: panInput.isEmpty ? (existingPAN?.masked() ?? "") : panInput.masked())
                } else {

                    // MARK: Step 1 — Enter number
                    CardView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("PAN Number")
                                    .foregroundStyle(Color.theme.textPrimary)
                                Spacer()
                                TextField("ABCDE1234F", text: $panInput)
                                    .textInputAutocapitalization(.characters)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(Color.theme.primaryAccent)
                                    .onChange(of: panInput) { _, v in
                                        panInput = String(v.uppercased().prefix(10))
                                    }
                            }
                            .padding(16)

                            if !panInput.isEmpty {
                                Divider().padding(.horizontal, 16)
                                HStack {
                                    Image(systemName: isValidFormat ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(isValidFormat ? Color.theme.success : Color.theme.danger)
                                    Text(isValidFormat ? "Valid PAN format" : "Invalid format — must be ABCDE1234F")
                                        .font(.caption)
                                        .foregroundStyle(isValidFormat ? Color.theme.success : Color.theme.danger)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // MARK: Confirm button
                    Button {
                        Task { await savePAN() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Confirm PAN")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidFormat ? Color.theme.primaryAccent : Color.gray.opacity(0.2))
                    .foregroundStyle(isValidFormat ? Color.theme.primaryText : Color.theme.textSecondary)
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    .disabled(!isValidFormat || isSaving)

                    // MARK: Step 2 — Auto-fill helpers (secondary)
                    VStack(spacing: 10) {
                        Text("Or auto-fill from your documents")
                            .font(.caption)
                            .foregroundStyle(Color.theme.textSecondary)

                        if let docURL = uploadedDocURL, !docURL.isEmpty {
                            Button {
                                Task { await extractFromUploadedDoc(url: docURL) }
                            } label: {
                                if isExtracting {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(Color.theme.primaryAccent)
                                        Text("Extracting...")
                                            .font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Label("Extract from Uploaded Doc", systemImage: "doc.text.magnifyingglass")
                                        .font(.subheadline).fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 12)
                            .background(Color.theme.cardBackground)
                            .foregroundStyle(Color.theme.primaryAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.primaryAccent.opacity(0.4), lineWidth: 1))
                            .padding(.horizontal, 16)
                            .disabled(isExtracting)
                        }

                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan PAN Card", systemImage: "camera.fill")
                                .font(.subheadline).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 12)
                        .background(Color.theme.cardBackground)
                        .foregroundStyle(Color.theme.primaryAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.primaryAccent.opacity(0.4), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    if let error = scanError {
                        resultCard(success: false, title: "Could Not Extract", detail: error)
                    }
                }
            }
            .padding(.top, 8)
        }
        .onAppear { panInput = existingPAN ?? "" }
        .fullScreenCover(isPresented: $showScanner) {
            CardScannerView(documentType: .pan) { result in
                showScanner = false
                handleScanResult(result)
            }
            .ignoresSafeArea()
        }
    }

    private func extractFromUploadedDoc(url: String) async {
        isExtracting = true
        scanError = nil
        let result = await DocumentOCRExtractor.extractNumber(from: url, type: .pan)
        await MainActor.run {
            isExtracting = false
            handleScanResult(result)
        }
    }

    private func handleScanResult(_ result: OCRScanResult?) {
        guard let result else {
            scanError = "Could not read the document. Try scanning the card instead."
            return
        }
        if result.extractedNumber.isEmpty {
            scanError = "PAN number not found. Please enter manually."
        } else {
            panInput = result.extractedNumber
            scanError = nil
        }
    }

    private func savePAN() async {
        isSaving = true
        do {
            try await SupabaseManager.shared.savePANVerification(pan: panInput, verified: true)
            isVerified = true
            onVerified()
        } catch {
            scanError = "Failed to save: \(error.localizedDescription)"
        }
        isSaving = false
    }
}

// MARK: - Aadhaar Section

private struct AadhaarVerificationSection: View {
    let existingAadhaar: String?
    let isAlreadyVerified: Bool
    let onVerified: () -> Void
    var uploadedDocURL: String? = nil

    @State private var aadhaarInput: String = ""
    @State private var isSaving = false
    @State private var isExtracting = false
    @State private var showScanner = false
    @State private var scanError: String? = nil
    @State private var isVerified = false

    var isValidFormat: Bool { KYCValidator.isValidAadhaar(aadhaarInput) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isAlreadyVerified || isVerified {
                    verifiedBanner(
                        text: "Aadhaar Verified",
                        detail: maskAadhaar(aadhaarInput.isEmpty ? (existingAadhaar ?? "") : aadhaarInput)
                    )                } else {

                    // MARK: Step 1 — Enter number
                    CardView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Aadhaar Number")
                                    .foregroundStyle(Color.theme.textPrimary)
                                Spacer()
                                TextField("12-digit number", text: $aadhaarInput)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(Color.theme.primaryAccent)
                                    .onChange(of: aadhaarInput) { _, v in
                                        aadhaarInput = String(v.filter { $0.isNumber }.prefix(12))
                                    }
                            }
                            .padding(16)

                            if !aadhaarInput.isEmpty {
                                Divider().padding(.horizontal, 16)
                                HStack {
                                    Image(systemName: isValidFormat ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(isValidFormat ? Color.theme.success : Color.theme.danger)
                                    Text(isValidFormat ? "Valid Aadhaar number" : "Invalid — must be 12 digits")
                                        .font(.caption)
                                        .foregroundStyle(isValidFormat ? Color.theme.success : Color.theme.danger)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // MARK: Confirm button
                    Button {
                        Task { await saveAadhaar() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Confirm Aadhaar")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidFormat ? Color.theme.primaryAccent : Color.gray.opacity(0.2))
                    .foregroundStyle(isValidFormat ? Color.theme.primaryText : Color.theme.textSecondary)
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    .disabled(!isValidFormat || isSaving)

                    // MARK: Step 2 — Auto-fill helpers (secondary)
                    VStack(spacing: 10) {
                        Text("Or auto-fill from your documents")
                            .font(.caption)
                            .foregroundStyle(Color.theme.textSecondary)

                        if let docURL = uploadedDocURL, !docURL.isEmpty {
                            Button {
                                Task { await extractFromUploadedDoc(url: docURL) }
                            } label: {
                                if isExtracting {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(Color.theme.primaryAccent)
                                        Text("Extracting...")
                                            .font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Label("Extract from Uploaded Doc", systemImage: "doc.text.magnifyingglass")
                                        .font(.subheadline).fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 12)
                            .background(Color.theme.cardBackground)
                            .foregroundStyle(Color.theme.primaryAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.primaryAccent.opacity(0.4), lineWidth: 1))
                            .padding(.horizontal, 16)
                            .disabled(isExtracting)
                        }

                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan Aadhaar Card", systemImage: "camera.fill")
                                .font(.subheadline).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 12)
                        .background(Color.theme.cardBackground)
                        .foregroundStyle(Color.theme.primaryAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.primaryAccent.opacity(0.4), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    if let error = scanError {
                        resultCard(success: false, title: "Could Not Extract", detail: error)
                    }
                }
            }
            .padding(.top, 8)
        }
        .onAppear { aadhaarInput = existingAadhaar ?? "" }
        .fullScreenCover(isPresented: $showScanner) {
            CardScannerView(documentType: .aadhaar) { result in
                showScanner = false
                handleScanResult(result)
            }
            .ignoresSafeArea()
        }
    }

    private func extractFromUploadedDoc(url: String) async {
        isExtracting = true
        scanError = nil
        let result = await DocumentOCRExtractor.extractNumber(from: url, type: .aadhaar)
        await MainActor.run {
            isExtracting = false
            handleScanResult(result)
        }
    }

    private func handleScanResult(_ result: OCRScanResult?) {
        guard let result else {
            scanError = "Could not read the document. Try scanning the card instead."
            return
        }
        if result.extractedNumber.isEmpty {
            scanError = "Aadhaar number not found. Please enter manually."
        } else {
            aadhaarInput = result.extractedNumber
            scanError = nil
        }
    }

    private func saveAadhaar() async {
        isSaving = true
        do {
            try await SupabaseManager.shared.saveAadhaarVerification(
                aadhaarNumber: aadhaarInput, refId: nil, verified: true
            )
            isVerified = true
            onVerified()
        } catch {
            scanError = "Failed to save: \(error.localizedDescription)"
        }
        isSaving = false
    }

    private func maskAadhaar(_ number: String) -> String {
        guard number.count == 12 else { return number }
        return "XXXX XXXX \(number.suffix(4))"
    }
}

// MARK: - Shared Helpers

private func verifiedBanner(text: String, detail: String) -> some View {
    HStack(spacing: 14) {
        Image(systemName: "checkmark.seal.fill")
            .font(.largeTitle)
            .foregroundStyle(Color.theme.success)
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.headline)
                .foregroundStyle(Color.theme.success)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
        }
        Spacer()
    }
    .padding(16)
    .background(Color.theme.successBackground)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal, 16)
}

private func resultCard(success: Bool, title: String, detail: String) -> some View {
    HStack(spacing: 12) {
        Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(success ? Color.theme.success : Color.theme.danger)
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(success ? Color.theme.success : Color.theme.danger)
            if !detail.isEmpty {
                Text(detail).font(.caption).foregroundStyle(Color.theme.textSecondary)
            }
        }
        Spacer()
    }
    .padding(14)
    .background(success ? Color.theme.successBackground : Color.theme.dangerBackground)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal, 16)
}
