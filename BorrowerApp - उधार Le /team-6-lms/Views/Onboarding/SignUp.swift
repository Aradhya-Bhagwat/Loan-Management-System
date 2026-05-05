

import SwiftUI
import VisionKit
import UniformTypeIdentifiers

// MARK: - View Model

@Observable
final class SignUpViewModel {

    var fullName: String = ""
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    var email: String = ""
    var mobile: String = ""
    var branch: Branch = .north
    var isOTPSent: Bool = false

    static let branches = Branch.allCases

    var identityDocData: Data? = nil
    var addressDocData: Data? = nil
    var incomeDocData: Data? = nil

    var identityProofScanned: Bool { identityDocData != nil }
    var addressProofScanned: Bool { addressDocData != nil }
    var incomeProofScanned: Bool { incomeDocData != nil }

    var bankAccountNumber: String = ""
    var ifscCode: String = ""
    var accountHolderName: String = ""
    var isConsentGiven: Bool = false

    var isSubmitting: Bool = false
    var errorMessage: String? = nil

    @MainActor
    func startSignUpFlow() async -> Bool {
        isSubmitting = true
        errorMessage = nil
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dobString = formatter.string(from: dateOfBirth)

            let bankDetails = [
                "acc_holder": accountHolderName,
                "acc_number": bankAccountNumber,
                "ifsc": ifscCode
            ]

            saveDocsToDisk()

            try await SupabaseManager.shared.signUpWithMagicLink(
                email: email,
                fullName: fullName,
                mobile: mobile,
                dob: dobString,
                bankDetails: bankDetails,
                branch: branch.rawValue
            )
            isOTPSent = true
            isSubmitting = false
            return true
        } catch {
            isSubmitting = false
            errorMessage = "Failed to start sign up: \(error.localizedDescription)"
            return false
        }
    }

    private func saveDocsToDisk() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let docDir = paths.first {
            if let data = identityDocData { try? data.write(to: docDir.appendingPathComponent("temp_id.dat")) }
            if let data = addressDocData { try? data.write(to: docDir.appendingPathComponent("temp_addr.dat")) }
            if let data = incomeDocData { try? data.write(to: docDir.appendingPathComponent("temp_income.dat")) }
        }
    }

    @MainActor
    func markDocumentScanned(type: DocumentType, data: Data) {
        switch type {
        case .identity: identityDocData = data
        case .address: addressDocData = data
        case .income: incomeDocData = data
        }
    }

    enum DocumentType: Identifiable {
        var id: Self { self }
        case identity, address, income
    }
}

// MARK: - Views

struct SignUpPhase1View: View {
    @Binding var path: NavigationPath
    var viewModel: SignUpViewModel

    var isFormValid: Bool {
        !viewModel.fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        viewModel.email.contains("@") &&
        viewModel.mobile.count >= 10
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Basic Details")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.theme.textPrimary)
                    Text("Enter your registration details below")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)

