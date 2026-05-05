import SwiftUI
import Observation
import Supabase
import Auth
import LocalAuthentication
import Security

@Observable
class AuthViewModel {
    var currentUser: UserSession?
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    // MFA / AAL state
    var isMfaChallengeRequired: Bool = false
    var mfaChallengeFactorId: String?
    var isMfaLoading: Bool = false
    var isTotpEnabled: Bool = false
    var isMfaStatusLoading: Bool = false
    
    var emailInput: String = ""
    var passwordInput: String = ""
    
    // Authentication State Properties
    var isPasswordResetRequired: Bool = false
    var newPasswordInput: String = ""
    var mfaEnrollmentData: AuthMFAEnrollResponse?
    var isPresentingMfaEnrollment: Bool = false
    
    var isBiometricsEnabled: Bool {
        get { 
            // Default to false unless the user explicitly enables it
            if UserDefaults.standard.object(forKey: "isBiometricsEnabled") == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: "isBiometricsEnabled") 
        }
        set { 
            UserDefaults.standard.set(newValue, forKey: "isBiometricsEnabled")
        }
    }

    var hasBiometricSession: Bool {
        UserDefaults.standard.bool(forKey: Self.hasBiometricSessionKey)
    }
    
    init() {
        restoreSession()
    }
    
    func restoreSession() {
        isLoading = true
        Task {
            do {
                if let user = try await DatabaseService.shared.getCurrentSession() {
                    let verifiedSession = await updateVerificationStatusIfNeeded(for: user)
                    await MainActor.run {
                        self.currentUser = verifiedSession
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                    await refreshMFARequirement()
                } else {
                    await MainActor.run { self.isLoading = false }
                }
            } catch {
                await MainActor.run { self.isLoading = false }
                print("No existing session found or profile fetch failed: \(error)")
            }
        }
    }
    
    func login() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Directly login without MFA/OTP flow
                let session = try await DatabaseService.shared.login(email: emailInput, password: passwordInput)
                let verifiedSession = await updateVerificationStatusIfNeeded(for: session)
                
                await MainActor.run {
                    self.currentUser = verifiedSession
                    self.isAuthenticated = true
                    self.isLoading = false
                    print("Login successful for \(emailInput)")
                }
                await refreshMFARequirement()
            } catch {
                let errorToDisplay: String
                
                if let loginError = error as? LoginAccessError, loginError == .blocked {
                    errorToDisplay = "Account Blocked: Too many failed login attempts. Please contact admin."
                } else {
                    // Fetch failed attempts to show "X/3 attempts remaining"
                    let attempts = await DatabaseService.shared.getFailedLoginAttempts(for: emailInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                    if attempts > 0 && attempts < 3 {
                        errorToDisplay = "Invalid password. \(3 - attempts) attempts remaining."
                    } else if attempts >= 3 {
                        errorToDisplay = "Account Blocked: Too many failed login attempts."
                    } else {
                        errorToDisplay = "Login failed: \(error.localizedDescription)"
                    }
                }

                await MainActor.run {
                    self.errorMessage = errorToDisplay
                    self.isLoading = false
                    
                    // FALLBACK FOR DEVELOPMENT
                    if SupabaseConfig.anonKey == "your-anon-key" {
                        self.errorMessage = nil // Clear error for bypass
                        self.isAuthenticated = true
                        self.currentUser = UserSession(id: UUID(), name: "Dev Admin", email: emailInput, role: .admin, status: .verified)
                    }
                }
            }
        }
    }

    private func updateVerificationStatusIfNeeded(for session: UserSession) async -> UserSession {
        if session.status == .pending {
            print("Auth: First login detected for \(session.email). Updating status to verified...")
            await DatabaseService.shared.updateUserVerificationStatus(id: session.id, status: .verified)
            // Refresh to get the updated profile from DB
            return (try? await DatabaseService.shared.getCurrentSession()) ?? session
        }
        return session
    }
    
    func authenticateWithBiometrics() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let stored = try KeychainSessionStore.shared.load(
                    prompt: "Unlock उधार De to continue"
                )

                _ = try await SupabaseManager.shared.client.auth.setSession(
                    accessToken: stored.accessToken,
                    refreshToken: stored.refreshToken
                )
                _ = try? await SupabaseManager.shared.client.auth.refreshSession()

                let user = try? await DatabaseService.shared.getCurrentSession()
                
                var verifiedUser: UserSession? = nil
                if let u = user {
                    verifiedUser = await updateVerificationStatusIfNeeded(for: u)
                }

                await MainActor.run {
                    self.currentUser = verifiedUser
                    self.isAuthenticated = (verifiedUser != nil)
                    self.isLoading = false
                }

                await refreshMFARequirement()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Biometric sign-in failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func logout() {
        Task {
            try? await SupabaseManager.shared.client.auth.signOut()
            try? KeychainSessionStore.shared.delete()
            UserDefaults.standard.set(false, forKey: Self.hasBiometricSessionKey)
            await MainActor.run {
                currentUser = nil
                isAuthenticated = false
                isPasswordResetRequired = false
                isMfaChallengeRequired = false
                mfaChallengeFactorId = nil
                emailInput = ""
                passwordInput = ""
                newPasswordInput = ""
            }
        }
    }
    
    func updatePassword() {
        guard !newPasswordInput.isEmpty else {
            errorMessage = "Please enter a new password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Update the password in Supabase
                try await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(password: newPasswordInput)
                )

                // 2. Update verification status to Verified in public.users
                // We use the Auth session directly to ensure we have the correct ID
                if let authUser = try? await SupabaseManager.shared.client.auth.user() {
                    print("Auth: Password updated for user \(authUser.id). Updating status in public.users...")
                    await DatabaseService.shared.updateUserVerificationStatus(id: authUser.id, status: .verified)
                } else {
                    print("Auth Warning: Could not retrieve user session to update status.")
                }
                
                // After setting password, refresh the user session
                if let user = try? await DatabaseService.shared.getCurrentSession() {
                    await MainActor.run {
                        self.currentUser = user
                        self.isPasswordResetRequired = false
                        self.isAuthenticated = true
                        self.isLoading = false
                        self.newPasswordInput = ""
                        print("Password updated and session restored for \(user.email)")
                    }

                    // Offer 2FA setup right after onboarding password is set.
                    await MainActor.run { self.beginTOTPEnrollment() }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update password: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // Enroll in MFA is no longer needed but kept as an empty stub if you ever want to re-add
    func enrollInMFA() { }

    // MARK: - MFA (TOTP)

    func beginTOTPEnrollment() {
        if isTotpEnabled {
            errorMessage = "Two-factor authentication is already enabled."
            return
        }
        errorMessage = nil
        isMfaLoading = true
        mfaEnrollmentData = nil
        isPresentingMfaEnrollment = true

        Task {
            do {
                let enrollment = try await SupabaseManager.shared.client.auth.mfa.enroll(
                    params: .totp(issuer: "उधार De", friendlyName: "उधार De")
                )
                await MainActor.run {
                    self.mfaEnrollmentData = enrollment
                    self.isMfaLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to start 2FA setup: \(String(describing: error))"
                    self.isMfaLoading = false
                }
            }
        }
    }

    func verifyTOTPEnrollment(code: String) {
        guard let factorId = mfaEnrollmentData?.id else {
            errorMessage = "2FA setup isn't ready yet. Please try again."
            return
        }

        errorMessage = nil
        isMfaLoading = true

        Task {
            do {
                try await SupabaseManager.shared.client.auth.mfa.challengeAndVerify(
                    params: .init(factorId: factorId, code: code)
                )

                // Successful verification promotes session to aal2.
                let user = try? await DatabaseService.shared.getCurrentSession()
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = (user != nil)
                    self.isPresentingMfaEnrollment = false
                    self.mfaEnrollmentData = nil
                    self.isMfaLoading = false
                }

                await refreshMFARequirement()

                if self.isBiometricsEnabled && !self.hasBiometricSession {
                    await MainActor.run { self.verifyBiometricsNowAndStoreSession() }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Invalid code. Please try again."
                    self.isMfaLoading = false
                }
            }
        }
    }

    func completeMFAChallenge(code: String) {
        guard let factorId = mfaChallengeFactorId else {
            errorMessage = "No 2FA factor available."
            return
        }

        errorMessage = nil
        isMfaLoading = true

        Task {
            do {
                try await SupabaseManager.shared.client.auth.mfa.challengeAndVerify(
                    params: .init(factorId: factorId, code: code)
                )
                let user = try? await DatabaseService.shared.getCurrentSession()
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = (user != nil)
                    self.isMfaChallengeRequired = false
                    self.mfaChallengeFactorId = nil
                    self.isMfaLoading = false
                }

                await refreshMFARequirement()

                if self.isBiometricsEnabled && !self.hasBiometricSession {
                    await MainActor.run { self.verifyBiometricsNowAndStoreSession() }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Invalid code. Please try again."
                    self.isMfaLoading = false
                }
            }
        }
    }

    func storeSessionForBiometricsIfPossible() {
        guard isBiometricsEnabled else { return }

        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                try KeychainSessionStore.shared.save(
                    accessToken: session.accessToken,
                    refreshToken: session.refreshToken,
                    requireBiometrics: true
                )
                UserDefaults.standard.set(true, forKey: Self.hasBiometricSessionKey)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not enable biometric unlock: \(error.localizedDescription)"
                }
            }
        }
    }

    func verifyBiometricsNowAndStoreSession() {
        guard isBiometricsEnabled else { return }

        let context = LAContext()
        var authError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            // Biometrics are optional. If not available, silently disable and continue.
            isBiometricsEnabled = false
            clearBiometricSession()
            return
        }

        let reason = "Enable biometric unlock for उधार De"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            Task { @MainActor in
                if success {
                    self.storeSessionForBiometricsIfPossible()
                } else {
                    self.isBiometricsEnabled = false
                    self.clearBiometricSession()
                }
            }
        }
    }

    func clearBiometricSession() {
        do {
            try KeychainSessionStore.shared.delete()
        } catch {
            // ignore
        }
        UserDefaults.standard.set(false, forKey: Self.hasBiometricSessionKey)
    }

    private func refreshMFARequirement() async {
        await MainActor.run { self.isMfaStatusLoading = true }
        do {
            let status = try await SupabaseManager.shared.client.auth.mfa.getAuthenticatorAssuranceLevel()
            let needsAAL2 = (status.nextLevel == "aal2") && (status.currentLevel != "aal2")
            let factors = try await SupabaseManager.shared.client.auth.mfa.listFactors()
            let totpFactorId = factors.totp.first?.id

            await MainActor.run {
                self.isTotpEnabled = !factors.totp.isEmpty
                self.mfaChallengeFactorId = totpFactorId
                self.isMfaChallengeRequired = needsAAL2 && (totpFactorId != nil)
            }
        } catch {
            // Don't block the user if AAL inspection fails; just log.
            print("MFA AAL check failed: \(error)")
        }
        await MainActor.run { self.isMfaStatusLoading = false }
    }

    func refreshMFAStatus() {
        Task { await refreshMFARequirement() }
    }

    func handleDeepLink(url: URL) {
        print("Handling Deep Link: \(url.absoluteString)")
        
        Task {
            do {
                // To support cross-device invites (sent from iPad, opened on iPhone),
                // we check if a local PKCE verifier exists. If not, we handle it as a direct link.
                
                // Exchange the Magic Link/Invite for a session
                try await SupabaseManager.shared.client.auth.session(from: url)
                
                // Fetch the user session to verify it worked and get the profile
                let user = try? await DatabaseService.shared.getCurrentSession()
                
                let urlString = url.absoluteString.lowercased()
                if urlString.contains("type=invite") || 
                   urlString.contains("type=recovery") || 
                   urlString.contains("type=magiclink") || 
                   urlString.contains("type=signup") {
                    
                    await MainActor.run {
                        self.currentUser = user
                        self.isPasswordResetRequired = true
                        self.isAuthenticated = true 
                        self.isLoading = false
                        print("Deep Link: Account setup screen triggered for \(user?.email ?? "unknown")")
                    }
                } else if let session = user {
                    let verifiedSession = await updateVerificationStatusIfNeeded(for: session)
                    await MainActor.run {
                        self.currentUser = verifiedSession
                        self.isAuthenticated = true
                        self.isPasswordResetRequired = false
                        self.isLoading = false
                    }
                }

                if user != nil {
                    await refreshMFARequirement()
                }
            } catch {
                // If it's a PKCE verifier error, it usually means cross-device login.
                // In a production app, you would handle this by falling back to the implicit grant
                // or checking for the presence of the verifier manually.
                
                await MainActor.run {
                    self.errorMessage = "Invitation error: \(error.localizedDescription)"
                    self.isLoading = false
                }
                print("Error processing deep link: \(error)")
            }
        }
    }

    private static let hasBiometricSessionKey = "hasBiometricSession"
}

// MARK: - Keychain session storage (Biometrics)

private final class KeychainSessionStore {
    static let shared = KeychainSessionStore()

    struct StoredSession: Codable, Sendable {
        let accessToken: String
        let refreshToken: String
    }

    private let service = "udharde.supabase.session"
    private let account = "current"

    private init() {}

    func save(accessToken: String, refreshToken: String, requireBiometrics: Bool) throws {
        let data = try JSONEncoder().encode(StoredSession(accessToken: accessToken, refreshToken: refreshToken))

        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        SecItemDelete(query as CFDictionary)

        query[kSecValueData] = data

        if requireBiometrics {
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryCurrentSet],
                &error
            ) else {
                throw error?.takeRetainedValue() as Error? ?? NSError(domain: "Keychain", code: -1)
            }
            query[kSecAttrAccessControl] = access
        } else {
            query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
    }

    func load(prompt: String) throws -> StoredSession {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
            kSecUseOperationPrompt: prompt
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: "Keychain", code: Int(status))
        }

        return try JSONDecoder().decode(StoredSession.self, from: data)
    }

    func delete() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
    }
}
