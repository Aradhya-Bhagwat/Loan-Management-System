

import SwiftUI
import Auth
import Supabase

@Observable
final class AuthManager {
    var isAuthenticated: Bool = false
    var isVerified: Bool = false
    var isChecking: Bool = true

    var needsPasswordSetup: Bool = false

    init() {

        Task {
            for await (event, session) in SupabaseManager.shared.client.auth.authStateChanges {
                await handleAuthStateChange(event: event, session: session)
            }
        }
    }

    @MainActor
    func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        print("🔐 Auth event: \(event), has session: \(session != nil)")
        switch event {
        case .initialSession:

            if let session = session {
                self.isAuthenticated = true
                await refreshUserStatus()

                self.needsPasswordSetup = false
                print("✅ Initial session found: authenticated=true, verified=\(isVerified)")
            } else {
                print("ℹ️ No initial session")
                self.isAuthenticated = false
                self.isVerified = false
                self.needsPasswordSetup = false
            }
            self.isChecking = false

        case .signedIn, .tokenRefreshed, .userUpdated:
            if session != nil {
                self.isAuthenticated = true
                await refreshUserStatus()
                print("✅ Auth State Change: authenticated=true, verified=\(isVerified)")
                self.isChecking = false
            }

        case .signedOut:
            print("👋 User signed out")
            self.isAuthenticated = false
            self.isVerified = false
            self.needsPasswordSetup = false
            self.isChecking = false

        default:
            print("ℹ️ Unhandled auth event: \(event)")
            break
        }
    }

    @MainActor
    private func refreshUserStatus() async {
        do {
            let status = try await SupabaseManager.shared.fetchUserStatus()
            self.isVerified = (status == "Verified")
        } catch {
            print("⚠️ Fetch status error: \(error)")
            self.isVerified = false
        }
    }

    @MainActor
    func handleDeepLink(url: URL) async {
        self.isChecking = true
        print("🔗 [AuthManager] Deep link received: \(url.absoluteString)")

        do {

            let session = try await SupabaseManager.shared.handleDeepLink(url: url)
            print("✅ [AuthManager] Session exchange call completed. User: \(session.user.email ?? "unknown")")

            self.isAuthenticated = true

            await refreshUserStatus()

            if !self.isVerified {
                self.needsPasswordSetup = true
            }

            print("✨ [AuthManager] needsPasswordSetup: \(needsPasswordSetup), isVerified: \(isVerified)")

        } catch {
            print("❌ [AuthManager] Deep link processing failed: \(error.localizedDescription)")
            await checkSession()
        }

        self.isChecking = false
    }

    @MainActor
    func checkSession() async {
        let currentSession = try? await SupabaseManager.shared.client.auth.session

        if currentSession != nil {
            self.isAuthenticated = true
            await refreshUserStatus()
            print("✅ checkSession: authenticated=true, verified=\(isVerified)")
        } else {
            print("ℹ️ checkSession: No session found")
            self.isAuthenticated = false
            self.isVerified = false
        }
        self.isChecking = false
    }

    @MainActor
    func completeAuthentication() {
        isAuthenticated = true
        isVerified = true
        needsPasswordSetup = false
    }

    @MainActor
    func signOut() {
        isAuthenticated = false
        isVerified = false
        needsPasswordSetup = false
    }
}

enum OnboardingRoute: Hashable {
    case login
    case signUpBasicDetails
    case signUpDocuments
    case signUpConsent
}

struct OnboardingRouter: View {
    @State private var path = NavigationPath()

    @State private var loginVM = LoginViewModel()
    @State private var signUpVM = SignUpViewModel()

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingWelcomeView(path: $path)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .login:
                        LoginView(path: $path, viewModel: loginVM)
                    case .signUpBasicDetails:
                        SignUpPhase1View(path: $path, viewModel: signUpVM)
                    case .signUpDocuments:
                        SignUpPhase2View(path: $path, viewModel: signUpVM)
                    case .signUpConsent:
                        SignUpPhase3View(path: $path, viewModel: signUpVM)
                    }
                }
        }
    }
}

struct OnboardingWelcomeView: View {
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {

            LinearGradient(
                colors: [Color.theme.primaryAccent.opacity(0.1), Color.theme.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    }

                    VStack(spacing: 8) {
                        Text("उधार Le")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(Color.theme.textPrimary)

                        Text("Smart Loan Management for Borrowers")
                            .font(.subheadline)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        path.append(OnboardingRoute.login)
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.theme.primaryAccent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.theme.primaryAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                    }

                    Button {
                        path.append(OnboardingRoute.signUpBasicDetails)
                    } label: {
                        Text("Create New Account")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(Color.theme.primaryAccent)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.theme.primaryAccent, lineWidth: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 32)

                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Text("Terms of Service")
                        Text("•")
                        Text("Privacy Policy")
                    }
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.theme.primaryAccent)
                }
                .padding(.bottom, 20)
            }
        }
    }
}