                VStack(spacing: 0) {
                    HStack {
                        Text("Full Name")
                            .foregroundColor(Color.theme.textPrimary)
                        Spacer()
                        TextField("", text: Bindable(viewModel).fullName, prompt: Text("e.g. John Doe").foregroundColor(Color.gray.opacity(0.6)))
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(Color.theme.primaryAccent)
                    }
                    .padding(16)

                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                    DatePicker("Date of Birth", selection: Bindable(viewModel).dateOfBirth, in: ...Calendar.current.date(byAdding: .year, value: -18, to: Date())!, displayedComponents: .date)
                        .tint(Color.theme.primaryAccent)
                        .padding(16)

                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                    HStack {
                        Text("Mobile")
                            .foregroundColor(Color.theme.textPrimary)
                        Spacer()
                        TextField("", text: Bindable(viewModel).mobile, prompt: Text("10-digit number").foregroundColor(Color.gray.opacity(0.6)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(Color.theme.primaryAccent)
                    }
                    .padding(16)

                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                    HStack {
                        Text("Email")
                            .foregroundColor(Color.theme.textPrimary)
                        Spacer()
                        TextField("", text: Bindable(viewModel).email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(Color.theme.primaryAccent)
                            .placeholder(when: viewModel.email.isEmpty) {
                                Text("e.g. email@domain.com")
                                    .foregroundColor(Color.gray.opacity(0.5))
                                    .multilineTextAlignment(.trailing)
                            }
                    }
                    .padding(16)
                }
                .cardStyle()
                .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    HStack {
                        Text("Bank Branch")
                            .foregroundColor(Color.theme.textPrimary)
                        Spacer()
                        Picker("Branch", selection: Bindable(viewModel).branch) {
                            ForEach(SignUpViewModel.branches, id: \.self) { branch in
                                Text(branch.rawValue).tag(branch)
                            }
                        }
                        .tint(Color.theme.primaryAccent)
                        .pickerStyle(.menu)
                        .lineLimit(1)
                        .dismissKeyboardOnPickerTap()
                    }
                    .padding(16)
                }
                .cardStyle()
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Button {
                    path.append(OnboardingRoute.signUpDocuments)
                } label: {
                    Text("Continue")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.theme.primaryAccent : Color.gray.opacity(0.2))
                        .foregroundColor(isFormValid ? Color.theme.primaryText : Color.theme.textSecondary)
                        .clipShape(Capsule())
                }
                .disabled(!isFormValid)
                .padding(.horizontal, 16)
                .padding(.top, 24)

                Button {
                    path.removeLast(path.count)
                    path.append(OnboardingRoute.login)
                } label: {
                    Text("Already have an account? ")
                        .foregroundColor(.secondary) +
                    Text("Login")
                        .fontWeight(.bold)
                        .foregroundColor(Color.theme.primaryAccent)
                }
                .font(.subheadline)
                .padding(.top, 16)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.theme.appBackground.ignoresSafeArea())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

struct SignUpPhase2View: View {
    @Binding var path: NavigationPath
    var viewModel: SignUpViewModel

    @State private var showActionSheet = false
    @State private var showScanner = false
    @State private var showFileImporter = false
    @State private var targetScanType: SignUpViewModel.DocumentType? = nil
    @State private var isUploading = false

    var allScanned: Bool {
        viewModel.identityProofScanned && viewModel.addressProofScanned && viewModel.incomeProofScanned
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Documents Upload")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.theme.textPrimary)
                    Text("Upload your documents via files or scan them directly using VisionKit.")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)

                VStack(spacing: 0) {
                    DocumentTrackerRow(
                        title: "Identity Proof",
                        isScanned: viewModel.identityProofScanned,
                        isUploading: isUploading && targetScanType == .identity,
                        action: { startActionSelection(for: .identity) }
                    )

                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                    DocumentTrackerRow(
                        title: "Address Proof",
                        isScanned: viewModel.addressProofScanned,
                        isUploading: isUploading && targetScanType == .address,
                        action: { startActionSelection(for: .address) }
                    )

                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                    DocumentTrackerRow(
                        title: "Income Documents",
                        isScanned: viewModel.incomeProofScanned,
                        isUploading: isUploading && targetScanType == .income,
                        action: { startActionSelection(for: .income) }
                    )
                }
                .cardStyle()
                .padding(.horizontal, 16)

