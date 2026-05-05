

import SwiftUI
import LocalAuthentication

// MARK: - View Model

@Observable
final class LoginViewModel {
    var email: String = ""
    var password: String = ""
    var isSubmitting: Bool = false
    var errorMessage: String? = nil
    var isMagicLinkSent: Bool = false

    @MainActor
    func login(authManager: AuthManager) async {
        isSubmitting = true
        errorMessage = nil

        do {
            try await SupabaseManager.shared.signIn(email: email, password: password)
            UserDefaults.standard.set(email, forKey: "lastLoggedInEmail")
            await authManager.checkSession()
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
        isSubmitting = false
    }

    @MainActor
    func tryBiometricLogin(authManager: AuthManager) async {
        guard UserDefaults.standard.bool(forKey: "useBiometrics") else { return }

        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Access your account")
                if success {
                    await authManager.checkSession()
                }
            } catch {
                print("Biometric login failed: \(error)")
            }
        }
    }
}

// MARK: - Views

struct LoginView: View {
    @Binding var path: NavigationPath
    var viewModel: LoginViewModel
    @Environment(AuthManager.self) private var authManager

    var isFormValid: Bool {
        return !viewModel.email.isEmpty && viewModel.email.contains("@") && !viewModel.password.isEmpty
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 24) {

                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.theme.primaryAccent)
                        .padding(.top, 40)

                    Text("Welcome Back")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Sign in to your account to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                    VStack(spacing: 0) {
                        TextField("Email Address", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding()

                        Divider().padding(.horizontal)

                        SecureField("Password", text: $viewModel.password)
                            .padding()
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task {
                            await viewModel.login(authManager: authManager)
                        }
                    } label: {
                        HStack {
                            if viewModel.isSubmitting {
                                ProgressView().tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text("Login")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.theme.primaryAccent : Color.gray.opacity(0.3))
                        .foregroundColor(isFormValid ? .white : .secondary)
                        .clipShape(Capsule())
                    }
                    .disabled(viewModel.isSubmitting || !isFormValid)
                    .padding(.horizontal)

                    Button {
                        path.append(OnboardingRoute.signUpBasicDetails)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            Text("Sign Up")
                                .fontWeight(.bold)
                                .foregroundColor(Color.theme.primaryAccent)
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 8)

                Spacer()
            }
        }
        .dismissKeyboardOnTap()
        .background(Color.theme.appBackground.ignoresSafeArea())
        .onAppear {
            if viewModel.email.isEmpty {
                viewModel.email = UserDefaults.standard.string(forKey: "lastLoggedInEmail") ?? ""
            }
            Task {
                await viewModel.tryBiometricLogin(authManager: authManager)
            }
        }
    }
}
