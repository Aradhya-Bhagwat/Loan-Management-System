

import Foundation
import Supabase

// MARK: - Authentication Error

enum LMSAuthError: Error, CustomStringConvertible {
    case notLoggedIn

    var description: String {
        "You're not signed in to CredFlow Go. Please open the app and sign in first."
    }
}

// MARK: - Authentication Manager

final class LMSAuthenticationManager: Sendable {

    static let shared = LMSAuthenticationManager()
    private init() {}

    func requireAuthenticatedUserId() async throws -> UUID {
        print("🔐 [Siri Auth] Checking Supabase session...")

        guard let session = try? await SupabaseManager.shared.client.auth.session else {
            print("❌ [Siri Auth] No active session — user not signed in.")
            throw LMSAuthError.notLoggedIn
        }

        print("✅ [Siri Auth] Session valid. User: \(session.user.id.uuidString.prefix(8))...")
        return session.user.id
    }
}
