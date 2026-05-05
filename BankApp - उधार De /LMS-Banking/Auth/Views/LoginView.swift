import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @Bindable var authController: AuthViewModel
    @State private var isAnimating = false
    @State private var biometricType: LABiometryType = .none
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [Color.appGreen.opacity(0.15), Color.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Brand Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.appGreen.opacity(0.15))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "shield.checkerboard")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.appGreen)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    
                    VStack(spacing: 4) {
                        let title: String = {
                            if authController.isPasswordResetRequired { return "Set Password" }
                            return "उधार De"
                        }()
                        
                        let subtitle: String = {
                            if authController.isPasswordResetRequired { return "Create your new secure password" }
                            return "Institutional Banking Portal"
                        }()

                        Text(title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .tracking(-0.5)
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }
                    .offset(y: isAnimating ? 0 : 20)
                    .opacity(isAnimating ? 1.0 : 0.0)
                }
                
                if authController.isPasswordResetRequired {
                    passwordResetForm
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    loginForm
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 8) {
                    Text("Secure Encryption Active")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        Text("AES-256")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .padding(.bottom, 20)
                .opacity(isAnimating ? 1.0 : 0.0)
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalDocumentView(title: "Privacy Policy", content: privacyPolicyContent)
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(title: "Terms of Service", content: termsOfServiceContent)
        }
        .onAppear {
            checkBiometricAvailability()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)) {
                isAnimating = true
            }
        }
    }
    
    private var loginForm: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("EMAIL ADDRESS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundStyle(Color.appGreen)
                        .frame(width: 24)
                    
                    TextField("Enter your email", text: $authController.emailInput)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }
                .padding()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appGreen.opacity(0.1), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("PASSWORD")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundStyle(Color.appGreen)
                        .frame(width: 24)
                    
                    SecureField("••••••••", text: $authController.passwordInput)
                }
                .padding()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appGreen.opacity(0.1), lineWidth: 1)
                )
            }
            
            if let error = authController.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.appRed)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            
            Button {
                withAnimation {
                    authController.login()
                }
            } label: {
                HStack {
                    if authController.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 8)
                    }
                    
                    Text(authController.isLoading ? "AUTHENTICATING..." : "SIGN IN")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color.appGreen, Color.appGreen.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.appGreen.opacity(0.3), radius: 10, y: 5)
            }
            .disabled(authController.isLoading)
            .padding(.top, 10)
            
            // GDPR Compliance Links
            VStack(spacing: 8) {
                Text("By signing in, you agree to our")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Button("Privacy Policy") { showPrivacyPolicy = true }
                    Text("&")
                    Button("Terms of Service") { showTerms = true }
                }
                .font(.caption2.bold())
                .tint(Color.appGreen)
            }
            .padding(.top, 10)
            
            // Intentionally no "Login with FaceID" button.
            // Biometrics are used to unlock the app/session only after a successful password + MFA login.
        }
        .padding(.horizontal, 24)
        .offset(y: isAnimating ? 0 : 40)
        .opacity(isAnimating ? 1.0 : 0.0)
    }
    
    private var passwordResetForm: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("NEW PASSWORD")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.appGreen)
                        .frame(width: 24)
                    
                    SecureField("Minimum 8 characters", text: $authController.newPasswordInput)
                }
                .padding()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appGreen.opacity(0.1), lineWidth: 1)
                )
            }
            
            if let error = authController.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.appRed)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button {
                    withAnimation {
                        authController.updatePassword()
                    }
                } label: {
                    HStack {
                        if authController.isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 8)
                        }
                        
                        Text(authController.isLoading ? "UPDATING..." : "UPDATE PASSWORD")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.appGreen, Color.appGreen.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.appGreen.opacity(0.3), radius: 10, y: 5)
                }
                .disabled(authController.isLoading || authController.newPasswordInput.count < 6)
                
                Button("Cancel") {
                    withAnimation {
                        authController.isPasswordResetRequired = false
                        authController.logout()
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }

    // Static content (can be replaced with DB fetch later)
    private var privacyPolicyContent: String {
        """
        <h3>Institutional Privacy Policy</h3>
        <p><strong>Effective Date:</strong> January 1, 2026</p>
        <p>At उधार De Institutional Banking, safeguarding your personal and financial information is our highest priority. This Privacy Policy details how we collect, process, and protect your data in accordance with the General Data Protection Regulation (GDPR) and other applicable financial privacy laws.</p>
        
        <h4>1. Data Collection and Usage</h4>
        <p>We collect personal information (e.g., name, contact details, identification numbers) and financial data (e.g., income, credit history, transaction records) strictly for the purposes of evaluating loan applications, managing accounts, and fulfilling legal and regulatory obligations, such as Know Your Customer (KYC) and Anti-Money Laundering (AML) checks.</p>
        
        <h4>2. Data Security and Storage</h4>
        <p>All sensitive information is encrypted in transit and at rest using AES-256 encryption. We employ strict role-based access controls to ensure that your data is only accessible to authorized personnel on a need-to-know basis.</p>
        
        <h4>3. Data Retention</h4>
        <p>In compliance with financial regulations and our standard Data Retention Policy, loan records and associated personal data are securely retained for a minimum of ten (10) years following the closure of an account or the final payoff of a loan, after which they are automatically and securely purged from our systems.</p>
        
        <h4>4. Your Rights</h4>
        <p>Under GDPR, you have the right to access the personal data we hold about you, request corrections to inaccurate information, and, where legally permissible, request the deletion of your data (Right to Erasure). To exercise these rights, please contact our Data Protection Officer at privacy@udhaarde.com.</p>
        """
    }

    private var termsOfServiceContent: String {
        """
        <h3>Master Terms of Service</h3>
        <p><strong>Effective Date:</strong> January 1, 2026</p>
        <p>Welcome to the उधार De Institutional Banking Portal. By accessing or using this system, you agree to be bound by the following Master Terms of Service. These terms govern the use of our loan origination, management, and reporting systems.</p>

        <h4>1. Authorized Use</h4>
        <p>This portal is intended strictly for authorized borrowers, loan officers, and institutional administrators. You agree to use the system solely for legitimate banking and loan management purposes. Unauthorized access, data scraping, or attempts to circumvent security measures are strictly prohibited and will result in account termination.</p>

        <h4>2. Accuracy of Information</h4>
        <p>You certify that all information provided during the loan application, KYC verification, and servicing processes is accurate, current, and complete. Falsifying financial documents or identity information constitutes fraud and will result in immediate account termination and reporting to relevant financial authorities.</p>

        <h4>3. Financial Obligations</h4>
        <p>Borrowers are responsible for adhering to the repayment schedules agreed upon in their finalized loan sanctions. Failure to remit EMI payments by the specified due dates may result in late fees, increased interest rates, reporting to credit bureaus, and collection activities as permitted by law.</p>
        """
    }
}

struct LegalDocumentView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // In a real app, use AttributedString with HTML
                    Text(content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                        .font(.body)
                        .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LoginView(authController: AuthViewModel())
}
