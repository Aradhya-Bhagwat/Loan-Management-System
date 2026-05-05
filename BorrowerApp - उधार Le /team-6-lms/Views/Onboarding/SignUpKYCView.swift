import SwiftUI
import VisionKit

struct SignUpKYCView: View {
    @Environment(\.dismiss) var dismiss

    @State private var panInput = ""
    @State private var aadhaarInput = ""

    @State private var panVerified = false
    @State private var aadhaarVerified = false

    @State private var isSavingPAN = false
    @State private var isSavingAadhaar = false

    @State private var showPANScanner = false
    @State private var showAadhaarScanner = false

    @State private var errorMessage: String? = nil

    var isValidPAN: Bool { KYCValidator.isValidPAN(panInput) }
    var isValidAadhaar: Bool { KYCValidator.isValidAadhaar(aadhaarInput) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.theme.primaryAccent)
                        Text("Verify Your Identity")
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(Color.theme.textPrimary)
                        Text("Scan your PAN and Aadhaar cards to complete KYC. You can skip and do this later from your profile.")
                            .font(.subheadline)
                            .foregroundStyle(Color.theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 32)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.theme.danger)
                            .padding(.horizontal)
                    }

                    // MARK: PAN Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("PAN Verification", systemImage: "doc.text.fill")
                                .font(.headline)
                                .foregroundStyle(Color.theme.textPrimary)
                            Spacer()
                            if panVerified {
                                Label("Verified", systemImage: "checkmark.seal.fill")
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundStyle(Color.theme.success)
                            }
                        }

                        if panVerified {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.theme.success)
                                Text(panInput.masked()).foregroundStyle(Color.theme.textSecondary)
                            }
                            .font(.subheadline)
                        } else {

                            Button {
                                showPANScanner = true
                            } label: {
                                Label("Scan PAN Card", systemImage: "camera.fill")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.theme.primaryAccent)
                                    .foregroundStyle(Color.theme.primaryText)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            HStack {
                                TextField("Or enter PAN manually (ABCDE1234F)", text: $panInput)
                                    .textInputAutocapitalization(.characters)
                                    .onChange(of: panInput) { _, v in
                                        panInput = String(v.uppercased().prefix(10))
                                    }
                                    .padding(12)
                                    .background(Color.gray.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    Task { await savePAN() }
                                } label: {
                                    if isSavingPAN {
                                        ProgressView().tint(.white).frame(width: 60)
                                    } else {
                                        Text("Confirm")
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.theme.primaryText)
                                            .frame(width: 60)
                                    }
                                }
                                .padding(.vertical, 12)
                                .background(isValidPAN ? Color.theme.primaryAccent : Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .disabled(!isValidPAN || isSavingPAN)
                            }

                            if !panInput.isEmpty {
                                Label(
                                    isValidPAN ? "Valid PAN format" : "Invalid format — must be ABCDE1234F",
                                    systemImage: isValidPAN ? "checkmark.circle.fill" : "xmark.circle.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(isValidPAN ? Color.theme.success : Color.theme.danger)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // MARK: Aadhaar Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Aadhaar Verification", systemImage: "person.text.rectangle.fill")
                                .font(.headline)
                                .foregroundStyle(Color.theme.textPrimary)
                            Spacer()
                            if aadhaarVerified {
                                Label("Verified", systemImage: "checkmark.seal.fill")
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundStyle(Color.theme.success)
                            }
                        }

                        if aadhaarVerified {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.theme.success)
                                Text("XXXX XXXX \(aadhaarInput.suffix(4))")
                                    .foregroundStyle(Color.theme.textSecondary)
                            }
                            .font(.subheadline)
                        } else {

                            Button {
                                showAadhaarScanner = true
                            } label: {
                                Label("Scan Aadhaar Card", systemImage: "camera.fill")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.theme.primaryAccent)
                                    .foregroundStyle(Color.theme.primaryText)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            HStack {
                                TextField("Or enter 12-digit Aadhaar number", text: $aadhaarInput)
                                    .keyboardType(.numberPad)
                                    .onChange(of: aadhaarInput) { _, v in
                                        aadhaarInput = String(v.filter { $0.isNumber }.prefix(12))
                                    }
                                    .padding(12)
                                    .background(Color.gray.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    Task { await saveAadhaar() }
                                } label: {
                                    if isSavingAadhaar {
                                        ProgressView().tint(.white).frame(width: 70)
                                    } else {
                                        Text("Confirm")
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.theme.primaryText)
                                            .frame(width: 70)
                                    }
                                }
                                .padding(.vertical, 12)
                                .background(isValidAadhaar ? Color.theme.primaryAccent : Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .disabled(!isValidAadhaar || isSavingAadhaar)
                            }

                            if !aadhaarInput.isEmpty {
                                Label(
                                    isValidAadhaar ? "Valid Aadhaar number" : "Invalid — must be 12 digits",
                                    systemImage: isValidAadhaar ? "checkmark.circle.fill" : "xmark.circle.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(isValidAadhaar ? Color.theme.success : Color.theme.danger)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Text(panVerified || aadhaarVerified ? "Continue" : "Skip for Now")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(panVerified || aadhaarVerified ? Color.theme.primaryAccent : Color.gray.opacity(0.15))
                                .foregroundStyle(panVerified || aadhaarVerified ? Color.theme.primaryText : Color.theme.textSecondary)
                                .clipShape(Capsule())
                        }

                        if !(panVerified || aadhaarVerified) {
                            Text("You can verify later from Profile → Verify KYC")
                                .font(.caption)
                                .foregroundStyle(Color.theme.textSecondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.theme.appBackground.ignoresSafeArea())
            .navigationTitle("KYC Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { dismiss() }
                        .foregroundStyle(Color.theme.textSecondary)
                }
            }
            .fullScreenCover(isPresented: $showPANScanner) {
                CardScannerView(documentType: .pan) { result in
                    showPANScanner = false
                    if let number = result?.extractedNumber, !number.isEmpty {
                        panInput = number

                        if KYCValidator.isValidPAN(number) {
                            Task { await savePAN() }
                        }
                    } else {
                        errorMessage = "PAN not detected. Please enter manually."
                    }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showAadhaarScanner) {
                CardScannerView(documentType: .aadhaar) { result in
                    showAadhaarScanner = false
                    if let number = result?.extractedNumber, !number.isEmpty {
                        aadhaarInput = number

                        if KYCValidator.isValidAadhaar(number) {
                            Task { await saveAadhaar() }
                        }
                    } else {
                        errorMessage = "Aadhaar number not detected. Please enter manually."
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Save Actions

    private func savePAN() async {
        isSavingPAN = true
        errorMessage = nil
        do {
            try await SupabaseManager.shared.savePANVerification(pan: panInput, verified: true)
            panVerified = true
        } catch {
            errorMessage = "Failed to save PAN: \(error.localizedDescription)"
        }
        isSavingPAN = false
    }

    private func saveAadhaar() async {
        isSavingAadhaar = true
        errorMessage = nil
        do {
            try await SupabaseManager.shared.saveAadhaarVerification(
                aadhaarNumber: aadhaarInput, refId: nil, verified: true
            )
            aadhaarVerified = true
        } catch {
            errorMessage = "Failed to save Aadhaar: \(error.localizedDescription)"
        }
        isSavingAadhaar = false
    }
}
