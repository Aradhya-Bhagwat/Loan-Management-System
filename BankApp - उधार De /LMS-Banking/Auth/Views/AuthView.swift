import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit
import Auth

struct AuthView: View {
    @Bindable var authController: AuthViewModel
    
    var body: some View {
        if authController.isPasswordResetRequired {
            AccountSetupView(authController: authController)
        } else {
            LoginView(authController: authController)
        }
    }
}

private struct AccountSetupView: View {
    @Bindable var authController: AuthViewModel
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appGreen.opacity(0.15), Color.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Welcome Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.appGreen.opacity(0.15))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "person.badge.shield.checkmark")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.appGreen)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Welcome to उधार De")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Finish setting up your secure account")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                VStack(spacing: 24) {
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CREATE PASSWORD")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(Color.appGreen)
                            SecureField("Choose a strong password", text: $authController.newPasswordInput)
                        }
                        .padding()
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // Onboarding Security Options
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "faceid")
                                .font(.title3)
                                .foregroundStyle(Color.appGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Biometric Unlock")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Unlock locally with Face ID / Touch ID")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { authController.isBiometricsEnabled },
                                    set: { newValue in
                                        authController.isBiometricsEnabled = newValue
                                        if newValue {
                                            authController.verifyBiometricsNowAndStoreSession()
                                        } else {
                                            authController.clearBiometricSession()
                                        }
                                    }
                                )
                            )
                            .labelsHidden()
                            .tint(Color.appGreen)
                        }

                        Divider()

                        HStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.title3)
                                .foregroundStyle(Color.appGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Google Authenticator (2FA)")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Add an authenticator for safer logins")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if authController.isMfaStatusLoading {
                                ProgressView()
                                    .tint(Color.appGreen)
                            } else if authController.isTotpEnabled {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Color.appGreen)
                                    Text("Enabled")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.appGreen)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.appGreen.opacity(0.12))
                                .clipShape(Capsule())
                            } else {
                                Button("Set up") {
                                    authController.beginTOTPEnrollment()
                                }
                                .buttonStyle(.bordered)
                                .tint(Color.appGreen)
                            }
                        }
                    }
                    .padding()
                    .background(Color.appGreen.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appGreen.opacity(0.1), lineWidth: 1)
                    )
                    
                    if let error = authController.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Button {
                        authController.updatePassword()
                    } label: {
                        HStack {
                            if authController.isLoading {
                                ProgressView().tint(.white).padding(.trailing, 8)
                            }
                            Text(authController.isLoading ? "FINALIZING..." : "COMPLETE SETUP")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.appGreen.opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(authController.isLoading || authController.newPasswordInput.count < 6)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                Text("Secure Institutional Banking Encryption Active")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            authController.refreshMFAStatus()
        }
    }
}

// MARK: - MFA UI

struct MFAChallengeView: View {
    @Bindable var authController: AuthViewModel
    @State private var code: String = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appGreen.opacity(0.15), Color.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.appGreen)

                    Text("Two-Factor Required")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Enter the 6-digit code from your authenticator app to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    TextField("123456", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .padding()
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appGreen.opacity(0.12), lineWidth: 1)
                        )

                    if let error = authController.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.appRed)
                    }

                    Button {
                        authController.completeMFAChallenge(code: code.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        HStack {
                            if authController.isMfaLoading {
                                ProgressView().tint(.white).padding(.trailing, 8)
                            }
                            Text(authController.isMfaLoading ? "VERIFYING..." : "VERIFY & CONTINUE")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.appGreen.opacity(0.25), radius: 10, y: 5)
                    }
                    .disabled(authController.isMfaLoading || code.count < 6)

                    Button(role: .destructive) {
                        authController.logout()
                    } label: {
                        Text("Sign out")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}

struct MFAEnrollmentView: View {
    @Bindable var authController: AuthViewModel
    @State private var code: String = ""
    @State private var showSecret: Bool = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Set up 2FA")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            authController.isPresentingMfaEnrollment = false
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if authController.isMfaLoading && authController.mfaEnrollmentData == nil {
            VStack(spacing: 16) {
                ProgressView()
                Text("Preparing your authenticator setup…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        } else if let totp = authController.mfaEnrollmentData?.totp {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 10) {
                        QRCodeImageView(text: totp.uri)
                            .frame(width: 240, height: 240)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)

                        HStack(spacing: 12) {
                            Button("Open Google Authenticator") {
                                guard let url = URL(string: totp.uri) else { return }
                                if UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                } else {
                                    authController.errorMessage = "No authenticator app found for this link."
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.appGreen)

                            Button("Copy Secret") {
                                UIPasteboard.general.string = totp.secret
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Manual entry")
                            .font(.headline)

                        HStack(spacing: 10) {
                            Text(showSecret ? totp.secret : String(repeating: "•", count: max(8, min(32, totp.secret.count))))
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button(showSecret ? "Hide" : "Show") { showSecret.toggle() }
                                .buttonStyle(.bordered)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Verify")
                            .font(.headline)
                        Text("Enter the 6-digit code below to activate 2FA.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .padding(.bottom, 140)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    TextField("123456", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .padding()
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appGreen.opacity(0.12), lineWidth: 1)
                        )

                    if let error = authController.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.appRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        authController.verifyTOTPEnrollment(code: code.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        HStack {
                            if authController.isMfaLoading {
                                ProgressView().tint(.white).padding(.trailing, 8)
                            }
                            Text(authController.isMfaLoading ? "VERIFYING..." : "ACTIVATE 2FA")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(authController.isMfaLoading || code.count < 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
        } else {
            VStack(spacing: 12) {
                Text("Couldn’t start setup")
                    .font(.headline)
                Text(authController.errorMessage ?? "Please try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
    }
}

private struct QRCodeImageView: View {
    let text: String

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = makeImage(text: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCard)
                .overlay {
                    Text("QR unavailable")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func makeImage(text: String) -> UIImage? {
        let data = Data(text.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up so it renders crisp in SwiftUI
        let transform = CGAffineTransform(scaleX: 12, y: 12)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