                VStack(spacing: 16) {
                    Button {
                        path.append(OnboardingRoute.signUpConsent)
                    } label: {
                        Text("Continue to Account Details")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(allScanned ? Color.theme.primaryAccent : Color.gray.opacity(0.2))
                            .foregroundColor(allScanned ? Color.theme.primaryText : Color.theme.textSecondary)
                            .clipShape(Capsule())
                    }
                    .disabled(!allScanned)

                    Button {
                        path.append(OnboardingRoute.signUpConsent)
                    } label: {
                        Text("Skip Document Upload")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                            .padding(.bottom, 2)
                    }
                    .foregroundColor(Color.theme.primaryAccent)

                    Text("You can upload these docs in the profile section as well.")
                        .font(.caption)
                        .foregroundColor(Color.theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.theme.appBackground.ignoresSafeArea())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .alert("Upload Document", isPresented: $showActionSheet) {
            Button("Camera Scan") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showScanner = true
                }
            }
            Button("Choose from Files") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showFileImporter = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { pdfData, isPDF in
                if let type = targetScanType {
                    Task { await handleUpload(data: pdfData, isPDF: isPDF, type: type) }
                }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .jpeg, .png]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url), let type = targetScanType {
                    let isPDF = url.pathExtension.lowercased() == "pdf"
                    Task { await handleUpload(data: data, isPDF: isPDF, type: type) }
                }
            case .failure(let error):
                print("Failed to import file: \(error)")
            }
        }
    }

    private func handleUpload(data: Data, isPDF: Bool, type: SignUpViewModel.DocumentType) async {
        viewModel.markDocumentScanned(type: type, data: data)
    }

    private func startActionSelection(for type: SignUpViewModel.DocumentType) {
        targetScanType = type
        showActionSheet = true
    }
}

struct DocumentTrackerRow: View {
    let title: String
    let isScanned: Bool
    let isUploading: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(Color.theme.textPrimary)
            Spacer()
            if isUploading {
                ProgressView().tint(Color.theme.primaryAccent)
            } else if isScanned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.theme.success)
                    .font(.title3)
            } else {
                Button(action: action) {
                    Text("Upload")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.theme.primaryAccent)
                        .foregroundColor(Color.theme.primaryText)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
    }
}

struct SignUpPhase3View: View {
    @Binding var path: NavigationPath
    var viewModel: SignUpViewModel
    @Environment(AuthManager.self) private var authManager
    @State private var showTermsSheet = false

    var isFormValid: Bool {
        !viewModel.accountHolderName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !viewModel.bankAccountNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidIFSC &&
        viewModel.isConsentGiven
    }

    private var isValidIFSC: Bool {
        viewModel.branch.isValidIFSC(viewModel.ifscCode)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isOTPSent {

                    VStack(spacing: 32) {
                        Spacer(minLength: 40)

                        ZStack {
                            Circle()
                                .fill(Color.theme.success.opacity(0.1))
                                .frame(width: 120, height: 120)

                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color.theme.success)
                        }

                        VStack(spacing: 12) {
                            Text("Email Verification Sent!")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("We've sent a secure magic link to")
                                .foregroundColor(.secondary)

                            Text(viewModel.email)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.theme.primaryAccent)

                            Text("Click the link in your email to verify your account and set your password.")
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)
                                .padding(.top, 8)
                        }

                        VStack(spacing: 16) {
                            Button {
                                path.removeLast(path.count)
                            } label: {
                                Text("Return to Welcome")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.theme.primaryAccent)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }

