import Foundation
import Supabase
import Auth

enum SupabaseConfig {
    static let url = URL(string: "https://vghdgjndpwfwbchwbnak.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZnaGRnam5kcHdmd2JjaHdibmFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxNTk1MDYsImV4cCI6MjA5MTczNTUwNn0.WRj3YyKXqhmHmtHRE7n2VCatvpsivhVBeZ3o2IYSQB0"
    
    // IMPORTANT: Only use service_role key for admin tasks. 
    // In production, move this logic to an Edge Function.
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZnaGRnam5kcHdmd2JjaHdibmFrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjE1OTUwNiwiZXhwIjoyMDkxNzM1NTA2fQ.6wlRfNrjGvjsQ4qtnagT2B7qie4s7rCWO_wEXCAqDOA"

    // Supabase Storage bucket for borrower-uploaded documents
    static let storageBucket = "documents"
}

private struct NoopAuthLocalStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws { }
    func retrieve(key: String) throws -> Data? { nil }
    func remove(key: String) throws { }
}

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    let adminClient: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    flowType: .implicit, // REQUIRED for cross-device Magic Links
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        
        self.adminClient = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.serviceRoleKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: NoopAuthLocalStorage(),
                    storageKey: "supabase.admin.auth.token",
                    flowType: .implicit,
                    autoRefreshToken: false,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
