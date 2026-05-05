

import SwiftUI
import LocalAuthentication
import Auth
import Supabase

@Observable
final class SetPasswordViewModel {
    var password = ""
    var confirmPassword = ""
    var enableBiometrics = false
    var isSubmitting = false
    var errorMessage: String?
    var syncProgress: String = ""

    var isFormValid: Bool {
        password.count >= 6 && password == confirmPassword
    }

    @MainActor
    func verifyBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Enable biometric login for CredFlow Go")
                return success
            } catch {
                self.errorMessage = "Biometric verification failed: \(error.localizedDescription)"
                return false
            }
        } else {
            self.errorMessage = "Biometrics not available on this device."
            return false
        }
    }

    @MainActor
    func finalizeSetup(authManager: AuthManager) async {
        isSubmitting = true
        errorMessage = nil
        syncProgress = "Setting password..."
        print("🚀 Starting Finalize Setup")

        do {

            print("🔑 Updating password...")
            try await SupabaseManager.shared.updatePassword(password: password)

            if enableBiometrics {
                print("🧬 Enabling biometrics...")
                UserDefaults.standard.set(true, forKey: "useBiometrics")
            }

            print("👤 Fetching user metadata...")
            let session = try await SupabaseManager.shared.client.auth.session
            let meta = session.user.userMetadata
            print("📝 Metadata found: \(meta)")

            let fullName = meta["full_name"]?.stringValue ?? ""
            let mobile = meta["mobile"]?.stringValue ?? ""
            let dob = meta["dob"]?.stringValue
            let accHolder = meta["acc_holder"]?.stringValue ?? fullName
            let accNumber = meta["acc_number"]?.stringValue ?? ""
            let ifsc = meta["ifsc"]?.stringValue ?? ""
            let branch = meta["branch"]?.stringValue.flatMap { Branch(rawValue: $0) }

            syncProgress = "Syncing profile..."

            var profile = BorrowerProfile(mobile: mobile)
            profile.fullName = fullName
            profile.email = session.user.email
            profile.dob = (dob?.isEmpty == false) ? dob : nil
            profile.accountHolderName = accHolder
            profile.bankAccountNumber = accNumber
            profile.ifscCode = ifsc
            profile.branch = branch
            profile.creditScore = 750

            print("📤 Creating borrower profile...")
            try await SupabaseManager.shared.createBorrower(profile: profile)

            syncProgress = "Uploading documents..."
            print("📄 Syncing documents...")
            await uploadStoredDocs()

            print("✅ Updating user status to Verified...")
            try await SupabaseManager.shared.updateUserStatus(to: "Verified")

            syncProgress = "Finalizing..."
            print("🔄 Refreshing session...")

            await authManager.checkSession()
            print("✨ Setup complete!")

        } catch {
            print("🚨 SETUP ERROR: \(error)")
            errorMessage = "Setup failed: \(error.localizedDescription)"
        }
        isSubmitting = false
    }

    private func uploadStoredDocs() async {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let docDir = paths.first else { 
            print("❌ Doc directory not found")
            return 
        }

        let files = [
            ("temp_id.dat", "PAN"),
            ("temp_addr.dat", "Address"),
            ("temp_income.dat", "Income")
        ]

        for (fileName, type) in files {
            let url = docDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                if let data = try? Data(contentsOf: url) {
                    print("📤 Uploading stored doc: \(type)")
                    do {
                        try await SupabaseManager.shared.uploadDocumentAndUpdateTable(
                            docType: type,
                            data: data,
                            isPDF: false
                        )
                        try? FileManager.default.removeItem(at: url)
                    } catch {
                        print("⚠️ Failed to upload stored \(type): \(error)")
                    }
                }
            } else {
                print("ℹ️ No temp file for \(type)")
            }
        }
    }
}

struct SetPasswordView: View {
    @State private var viewModel = SetPasswordViewModel()
    @Environment(AuthManager.self) private var authManager
    @State private var showKYCStep = false

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.theme.primaryAccent)

                    Text("Secure Your Account")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Set a password to log in next time and enable biometric access for faster entry.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                if viewModel.isSubmitting {
                    HStack(spacing: 8) {
                        ProgressView().tint(Color.theme.primaryAccent)
                        Text(viewModel.syncProgress)
                            .font(.caption)
                            .foregroundColor(Color.theme.primaryAccent)
                    }
                }

                if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                VStack(spacing: 0) {
                    SecureField("New Password", text: $viewModel.password)
                        .padding()

                    Divider().padding(.horizontal)

                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .padding()
                }
                .cardStyle()
                .padding(.horizontal)

                VStack(spacing: 0) {
                    Toggle(isOn: $viewModel.enableBiometrics) {
                        HStack {
                            Image(systemName: "faceid")
                            Text("Enable Biometrics")
                        }
                    }
                    .padding()
                    .onChange(of: viewModel.enableBiometrics) { oldValue, newValue in
                        if newValue {
                            Task {
                                let success = await viewModel.verifyBiometrics()
                                if !success {
                                    viewModel.enableBiometrics = false
                                }
                            }
                        }
                    }
                }
                .cardStyle()
                .padding(.horizontal)

                Button {
                    Task {
                        await viewModel.finalizeSetup(authManager: authManager)
                        if viewModel.errorMessage == nil {
                            showKYCStep = true
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.white)
                                .padding(.trailing, 8)
                        }
                        Text(viewModel.isSubmitting ? viewModel.syncProgress : "Finish Setup")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isFormValid ? Color.theme.primaryAccent : Color.gray.opacity(0.3))
                    .foregroundColor(viewModel.isFormValid ? .white : .secondary)
                    .clipShape(Capsule())
                }
                .disabled(!viewModel.isFormValid || viewModel.isSubmitting)
                .padding(.horizontal)

                Button("Sign Out") {
                    Task {
                        try? await SupabaseManager.shared.signOut()
                        authManager.signOut()
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .dismissKeyboardOnTap()
        .background(Color.theme.appBackground.ignoresSafeArea())
        .sheet(isPresented: $showKYCStep, onDismiss: {

            Task { await authManager.checkSession() }
        }) {
            SignUpKYCView()
        }
    }
}