                            Text("Did't receive an email? Check your spam folder or try again.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 24)

                        Spacer()
                    }
                    .padding(24)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bank Details")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color.theme.textPrimary)
                        Text("Finalize your account setup")
                            .font(.subheadline)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }

                    VStack(spacing: 0) {
                        HStack {
                            Text("Acc Holder")
                                .foregroundColor(Color.theme.textPrimary)
                            Spacer()
                            TextField("", text: Bindable(viewModel).accountHolderName, prompt: Text("On Card").foregroundColor(Color.gray.opacity(0.6)))
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Color.theme.primaryAccent)
                        }
                        .padding(16)

                        Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                        HStack {
                            Text("Acc Number")
                                .foregroundColor(Color.theme.textPrimary)
                            Spacer()
                            TextField("", text: Bindable(viewModel).bankAccountNumber, prompt: Text("12-16 digits").foregroundColor(Color.gray.opacity(0.6)))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Color.theme.primaryAccent)
                        }
                        .padding(16)

                        Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("IFSC Code")
                                    .foregroundColor(Color.theme.textPrimary)
                                Spacer()
                                TextField("", text: Bindable(viewModel).ifscCode, prompt: Text(viewModel.branch.suggestedIFSC).foregroundColor(Color.gray.opacity(0.6)))
                                    .textInputAutocapitalization(.characters)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(Color.theme.primaryAccent)
                                    .onChange(of: viewModel.ifscCode) { _, v in
                                        viewModel.ifscCode = v.uppercased()
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)

                            if !viewModel.ifscCode.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: isValidIFSC ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.caption2)
                                    Text(isValidIFSC
                                         ? "Valid for \(viewModel.branch.displayName) branch"
                                         : "Must start with \(viewModel.branch.ifscPrefix) for \(viewModel.branch.displayName)")
                                        .font(.caption2)
                                }
                                .foregroundStyle(isValidIFSC ? Color.theme.success : Color.theme.danger)
                                .padding(.horizontal, 16)
                            }

                            Button {
                                viewModel.ifscCode = viewModel.branch.suggestedIFSC
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.caption2)
                                    Text("Use suggested: \(viewModel.branch.suggestedIFSC)")
                                        .font(.caption2).fontWeight(.medium)
                                }
                                .foregroundStyle(Color.theme.primaryAccent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: viewModel.isConsentGiven ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(viewModel.isConsentGiven ? Color.theme.success : Color.theme.textSecondary.opacity(0.4))
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("I agree to the Terms & Conditions and Data Privacy Policy")
                                    .font(.subheadline)
                                    .foregroundColor(Color.theme.textPrimary)

                                Button {
                                    showTermsSheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.text")
                                            .font(.caption)
                                        Text("Read Terms & Conditions")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(Color.theme.primaryAccent)
                                }
                            }
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if viewModel.isConsentGiven {
                                viewModel.isConsentGiven = false
                            } else {
                                showTermsSheet = true
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Button {
                        Task {
                            await viewModel.startSignUpFlow()
                        }
                    } label: {
                        HStack {
                            if viewModel.isSubmitting {
                                ProgressView().tint(Color.white)
                            } else {
                                Text("Complete Registration")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.theme.primaryAccent : Color.gray.opacity(0.2))
                        .foregroundColor(isFormValid ? Color.theme.primaryText : Color.theme.textSecondary)
                        .clipShape(Capsule())
                    }
                    .disabled(viewModel.isSubmitting || !isFormValid)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.theme.appBackground.ignoresSafeArea())
        .dismissKeyboardOnTap()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsAndConditionsSheet(
                onAgree: {
                    viewModel.isConsentGiven = true
                    showTermsSheet = false
                },
                onDecline: {
                    viewModel.isConsentGiven = false
                    showTermsSheet = false
                }
            )
        }
    }
}

// MARK: - Terms & Conditions Sheet
private struct TermsAndConditionsSheet: View {
    let onAgree: () -> Void
    let onDecline: () -> Void

    @State private var hasScrolledToBottom = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text.fill")
                                    .font(.title2)
                                    .foregroundColor(Color.theme.primaryAccent)
                                Text("Terms & Conditions")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.theme.textPrimary)
                            }
                            Text("Last updated: April 2026")
                                .font(.caption)
                                .foregroundColor(Color.theme.textSecondary)
                        }
                        .padding(.top, 8)

                        Divider()

                        termsSection(
                            number: "1",
                            title: "Acceptance of Terms",
                            content: "By creating an account and using CredFlow Go (\"the App\"), you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions. If you do not agree, you must not use the App."
                        )

                        termsSection(
                            number: "2",
                            title: "Eligibility",
                            content: "You must be at least 18 years of age and a resident of India to use this service. By registering, you confirm that all information provided during sign-up is accurate and complete. You agree to update your information promptly if any changes occur."
                        )

                        termsSection(
                            number: "3",
                            title: "Loan Application & Processing",
                            content: "Submitting a loan application does not guarantee approval. All applications are subject to credit assessment, income verification, and internal risk evaluation. The Bank reserves the right to approve or reject any application at its sole discretion. Interest rates, processing fees, and loan terms are determined based on your credit profile and applicable RBI guidelines."
                        )

                        termsSection(
                            number: "4",
                            title: "Credit Score Authorization",
                            content: "By applying for a loan, you explicitly authorize CredFlow Go and its partner financial institutions to access your credit information from CIBIL, Experian, Equifax, or other credit bureaus. This inquiry may be recorded as a hard or soft pull on your credit report."
                        )

                        termsSection(
                            number: "5",
                            title: "Data Privacy & GDPR Compliance",
                            content: "We collect and process personal data including but not limited to: your name, date of birth, contact information, financial documents, bank details, and employment information. Your data is encrypted at rest and in transit using industry-standard AES-256 encryption. We will never sell your personal data to third parties. Data is retained for the duration of your account plus 7 years as required by financial regulations. You have the right to request data export, correction, or deletion (subject to legal retention requirements) by contacting our Data Protection Officer."
                        )

                        termsSection(
                            number: "6",
                            title: "Repayment Obligations",
                            content: "Upon loan disbursement, you agree to make timely repayments as per the EMI schedule. Late payments may attract penalty charges as specified in your loan agreement. Persistent defaults may result in legal action and negative reporting to credit bureaus, which will adversely affect your credit score."
                        )

                        termsSection(
                            number: "7",
                            title: "Document Authenticity",
                            content: "You certify that all documents uploaded (identity proof, address proof, income documents, bank statements) are genuine and unaltered. Submission of fraudulent, forged, or misleading documents is a criminal offense and will result in immediate account termination and potential legal proceedings."
                        )

                        termsSection(
                            number: "8",
                            title: "Account Security",
                            content: "You are responsible for maintaining the confidentiality of your account credentials. Notify us immediately of any unauthorized access. We are not liable for losses resulting from your failure to safeguard your login information."
                        )

                        termsSection(
                            number: "9",
                            title: "Limitation of Liability",
                            content: "CredFlow Go is provided \"as is\" without warranties of any kind. We shall not be liable for any indirect, incidental, or consequential damages arising from the use of this service. Our total liability shall not exceed the fees paid by you in the preceding 12 months."
                        )

                        termsSection(
                            number: "10",
                            title: "Governing Law",
                            content: "These Terms are governed by the laws of India. Any disputes shall be subject to the exclusive jurisdiction of the courts in Mumbai, Maharashtra."
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                            Link(destination: URL(string: "https://www.rbi.org.in/Scripts/FAQView.aspx?Id=92")!) {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.caption)
                                    Text("View RBI Fair Practices Code")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(Color.theme.primaryAccent)
                            }
                            .padding(.vertical, 4)
                        }

                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    hasScrolledToBottom = true
                                }
                            }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 12) {
                    Divider()

                    if !hasScrolledToBottom {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down")
                                .font(.caption2.bold())
                            Text("Scroll down to read all terms")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Color.theme.textSecondary)
                        .padding(.top, 4)
                    }

                    Button(action: onAgree) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                            Text("Agree & Continue")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasScrolledToBottom ? Color.theme.primaryAccent : Color.gray.opacity(0.2))
                        .foregroundColor(hasScrolledToBottom ? Color.theme.primaryText : Color.theme.textSecondary)
                        .clipShape(Capsule())
                    }
                    .disabled(!hasScrolledToBottom)

                    Button(action: onDecline) {
                        Text("Decline")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .background(Color.theme.cardBackground)
            }
            .background(Color.theme.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDecline()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.theme.textSecondary)
                    }
                }
            }
        }
    }

    private func termsSection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(number)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.theme.primaryAccent)
                    .clipShape(Circle())
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.theme.textPrimary)
            }
            Text(content)
                .font(.footnote)
                .foregroundColor(Color.theme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
