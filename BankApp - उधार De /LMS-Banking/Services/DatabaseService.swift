import Foundation
import Observation
import Supabase

enum LoginAccessError: LocalizedError {
    case blocked

    var errorDescription: String? {
        switch self {
        case .blocked:
            return "Your account is blocked. Please contact an administrator."
        }
    }
}

@Observable
class DatabaseService {
    static let shared = DatabaseService()

    var users: [UserSession] = []
    var borrowers: [Borrower] = []
    var auditTrail: [AuditEntry] = []
    var kpis: [KPI] = []

    var privacySettings: PrivacySettings = PrivacySettings()
    var consentTemplates: [ConsentTemplate] = [ConsentTemplate()]
    var systemConfig: SystemConfig = SystemConfig()
    var competitiveRates: [CompetitiveRate] = []
    
    private let client = SupabaseManager.shared.client
    
    func fetchAuditTrail() async {
        do {
            let entries: [AuditEntry] = try await client
                .from("audit_trail")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.auditTrail = entries
            }
        } catch {
            print("Error fetching audit trail: \(error)")
        }
    }

    // Server-side paginated audit trail fetch — efficient for large datasets
    struct AuditPage {
        let entries: [AuditEntry]
        let totalCount: Int
    }

    func fetchAuditPage(
        page: Int,
        pageSize: Int,
        search: String,
        branch: String,
        category: String,
        status: String
    ) async throws -> AuditPage {
        let from = page * pageSize
        let to = from + pageSize - 1

        let adminClient = SupabaseManager.shared.adminClient

        var filterQuery = adminClient
            .from("audit_trail")
            .select("*", count: .exact)

        if !search.isEmpty {
            filterQuery = filterQuery.or("title.ilike.%\(search)%,actor.ilike.%\(search)%")
        }
        if branch != "All" {
            filterQuery = filterQuery.eq("branch", value: branch)
        }
        if category != "All" {
            filterQuery = filterQuery.eq("category", value: category)
        }
        if status != "All" {
            filterQuery = filterQuery.eq("status", value: status)
        }

        let response = try await filterQuery
            .order("created_at", ascending: false)
            .range(from: from, to: to)
            .execute()

        let decoder = JSONDecoder()
        let entries = try decoder.decode([AuditEntry].self, from: response.data)
        let total = response.count ?? 0

        return AuditPage(entries: entries, totalCount: total)
    }
    
    private init() {}

    // MARK: - Reporting helpers

    struct PortfolioSnapshot: Sendable {
        let totalPortfolio: Double
        let activeLoanCount: Int
        let totalRecovered: Double
        let outstandingBalance: Double
        let overdueExposure: Double
        let npaCaseCount: Int
    }

    private struct LoanAmountRow: Codable {
        let loanAmount: Double
        enum CodingKeys: String, CodingKey { case loanAmount = "loan_amount" }
    }

    private struct LoanApplicationAmountRow: Codable {
        let id: UUID
        let borrowerId: UUID
        let loanAmount: Double
        let status: String?
        enum CodingKeys: String, CodingKey {
            case id
            case borrowerId = "borrower_id"
            case loanAmount = "loan_amount"
            case status
        }
    }

    private struct ActiveLoanRow: Codable {
        let outstandingBalance: Double
        let applicationId: UUID?
        let disbursedAt: String?
        let isNpa: Bool?
        let sanctionLetterUrl: String?
        enum CodingKeys: String, CodingKey {
            case outstandingBalance = "outstanding_balance"
            case applicationId = "application_id"
            case disbursedAt = "disbursed_at"
            case isNpa = "is_npa"
            case sanctionLetterUrl = "sanction_letter_url"
        }
    }

    struct EMIScheduleRow: Codable, Sendable {
        let dueDate: String
        let amount: Double
        let status: String?
        let paidAt: String?

        enum CodingKeys: String, CodingKey {
            case dueDate = "due_date"
            case amount
            case status
            case paidAt = "paid_at"
        }
    }

    func fetchPortfolioSnapshot(branch: String? = nil) async throws -> PortfolioSnapshot {
        let adminClient = SupabaseManager.shared.adminClient

        // 1. Total Portfolio (sum of approved loan application amounts)
        let allLoanAmounts: [LoanApplicationAmountRow] = (try? await adminClient
            .from("loan_application")
            .select("id,borrower_id,loan_amount,status")
            .execute()
            .value) ?? []

        let branchBorrowers = try await managerBorrowers(branch: branch)
        let branchBorrowerIds = branch != nil ? Set(branchBorrowers.map { $0.id }) : nil

        let approvedLoanAmounts = allLoanAmounts.filter { $0.status == LoanStatus.approved.rawValue }
        let filteredApprovedAmounts = branchBorrowerIds != nil
            ? approvedLoanAmounts.filter { branchBorrowerIds!.contains($0.borrowerId) }
            : approvedLoanAmounts

        let totalPortfolio = filteredApprovedAmounts.map(\.loanAmount).reduce(0, +)

        // 2. Active loans count
        let allActiveLoansResponse: [ManagerActiveLoanRow] = (try? await adminClient
            .from("active_loan")
            .select("id,application_id,disbursed_at,outstanding_balance,is_npa,sanction_letter_url")
            .execute()
            .value) ?? []

        let filteredAppIds = branchBorrowerIds != nil
            ? Set(allLoanAmounts.filter { branchBorrowerIds!.contains($0.borrowerId) }.map { $0.id })
            : nil
        let branchActiveLoans = filteredAppIds != nil
            ? allActiveLoansResponse.filter { active in
                guard let appId = active.applicationId else { return false }
                return filteredAppIds!.contains(appId)
            }
            : allActiveLoansResponse

        let activeLoanCount = branchActiveLoans.count

        // 3. Outstanding (active_loan table)
        let outstandingBalance = branchActiveLoans.map(\.outstandingBalance).reduce(0, +)
        let totalRecovered = totalPortfolio - outstandingBalance

        // 4. NPA Data (PAR and Case Count)
        let npaData: [NPAJoinRow] = branchBorrowerIds != nil
            ? (try? await adminClient
                .from("active_loan")
                .select("outstanding_balance, loan_application(borrower_id)")
                .eq("is_npa", value: true)
                .execute()
                .value).map { (rows: [NPAJoinRow]) in
                    rows.filter { row in
                        guard let borrowerId = row.loanApplication?.borrowerId else { return false }
                        return branchBorrowerIds!.contains(borrowerId)
                    }
                } ?? []
            : (try? await adminClient
                .from("active_loan")
                .select("outstanding_balance, loan_application(borrower_id)")
                .eq("is_npa", value: true)
                .execute()
                .value) ?? []

        let npaExposure = npaData.map(\.outstandingBalance).reduce(0, +)
        let npaCaseCount = npaData.count

        return PortfolioSnapshot(
            totalPortfolio: totalPortfolio,
            activeLoanCount: activeLoanCount,
            totalRecovered: totalRecovered,
            outstandingBalance: outstandingBalance,
            overdueExposure: npaExposure,
            npaCaseCount: npaCaseCount
        )
    }

    func fetchAuditTrail(from start: Date, to end: Date, branch: String? = nil) async throws -> [AuditEntry] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let startStr = iso.string(from: start)
        let endStr = iso.string(from: end)

        if let branch {
            return try await SupabaseManager.shared.adminClient
                .from("audit_trail")
                .select()
                .eq("branch", value: branch)
                .gte("created_at", value: startStr)
                .lte("created_at", value: endStr)
                .order("created_at", ascending: false)
                .execute()
                .value
        }
        return try await SupabaseManager.shared.adminClient
            .from("audit_trail")
            .select()
            .gte("created_at", value: startStr)
            .lte("created_at", value: endStr)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    // MARK: - Auth
    
    func login(email: String, password: String) async throws -> UserSession {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let response: Session

        do {
            response = try await client.auth.signIn(email: normalizedEmail, password: password)
        } catch {
            await recordFailedLoginAttempt(email: normalizedEmail, failureReason: error.localizedDescription)
            throw error
        }

        let profile: UserSession
        do {
            profile = try await fetchUserProfile(for: response.user.id)
        } catch {
            if case LoginAccessError.blocked = error {
                try? await client.auth.signOut()
                throw LoginAccessError.blocked
            }
            throw error
        }

        await resetFailedLoginAttempts(for: profile.id)
        return profile
    }

    func getCurrentSession() async throws -> UserSession? {
        do {
            let session = try await client.auth.session
            return try await fetchUserProfile(for: session.user.id)
        } catch {
            return nil
        }
    }

    private func fetchUserProfile(for userId: UUID) async throws -> UserSession {
        // Fetch user profile from public.users table
        do {
            let profiles: [UserSession] = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            
            if let profile = profiles.first {
                guard profile.status != .blocked else {
                    throw LoginAccessError.blocked
                }
                return profile
            }
        } catch {
            if case LoginAccessError.blocked = error {
                throw LoginAccessError.blocked
            }
            print("Profile fetch failed or missing for \(userId): \(error)")
        }
        
        // Fallback for newly created users who might not be synced yet
        let user = try await client.auth.user()
        return UserSession(
            id: userId,
            name: user.userMetadata["full_name"]?.description ?? "New User",
            email: user.email ?? "",
            role: UserRole(rawValue: user.userMetadata["role"]?.description ?? "Borrower") ?? .borrower,
            status: .pending,
            branch: user.userMetadata["branch"]?.description
        )
    }

    func getFailedLoginAttempts(for email: String) async -> Int {
        do {
            let profiles: [UserSession] = try await SupabaseManager.shared.adminClient
                .from("users")
                .select("failed_login_attempts")
                .eq("email", value: email)
                .limit(1)
                .execute()
                .value
            return profiles.first?.failedLoginAttempts ?? 0
        } catch {
            print("Error fetching failed attempts: \(error)")
            return 0
        }
    }

    private func recordFailedLoginAttempt(email: String, failureReason: String) async {
        do {
            let profiles: [UserSession] = try await SupabaseManager.shared.adminClient
                .from("users")
                .select()
                .eq("email", value: email)
                .limit(1)
                .execute()
                .value

            guard let profile = profiles.first,
                  [.manager, .borrower, .officer].contains(profile.role),
                  profile.status != .blocked else {
                return
            }

            let attempts = (profile.failedLoginAttempts ?? 0) + 1
            var updateData: [String: AnyJSON] = [
                "failed_login_attempts": .integer(attempts)
            ]

            if attempts >= 3 {
                updateData["status"] = .string(UserVerificationStatus.blocked.rawValue)
            }

            try await SupabaseManager.shared.adminClient
                .from("users")
                .update(updateData)
                .eq("id", value: profile.id.uuidString)
                .execute()

            if attempts >= 3 {
                try? await SupabaseManager.shared.adminClient.auth.admin.updateUserById(
                    profile.id,
                    attributes: AdminUserAttributes(banDuration: "87600h")
                )

                await logAudit(
                    title: "Suspicious Activity: \(profile.name) blocked after 3 failed login attempts",
                    actor: profile.name,
                    category: "Security",
                    status: "Blocked",
                    icon: "lock.shield.fill",
                    color: "red",
                    branch: profile.branch
                )
            } else {
                print("Failed login attempt \(attempts)/3 for \(email): \(failureReason)")
            }
        } catch {
            print("Failed to record login attempt for \(email): \(error)")
        }
    }

    private func resetFailedLoginAttempts(for userId: UUID) async {
        do {
            let updateData: [String: AnyJSON] = ["failed_login_attempts": .integer(0)]
            try await SupabaseManager.shared.adminClient
                .from("users")
                .update(updateData)
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            print("Failed to reset login attempts for \(userId): \(error)")
        }
    }
    
    // MARK: - Users (Staff)
    
    func fetchUsers() async {
        do {
            // Use adminClient to fetch the list so the Admin sees everything regardless of RLS
            let fetchedUsers: [UserSession] = try await SupabaseManager.shared.adminClient
                .from("users")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                self.users = fetchedUsers
                print("Admin: Users fetched, count: \(fetchedUsers.count)")
            }
        } catch {
            print("Error fetching users: \(error)")
        }
    }
    
    func inviteUser(name: String, email: String, phone: String, role: UserRole, branch: String? = nil) async throws {
        do {
            print("INSTITUTIONAL INVITE: Starting flow for \(email)")

            var userId: UUID?

            do {
                // 1. Try to create the user via Admin API
                let user = try await SupabaseManager.shared.adminClient.auth.admin.createUser(
                    attributes: AdminUserAttributes(
                        email: email,
                        emailConfirm: true,
                        password: UUID().uuidString,
                        userMetadata: [
                            "full_name": .string(name),
                            "role": .string(role.rawValue),
                            "branch": .string(branch ?? "")
                        ]
                    )
                )
                userId = user.id
                print("Step 1: New Auth User created. ID: \(userId!)")
            } catch {
                let errorMsg = error.localizedDescription.lowercased()
                if errorMsg.contains("already") || errorMsg.contains("registered") {
                    print("Step 1: User exists in Auth. Attempting to fetch existing ID...")
                    
                    // Fallback: Fetch user by email to get their ID
                    let response = try await SupabaseManager.shared.adminClient.auth.admin.listUsers()
                    if let found = response.users.first(where: { $0.email == email }) {
                        userId = found.id
                        print("Step 1 (Fallback): Found existing user ID: \(userId!)")
                    }
                }
                
                if userId == nil {
                    throw error
                }
            }
            
            guard let finalId = userId else { return }

            // 2. Sync to public.users table
            var userData: [String: AnyJSON] = [
                "id": .string(finalId.uuidString),
                "full_name": .string(name),
                "email": .string(email),
                "phone": .string(phone),
                "role": .string(role.rawValue),
                "status": .string(UserVerificationStatus.pending.rawValue)
            ]
            
            if let branch = branch {
                userData["branch"] = .string(branch)
            }

            try await SupabaseManager.shared.adminClient.from("users").upsert(userData).execute()
            print("Step 2: Profile synced.")

            // 3. If Officer, sync to public.loan_officers table
            if role == .officer {
                let officerData: [String: AnyJSON] = [
                    "id": .string(finalId.uuidString),
                    "full_name": .string(name),
                    "role": .string(role.rawValue),
                    "loans_handled": .integer(0),
                    "approval_rate": .double(0.0),
                    "default_rate": .double(0.0),
                    "active_loans": .integer(0),
                    "initials": .string(String(name.prefix(1)).uppercased())
                ]
                try? await SupabaseManager.shared.adminClient.from("loan_officers").upsert(officerData).execute()
                print("Step 3: Staff record synced.")
            }

            // 4. Trigger Magic Link Email
            try await SupabaseManager.shared.client.auth.signInWithOTP(
                email: email,
                redirectTo: URL(string: "udharde://callback")
            )
            print("Step 4: Magic Link sent to \(email)")
            
            // 5. Log Audit
            await logAudit(
                title: "User Invited: \(name)",
                actor: "Admin",
                category: "Management",
                status: "Success",
                icon: "person.badge.plus",
                color: "green",
                branch: branch
            )

            await fetchUsers()

        } catch {
            print("CRITICAL INVITE FAILURE: \(error.localizedDescription)")
            await logAudit(
                title: "Failed Invite: \(email)",
                actor: "Admin",
                category: "Management",
                status: "Error",
                icon: "exclamationmark.triangle",
                color: "red"
            )
            throw error
        }
    }

    // MARK: - Audit Logging

    func logAudit(        title: String,
        actor: String,
        category: String = "System",
        status: String = "Processed",
        icon: String = "bell.fill",
        color: String = "blue",
        branch: String? = nil
    ) async {
        do {
            var auditData: [String: AnyJSON] = [
                "title": .string(title),
                "actor": .string(actor),
                "category": .string(category),
                "status": .string(status),
                "icon": .string(icon),
                "icon_color": .string(color)
            ]
            
            if let branch = branch {
                auditData["branch"] = .string(branch)
            }
            
            try await SupabaseManager.shared.adminClient
                .from("audit_trail")
                .insert(auditData)
                .execute()
            
            print("Audit Logged: \(title)")
        } catch {
            print("Failed to log audit: \(error)")
        }
    }

    func updateUserVerificationStatus(id: UUID, status: UserVerificationStatus) async {
        do {
            let statusData: [String: AnyJSON] = ["status": .string(status.rawValue)]
            try await SupabaseManager.shared.adminClient
                .from("users")
                .update(statusData)
                .eq("id", value: id.uuidString)
                .execute()
            print("✅ SUCCESS: User \(id) status updated to \(status.rawValue) via Admin Client")
        } catch {
            print("❌ ERROR: Failed to update user status: \(error)")
        }
    }
    // MARK: - Admin Management Actions

    func deleteUser(id: UUID) async {
        do {
            // Because we added 'ON DELETE CASCADE' to the foreign keys in Supabase,
            // deleting the user from Auth will automatically remove their 
            // records from public.users, public.borrower, public.manager_settings, etc.
            
            try await SupabaseManager.shared.adminClient.auth.admin.deleteUser(id: id)

            await fetchUsers()
            print("User \(id) and all related data deleted successfully via Cascade")
        } catch {
            print("CRITICAL: Error deleting user: \(error)")
        }
    }

    func updateUserProfile(id: UUID, name: String, email: String, phone: String, role: UserRole, branch: String? = nil) async {
        do {
            var updateData: [String: AnyJSON] = [
                "full_name": .string(name),
                "email": .string(email),
                "phone": .string(phone),
                "role": .string(role.rawValue)
            ]

            if let branch = branch {
                updateData["branch"] = .string(branch)
            }

            try await client
                .from("users")
                .update(updateData)
                .eq("id", value: id)
                .execute()

            try await SupabaseManager.shared.adminClient.auth.admin.updateUserById(
                id,
                attributes: AdminUserAttributes(
                    email: email,
                    userMetadata: [
                        "full_name": .string(name),
                        "phone": .string(phone),
                        "role": .string(role.rawValue),
                        "branch": .string(branch ?? "")
                    ]
                )
            )

            await fetchUsers()
            print("User \(id) updated successfully in both Auth and Profile")
        } catch {
            print("Error updating user: \(error)")
        }
    }

    func banUser(id: UUID, isBanned: Bool) async {
        do {
            // In Supabase, banning is done by setting ban_duration. 
            // "87600h" is 10 years (effectively permanent ban). "none" removes it.
            let duration = isBanned ? "87600h" : "none"
            
            try await SupabaseManager.shared.adminClient.auth.admin.updateUserById(
                id,
                attributes: AdminUserAttributes(banDuration: duration)
            )
            
            print("User \(id) ban status set to: \(isBanned)")
        } catch {
            print("Error banning user: \(error)")
        }
    }

    func setUserBlockedStatus(id: UUID, isBlocked: Bool) async {
        do {
            let duration = isBlocked ? "87600h" : "none"
            let newStatus: UserVerificationStatus = isBlocked ? .blocked : .verified
            let updateData: [String: AnyJSON] = [
                "status": .string(newStatus.rawValue),
                "failed_login_attempts": .integer(0)
            ]

            try await SupabaseManager.shared.adminClient
                .from("users")
                .update(updateData)
                .eq("id", value: id.uuidString)
                .execute()

            try await SupabaseManager.shared.adminClient.auth.admin.updateUserById(
                id,
                attributes: AdminUserAttributes(banDuration: duration)
            )

            await fetchUsers()
            print("User \(id) blocked status set to: \(isBlocked)")
        } catch {
            print("Error updating blocked status: \(error)")
        }
    }
    
    var loanProducts: [LoanProduct] = []
    
    // MARK: - Loan Products
    
    func fetchLoanProducts() async {
        do {
            let fetched: [LoanProduct] = try await SupabaseManager.shared.adminClient
                .from("loan_products")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                self.loanProducts = fetched
            }
        } catch {
            print("Error fetching loan products: \(error)")
        }
    }
    
    func saveLoanProduct(_ product: LoanProduct) async {
        do {
            try await SupabaseManager.shared.adminClient
                .from("loan_products")
                .upsert(product)
                .execute()
            
            await fetchLoanProducts()
        } catch {
            print("Error saving loan product: \(error)")
        }
    }
    
    func deleteLoanProduct(id: UUID) async throws {
        do {
            try await SupabaseManager.shared.adminClient
                .from("loan_products")
                .delete()
                .eq("id", value: id)
                .execute()
            
            await fetchLoanProducts()
        } catch {
            print("Error deleting loan product: \(error)")
            // 23503 is Postgres foreign key violation
            let nsError = error as NSError
            if nsError.localizedDescription.contains("23503") || String(describing: error).contains("23503") {
                throw NSError(domain: "Database", code: 23503, userInfo: [NSLocalizedDescriptionKey: "Cannot delete this product because there are existing loan applications linked to it."])
            }
            throw error
        }
    }

    // MARK: - Competitive Rates
    
    func fetchCompetitiveRates() async {
        do {
            let fetched: [CompetitiveRate] = try await SupabaseManager.shared.adminClient
                .from("competitive_rates")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                self.competitiveRates = fetched
            }
        } catch {
            print("Error fetching competitive rates: \(error)")
        }
    }
    
    func saveCompetitiveRate(_ rate: CompetitiveRate) async {
        do {
            try await SupabaseManager.shared.adminClient
                .from("competitive_rates")
                .upsert(rate)
                .execute()
            
            await fetchCompetitiveRates()
        } catch {
            print("Error saving competitive rate: \(error)")
        }
    }
    
    // MARK: - Notification Settings

    var notificationSettings: [NotificationSetting] = []

    func fetchNotificationSettings() async {
        do {
            let fetched: [NotificationSetting] = try await SupabaseManager.shared.adminClient
                .from("notification_settings")
                .select()
                .order("title", ascending: true)
                .execute()
                .value
            await MainActor.run {
                self.notificationSettings = fetched
            }
        } catch {
            print("fetchNotificationSettings error: \(error)")
        }
    }

    func saveNotificationSetting(_ setting: NotificationSetting) async {
        do {
            try await SupabaseManager.shared.adminClient
                .from("notification_settings")
                .upsert(setting, onConflict: "title")
                .execute()
            await fetchNotificationSettings()
        } catch {
            print("saveNotificationSetting error: \(error)")
        }
    }

    func deleteNotificationSetting(id: UUID) async {
        do {
            try await SupabaseManager.shared.adminClient
                .from("notification_settings")
                .delete()
                .eq("id", value: id)
                .execute()
            await fetchNotificationSettings()
        } catch {
            print("deleteNotificationSetting error: \(error)")
        }
    }

    // MARK: - Notification Templates

    var notificationTemplates: [NotificationTemplate] = []

    func fetchNotificationTemplates() async {
        do {
            let fetched: [NotificationTemplate] = try await SupabaseManager.shared.adminClient
                .from("notification_templates")
                .select()
                .order("title", ascending: true)
                .execute()
                .value
            await MainActor.run {
                self.notificationTemplates = fetched
            }
        } catch {
            print("fetchNotificationTemplates error: \(error)")
        }
    }

    func saveNotificationTemplate(_ template: NotificationTemplate) async {
        do {
            try await SupabaseManager.shared.adminClient
                .from("notification_templates")
                .upsert(template)
                .execute()
            await fetchNotificationTemplates()
        } catch {
            print("saveNotificationTemplate error: \(error)")
        }
    }
    
    /// Fetch a single loan product by ID (used to get required_documents for a specific loan type)
    func fetchLoanProduct(by id: UUID) async throws -> LoanProduct? {
        let products: [LoanProduct] = try await client
            .from("loan_products")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return products.first
    }
    
    // MARK: - Loans

    private struct ManagerLoanApplicationRow: Codable {
        let id: UUID
        let borrowerId: UUID
        let loanAmount: Double
        let tenureMonths: Int
        let purpose: String?
        let status: String?
        let monthlyIncome: Double?
        let assignedOfficerId: UUID?
        let productId: UUID?
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case borrowerId = "borrower_id"
            case loanAmount = "loan_amount"
            case tenureMonths = "tenure_months"
            case purpose
            case status
            case monthlyIncome = "monthly_income"
            case assignedOfficerId = "assigned_officer_id"
            case productId = "product_id"
            case createdAt = "created_at"
        }
    }

    private struct ManagerBorrowerRow: Codable {
        let id: UUID
        let fullName: String?
        let creditScore: Int?
        let declaredMonthlyIncome: Double?

        enum CodingKeys: String, CodingKey {
            case id
            case fullName = "full_name"
            case creditScore = "credit_score"
            case declaredMonthlyIncome = "declared_monthly_income"
        }
    }

    private struct ManagerUserRow: Codable {
        let id: UUID
        let fullName: String
        let role: String
        let branch: String?

        enum CodingKeys: String, CodingKey {
            case id
            case fullName = "full_name"
            case role
            case branch
        }
    }

    private struct ManagerActiveLoanRow: Codable {
        let id: UUID
        let applicationId: UUID?
        let disbursedAt: String?
        let outstandingBalance: Double
        let isNpa: Bool?
        let sanctionLetterUrl: String?

        enum CodingKeys: String, CodingKey {
            case id
            case applicationId = "application_id"
            case disbursedAt = "disbursed_at"
            case outstandingBalance = "outstanding_balance"
            case isNpa = "is_npa"
            case sanctionLetterUrl = "sanction_letter_url"
        }
    }

    private struct ManagerEMIRow: Codable {
        let loanId: UUID?
        let dueDate: String
        let amount: Double
        let status: String?

        enum CodingKeys: String, CodingKey {
            case loanId = "loan_id"
            case dueDate = "due_date"
            case amount
            case status
        }
    }

    private struct ManagerRepaymentRow: Codable {
        let loanId: UUID
        let dueDate: String?
        let amount: Double
        let paidAmount: Double?
        let status: String?
        let paidAt: String?

        enum CodingKeys: String, CodingKey {
            case loanId = "loan_id"
            case dueDate = "due_date"
            case amount
            case paidAmount = "paid_amount"
            case status
            case paidAt = "paid_at"
        }
    }

    private struct ManagerEmploymentRow: Codable {
        let borrowerId: UUID
        let industryType: String?

        enum CodingKeys: String, CodingKey {
            case borrowerId = "borrower_id"
            case industryType = "industry_type"
        }
    }

    private func managerApplications() async throws -> [ManagerLoanApplicationRow] {
        try await SupabaseManager.shared.adminClient
            .from("loan_application")
            .select("id,borrower_id,loan_amount,tenure_months,purpose,status,monthly_income,assigned_officer_id,product_id,created_at")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func managerBorrowers(branch: String? = nil) async throws -> [ManagerBorrowerRow] {
        if let branch {
            return try await SupabaseManager.shared.adminClient
                .from("borrower")
                .select()
                .eq("branch", value: branch)
                .execute()
                .value
        }
        return try await SupabaseManager.shared.adminClient
            .from("borrower")
            .select("id,full_name,credit_score,declared_monthly_income")
            .execute()
            .value
    }

    private func managerUsers() async throws -> [ManagerUserRow] {
        try await SupabaseManager.shared.adminClient
            .from("users")
            .select("id,full_name,role,branch")
            .execute()
            .value
    }

    private func managerActiveLoans() async throws -> [ManagerActiveLoanRow] {
        try await SupabaseManager.shared.adminClient
            .from("active_loan")
            .select("id,application_id,disbursed_at,outstanding_balance,is_npa,sanction_letter_url")
            .execute()
            .value
    }

    private func managerLoanProducts() async throws -> [LoanProduct] {
        try await SupabaseManager.shared.adminClient
            .from("loan_products")
            .select()
            .execute()
            .value
    }

    private func managerRisk(creditScore: Int, isNpa: Bool) -> RiskLevel {
        if isNpa || creditScore < 650 { return .high }
        if creditScore < 750 { return .medium }
        return .low
    }

    private func managerMonthLabel(from value: String?) -> String {
        guard let value else { return "Unknown" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: value)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: value)
        }
        guard let date else { return String(value.prefix(7)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func managerMonthOrder(_ month: String) -> Int {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months.firstIndex(of: month).map { $0 + 1 } ?? 13
    }

    private func managerDate(from value: String) -> Date? {
        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.dateFormat = "yyyy-MM-dd"
        if let date = dateOnly.date(from: value) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: value)
    }
    
    func fetchLoans(branch: String? = nil) async throws -> [Loan] {
        let borrowers = try await managerBorrowers(branch: branch)
        let branchBorrowerIds = branch != nil ? Set(borrowers.map { $0.id }) : nil

        let allApplications = try await managerApplications()
        let applications = branchBorrowerIds != nil
            ? allApplications.filter { branchBorrowerIds!.contains($0.borrowerId) }
            : allApplications

        let borrowersDict = Dictionary(uniqueKeysWithValues: borrowers.map { ($0.id, $0) })
        let officers = Dictionary(uniqueKeysWithValues: try await managerUsers().map { ($0.id, $0) })
        let allActiveLoans = try await managerActiveLoans()
        let filteredAppIds = branchBorrowerIds != nil ? Set(applications.map { $0.id }) : nil
        let activeLoans = Dictionary(uniqueKeysWithValues: (filteredAppIds != nil
            ? allActiveLoans.filter { active in
                guard let appId = active.applicationId else { return false }
                return filteredAppIds!.contains(appId)
            }
            : allActiveLoans
        ).compactMap { active in
            active.applicationId.map { ($0, active) }
        })
        let products = Dictionary(uniqueKeysWithValues: ((try? await managerLoanProducts()) ?? []).map { ($0.id, $0) })

        return applications.map { application in
            let borrower = borrowersDict[application.borrowerId]
            let officer = application.assignedOfficerId.flatMap { officers[$0]?.fullName } ?? "Unassigned"
            let activeLoan = activeLoans[application.id]
            let creditScore = borrower?.creditScore ?? 750
            let purpose = application.purpose?.isEmpty == false
                ? application.purpose!
                : application.productId.flatMap { products[$0]?.name } ?? "General Loan"
            let status = LoanStatus(rawValue: application.status ?? "") ?? .submitted
            let incomeValue = application.monthlyIncome ?? borrower?.declaredMonthlyIncome ?? 0

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let createdDate = application.createdAt.flatMap { iso.date(from: $0) }

            return Loan(
                id: application.id,
                borrowerId: application.borrowerId,
                borrowerName: borrower?.fullName ?? "Unknown Borrower",
                amount: CurrencyFormatter.indian(application.loanAmount),
                amountValue: application.loanAmount,
                risk: managerRisk(creditScore: creditScore, isNpa: activeLoan?.isNpa == true),
                officer: officer,
                status: status,
                purpose: purpose,
                tenure: "\(application.tenureMonths) months",
                creditScore: creditScore,
                income: CurrencyFormatter.indian(incomeValue),
                sanctionLetterUrl: activeLoan?.sanctionLetterUrl,
                createdAt: createdDate
            )
        }
    }
    
    private struct LoanAmount: Codable {
        let loanAmount: Double
        enum CodingKeys: String, CodingKey {
            case loanAmount = "loan_amount"
        }
    }

    private struct OverdueAmount: Codable {
        let amount: String
    }

    private struct NPAJoinRow: Codable {
        let outstandingBalance: Double
        let loanApplication: BorrowerIdOnly?

        enum CodingKeys: String, CodingKey {
            case outstandingBalance = "outstanding_balance"
            case loanApplication = "loan_application"
        }
    }

    private struct BorrowerIdOnly: Codable {
        let borrowerId: UUID
        enum CodingKeys: String, CodingKey {
            case borrowerId = "borrower_id"
        }
    }

    func fetchLiveKPIs(branch: String? = nil) async throws -> [KPI] {
        let adminClient = SupabaseManager.shared.adminClient

        async let portfolioRows: [KPIViewRow] = (try? await adminClient
            .from("portfolio_health_kpis")
            .select()
            .execute()
            .value) ?? []

        async let repaymentRows: [KPIViewRow] = (try? await adminClient
            .from("repayment_kpis")
            .select()
            .execute()
            .value) ?? []

        async let npaRows: [KPIViewRow] = (try? await adminClient
            .from("npa_kpis")
            .select()
            .execute()
            .value) ?? []

        async let activeCountResponse = adminClient
            .from("active_loan")
            .select("id", count: .exact)
            .execute()

        let (portfolio, repayment, npa, activeResult) = try await (portfolioRows, repaymentRows, npaRows, activeCountResponse)

        let portfolioValue = portfolio.first(where: { $0.title == "Total Portfolio Value" })?.value
        let collectionEff  = repayment.first(where: { $0.title == "Collection Efficiency" })?.value
        let npaRatio       = npa.first(where: { $0.title == "NPA Ratio" })?.value
        let activeCount    = activeResult.count ?? 0

        let snapshot = (portfolioValue == nil || npaRatio == nil) ? (try? await fetchPortfolioSnapshot(branch: branch)) : nil

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let code = systemConfig.defaultCurrency.uppercased()
        formatter.currencySymbol = (code == "INR") ? "₹" : ((code == "USD") ? "$" : code + " ")
        formatter.maximumFractionDigits = 0

        let finalPortfolio: String = portfolioValue
            ?? formatter.string(from: NSNumber(value: snapshot?.totalPortfolio ?? 0))
            ?? "—"

        let finalRepayment: String = collectionEff ?? {
            guard let snap = snapshot, snap.totalPortfolio > 0 else { return "—" }
            let eff = ((snap.totalPortfolio - snap.overdueExposure) / snap.totalPortfolio) * 100
            return String(format: "%.1f%%", eff)
        }()

        let finalNPA: String = npaRatio ?? {
            guard let snap = snapshot else { return "—" }
            return snap.npaCaseCount > 0 ? "\(snap.npaCaseCount) cases" : "0 cases"
        }()

        let kpis: [KPI] = [
            KPI(title: "Portfolio Health",  value: finalPortfolio,          change: nil,       iconName: "briefcase.fill",                accent: "green"),
            KPI(title: "Repayment Trends",  value: finalRepayment,          change: nil,       iconName: "chart.line.uptrend.xyaxis",     accent: "green"),
            KPI(title: "NPA Analysis",      value: finalNPA,                change: nil,       iconName: "exclamationmark.triangle.fill", accent: "green"),
            KPI(title: "Active Loans",      value: "\(activeCount)",        change: nil,       iconName: "checkmark.seal.fill",           accent: "green")
        ]

        await MainActor.run {
            self.kpis = kpis
        }
        return kpis
    }

    private struct KPIViewRow: Codable {
        let id: String
        let title: String
        let value: String
    }

    func fetchKPIs(branch: String? = nil) async throws -> [KPI] {
        return try await fetchLiveKPIs(branch: branch)
    }
    
    
    
    func fetchLoanDistribution(branch: String? = nil) async throws -> [LoanDistribution] {
        let borrowers = try await managerBorrowers(branch: branch)
        let branchBorrowerIds = branch != nil ? Set(borrowers.map { $0.id }) : nil
        let allApplications = try await managerApplications()
        let applications = branchBorrowerIds != nil
            ? allApplications.filter { branchBorrowerIds!.contains($0.borrowerId) }
            : allApplications
        let products = Dictionary(uniqueKeysWithValues: ((try? await managerLoanProducts()) ?? []).map { ($0.id, $0.name) })
        guard !applications.isEmpty else { return [] }

        let grouped = Dictionary(grouping: applications) { application in
            if let productId = application.productId, let productName = products[productId] {
                return productName
            }
            return application.purpose?.isEmpty == false ? application.purpose! : "General Loan"
        }

        return grouped
            .map { key, value in
                LoanDistribution(type: key, percentage: Double(value.count) / Double(applications.count) * 100)
            }
            .sorted { $0.percentage > $1.percentage }
    }

    func fetchEMISchedule(from start: Date, to end: Date, branch: String? = nil) async throws -> [EMIScheduleRow] {
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = .current
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = .current
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let startStr = dayFormatter.string(from: start)
        let endStr = dayFormatter.string(from: end)

        return try await SupabaseManager.shared.adminClient
            .from("emi_schedule")
            .select("due_date,amount,status,paid_at")
            .gte("due_date", value: startStr)
            .lte("due_date", value: endStr)
            .execute()
            .value
    }
    
    func fetchMonthlyDisbursements(branch: String? = nil) async throws -> [MonthlyDisbursement] {
        let borrowers = try await managerBorrowers(branch: branch)
        let branchBorrowerIds = branch != nil ? Set(borrowers.map { $0.id }) : nil
        let allApplications = try await managerApplications()
        let applications = branchBorrowerIds != nil
            ? Dictionary(uniqueKeysWithValues: allApplications.filter { branchBorrowerIds!.contains($0.borrowerId) }.map { ($0.id, $0) })
            : Dictionary(uniqueKeysWithValues: allApplications.map { ($0.id, $0) })
        let allActiveLoans = try await managerActiveLoans()
        let filteredAppIds = Set(applications.keys)
        let activeLoans = allActiveLoans.filter { active in
            guard let appId = active.applicationId else { return false }
            return filteredAppIds.contains(appId)
        }
        let grouped = Dictionary(grouping: activeLoans) { managerMonthLabel(from: $0.disbursedAt) }

        return grouped
            .map { month, rows in
                let total = rows.reduce(0) { sum, active in
                    guard let applicationId = active.applicationId else { return sum }
                    return sum + (applications[applicationId]?.loanAmount ?? 0)
                }
                return MonthlyDisbursement(month: month, amount: total / 1_000_000)
            }
            .sorted { managerMonthOrder($0.month) < managerMonthOrder($1.month) }
    }
    
    func fetchDefaultTrends(branch: String? = nil) async throws -> [DefaultTrend] {
        let allActiveLoans = try await managerActiveLoans()
        let npaLoans = allActiveLoans.filter { $0.isNpa == true }
        if let branch {
            let borrowers = try await managerBorrowers(branch: branch)
            let branchBorrowerIds = Set(borrowers.map { $0.id })
            let allApplications = try await managerApplications()
            let branchAppIds = Set(allApplications.filter { branchBorrowerIds.contains($0.borrowerId) }.map { $0.id })
            let filteredNpaLoans = npaLoans.filter { active in
                guard let appId = active.applicationId else { return false }
                return branchAppIds.contains(appId)
            }
            let grouped = Dictionary(grouping: filteredNpaLoans) { managerMonthLabel(from: $0.disbursedAt) }
            return grouped
                .map { month, rows in DefaultTrend(month: month, count: rows.count) }
                .sorted { managerMonthOrder($0.month) < managerMonthOrder($1.month) }
        }
        let grouped = Dictionary(grouping: npaLoans) { managerMonthLabel(from: $0.disbursedAt) }
        return grouped
            .map { month, rows in DefaultTrend(month: month, count: rows.count) }
            .sorted { managerMonthOrder($0.month) < managerMonthOrder($1.month) }
    }
    
    func fetchSectorPerformance(branch: String? = nil) async throws -> [SectorPerformance] {
        let borrowers = try await managerBorrowers(branch: branch)
        let branchBorrowerIds = branch != nil ? Set(borrowers.map { $0.id }) : nil
        let allApplications = try await managerApplications()
        let applications = branchBorrowerIds != nil
            ? allApplications.filter { branchBorrowerIds!.contains($0.borrowerId) }
            : allApplications
        let allActiveLoans = try await managerActiveLoans()
        let filteredAppIds = branchBorrowerIds != nil
            ? Set(applications.map { $0.id })
            : nil
        let activeByApplication = Dictionary(uniqueKeysWithValues: (filteredAppIds != nil
            ? allActiveLoans.filter { active in
                guard let appId = active.applicationId else { return false }
                return filteredAppIds!.contains(appId)
            }
            : allActiveLoans
        ).compactMap { active in
            active.applicationId.map { ($0, active) }
        })
        let employmentRows: [ManagerEmploymentRow] = (try? await SupabaseManager.shared.adminClient
            .from("employment")
            .select("borrower_id,industry_type")
            .execute()
            .value) ?? []
        let sectorsByBorrower = Dictionary(uniqueKeysWithValues: employmentRows.map {
            ($0.borrowerId, ($0.industryType?.isEmpty == false ? $0.industryType! : "Unspecified"))
        })

        var disbursedBySector: [String: Double] = [:]
        var recoveredBySector: [String: Double] = [:]

        for application in applications where activeByApplication[application.id] != nil {
            let sector = sectorsByBorrower[application.borrowerId] ?? "Unspecified"
            disbursedBySector[sector, default: 0] += application.loanAmount
        }

        let repayments = (try? await repaymentRows(branch: branch)) ?? []
        let applicationById = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0) })
        for repayment in repayments {
            guard let application = applicationById[repayment.loanId] else { continue }
            let sector = sectorsByBorrower[application.borrowerId] ?? "Unspecified"
            recoveredBySector[sector, default: 0] += repayment.paidAmount ?? (repayment.status?.lowercased() == "paid" ? repayment.amount : 0)
        }

        return disbursedBySector.keys
            .map { sector in
                SectorPerformance(
                    sector: sector,
                    disbursed: (disbursedBySector[sector] ?? 0) / 1_000_000,
                    recovered: (recoveredBySector[sector] ?? 0) / 1_000_000
                )
            }
            .sorted { $0.disbursed > $1.disbursed }
    }
    
    func fetchLoanOfficers(branch: String? = nil) async throws -> [LoanOfficer] {
        let allUsers = try await managerUsers()
        let officers = branch != nil
            ? allUsers.filter { $0.role == "Loan Officer" && $0.branch == branch }
            : allUsers.filter { $0.role == "Loan Officer" }
        let borrowers = try await managerBorrowers(branch: branch)
        let branchBorrowerIds = branch != nil ? Set(borrowers.map { $0.id }) : nil
        let allApplications = try await managerApplications()
        let applications = branchBorrowerIds != nil
            ? allApplications.filter { branchBorrowerIds!.contains($0.borrowerId) }
            : allApplications
        let allActiveLoans = try await managerActiveLoans()
        let filteredAppIds = branchBorrowerIds != nil ? Set(applications.map { $0.id }) : nil
        let activeByApplication = Dictionary(uniqueKeysWithValues: (filteredAppIds != nil
            ? allActiveLoans.filter { active in
                guard let appId = active.applicationId else { return false }
                return filteredAppIds!.contains(appId)
            }
            : allActiveLoans
        ).compactMap { active in
            active.applicationId.map { ($0, active) }
        })

        return officers.map { officer in
            let assigned = applications.filter { $0.assignedOfficerId == officer.id }
            let approved = assigned.filter { $0.status == LoanStatus.approved.rawValue }.count
            let approvedAssigned = assigned.filter { $0.status == LoanStatus.approved.rawValue }
            let activeAssigned = approvedAssigned.filter { activeByApplication[$0.id] != nil }.count
            let defaulted = assigned.filter { activeByApplication[$0.id]?.isNpa == true }.count
            let approvalRate = assigned.isEmpty ? 0 : Double(approved) / Double(assigned.count) * 100
            let defaultRate = approvedAssigned.isEmpty ? 0 : Double(defaulted) / Double(approvedAssigned.count) * 100
            let initials = officer.fullName
                .split(separator: " ")
                .prefix(2)
                .compactMap { $0.first }
                .map(String.init)
                .joined()
                .uppercased()

            return LoanOfficer(
                id: officer.id,
                name: officer.fullName,
                role: officer.role,
                loansHandled: assigned.count,
                approvalRate: approvalRate,
                defaultRate: defaultRate,
                activeLoans: activeAssigned,
                initials: initials.isEmpty ? "LO" : initials
            )
        }
    }
    
    func fetchOverdueLoans(branch: String? = nil) async throws -> [OverdueLoan] {
        let branchBorrowers = try await managerBorrowers(branch: branch)
        let branchBorrowerIds = branch != nil ? Set(branchBorrowers.map { $0.id }) : nil
        let allApplications = try await managerApplications()
        let applicationsDict = Dictionary(uniqueKeysWithValues: allApplications.map { ($0.id, $0) })
        let filteredAppIds = branchBorrowerIds != nil
            ? Set(allApplications.filter { branchBorrowerIds!.contains($0.borrowerId) }.map { $0.id })
            : nil
        let borrowers = Dictionary(uniqueKeysWithValues: branchBorrowers.map { ($0.id, $0) })
        let users = Dictionary(uniqueKeysWithValues: try await managerUsers().map { ($0.id, $0) })
        let allActiveLoans = try await managerActiveLoans()
        let activeLoans = filteredAppIds != nil
            ? allActiveLoans.filter { active in
                guard let appId = active.applicationId else { return false }
                return filteredAppIds!.contains(appId)
            }
            : allActiveLoans
        let activeById = Dictionary(uniqueKeysWithValues: activeLoans.map { ($0.id, $0) })

        let emiRows: [ManagerEMIRow] = (try? await SupabaseManager.shared.adminClient
            .from("emi_schedule")
            .select("loan_id,due_date,amount,status")
            .execute()
            .value) ?? []

        let today = Calendar.current.startOfDay(for: Date())
        var overdueByApplication: [UUID: OverdueLoan] = [:]

        for emi in emiRows {
            let normalizedStatus = (emi.status ?? "").lowercased()
            guard normalizedStatus != "paid",
                  let dueDate = managerDate(from: emi.dueDate),
                  dueDate < today,
                  let activeId = emi.loanId,
                  let active = activeById[activeId],
                  let applicationId = active.applicationId,
                  let application = applicationsDict[applicationId] else {
                continue
            }

            let dpd = Calendar.current.dateComponents([.day], from: dueDate, to: today).day ?? 0
            let borrower = borrowers[application.borrowerId]
            let officer = application.assignedOfficerId.flatMap { users[$0]?.fullName } ?? "Unassigned"
            let existing = overdueByApplication[applicationId]
            if existing == nil || dpd > (existing?.dpd ?? 0) {
                overdueByApplication[applicationId] = OverdueLoan(
                    id: applicationId,
                    borrowerName: borrower?.fullName ?? "Unknown Borrower",
                    amount: CurrencyFormatter.indian(active.outstandingBalance > 0 ? active.outstandingBalance : emi.amount),
                    dpd: dpd,
                    risk: managerRisk(creditScore: borrower?.creditScore ?? 750, isNpa: active.isNpa == true || dpd >= 90),
                    officer: officer,
                    status: (active.isNpa == true || dpd >= 90) ? .defaulted : .overdue,
                    assignedOfficerId: application.assignedOfficerId?.uuidString
                )
            }
        }

        for active in activeLoans where active.isNpa == true {
            guard let applicationId = active.applicationId,
                  overdueByApplication[applicationId] == nil,
                  let application = applicationsDict[applicationId] else {
                continue
            }
            let borrower = borrowers[application.borrowerId]
            overdueByApplication[applicationId] = OverdueLoan(
                id: applicationId,
                borrowerName: borrower?.fullName ?? "Unknown Borrower",
                amount: CurrencyFormatter.indian(active.outstandingBalance),
                dpd: 90,
                risk: .high,
                officer: application.assignedOfficerId.flatMap { users[$0]?.fullName } ?? "Unassigned",
                status: .defaulted,
                assignedOfficerId: application.assignedOfficerId?.uuidString
            )
        }

        return overdueByApplication.values.sorted { $0.dpd > $1.dpd }
    }
    
    func fetchPortfolioSummaryMetrics(branch: String? = nil) async throws -> [DashboardMetric] {
        let snapshot = try await fetchPortfolioSnapshot(branch: branch)
        
        return [
            DashboardMetric(
                title: "Total Portfolio",
                value: CurrencyFormatter.indian(snapshot.totalPortfolio),
                change: "Lifetime Value",
                iconName: "briefcase.fill",
                accent: "green"
            ),
            DashboardMetric(
                title: "Active Loans",
                value: "\(snapshot.activeLoanCount)",
                change: "Currently Open",
                iconName: "doc.text.fill",
                accent: "blue"
            ),
            DashboardMetric(
                title: "Recovered",
                value: CurrencyFormatter.indian(snapshot.totalRecovered),
                change: "Funds Collected",
                iconName: "arrow.triangle.2.circlepath",
                accent: "green"
            ),
            DashboardMetric(
                title: "Outstanding",
                value: CurrencyFormatter.indian(snapshot.outstandingBalance),
                change: "To be Collected",
                iconName: "clock.arrow.2.circlepath",
                accent: "orange"
            )
        ]
    }

    func fetchRiskSummaryMetrics(branch: String? = nil) async throws -> [DashboardMetric] {
        let snapshot = try await fetchPortfolioSnapshot(branch: branch)
        
        return [
            DashboardMetric(
                title: "Total PAR",
                value: CurrencyFormatter.indian(snapshot.overdueExposure),
                change: "At Risk",
                iconName: "exclamationmark.triangle.fill",
                accent: "red"
            ),
            DashboardMetric(
                title: "NPA Cases",
                value: "\(snapshot.npaCaseCount)",
                change: "Defaulted",
                iconName: "person.fill.xmark",
                accent: "orange"
            )
        ]
    }
    
    func fetchReportTypes() async throws -> [InsightReportType] {
        return try await client
            .from("report_types")
            .select()
            .execute()
            .value
    }

    func fetchRepayments(loanId: UUID) async throws -> [Repayment] {
        return try await client
            .from("repayment_history")
            .select()
            .eq("loan_id", value: loanId)
            .order("due_date", ascending: true)
            .execute()
            .value
    }


    // MARK: - Loan Updates

    func updateLoanStatus(id: UUID, status: LoanStatus, comment: String? = nil) async throws {
        var updateData: [String: AnyJSON] = ["status": .string(status.rawValue)]
        if let comment = comment {
            updateData["status_comment"] = .string(comment)
        }
        try await client
            .from("loan_application")
            .update(updateData)
            .eq("id", value: id)
            .execute()
    }

    func assignRecoveryOfficer(loanId: UUID, officerId: String) async throws {
        let updateData: [String: AnyJSON] = ["assigned_officer_id": .string(officerId)]
        try await client
            .from("loan_application")
            .update(updateData)
            .eq("id", value: loanId)
            .execute()
    }

    // MARK: - User Profile

    func updateBasicProfile(id: UUID, fullName: String, email: String, phone: String? = nil) async throws {
        var updateData: [String: AnyJSON] = [
            "full_name": .string(fullName),
            "email": .string(email)
        ]
        if let phone = phone {
            updateData["phone"] = .string(phone)
        }
        try await client
            .from("users")
            .update(updateData)
            .eq("id", value: id)
            .execute()
    }

    func updateCurrentUserProfile(id: UUID, fullName: String, email: String, phone: String, branch: String) async throws {
        let normalizedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let updateData: [String: AnyJSON] = [
            "full_name": .string(fullName),
            "email": .string(email),
            "phone": .string(normalizedPhone),
            "branch": .string(branch)
        ]

        try await client
            .from("users")
            .update(updateData)
            .eq("id", value: id)
            .execute()

        try await SupabaseManager.shared.adminClient.auth.admin.updateUserById(
            id,
            attributes: AdminUserAttributes(
                email: email,
                userMetadata: [
                    "full_name": .string(fullName),
                    "email": .string(email),
                    "phone": .string(normalizedPhone)
                ]
            )
        )
    }

    // MARK: - Manager Settings

    func fetchManagerSettings(userId: UUID) async throws -> ManagerSettings? {
        do {
            let settings: ManagerSettings = try await client
                .from("manager_settings")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            return settings
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }

    func upsertManagerSettings(_ settings: ManagerSettings) async throws -> ManagerSettings {
        let updated: ManagerSettings = try await client
            .from("manager_settings")
            .upsert(settings)
            .eq("user_id", value: settings.userId)
            .single()
            .execute()
            .value
        return updated
    }

    // MARK: - Documents (BOTH SYSTEMS)

    // Borrower documents (your feature)
    func fetchBorrowerDocuments(borrowerId: UUID) async throws -> BorrowerDocumentRecord? {
        let records: [BorrowerDocumentRecord] = try await client
            .from("documents")
            .select()
            .eq("borrower_id", value: borrowerId)
            .execute()
            .value
        return records.first
    }

    func getDocumentUrl(storagePath: String) -> URL {
        try! client.storage
            .from(SupabaseConfig.storageBucket)
            .getPublicURL(path: storagePath)
    }

    // Application documents (Admin feature)
    func fetchApplicationDocuments(applicationId: UUID) async throws -> [ApplicationDocument] {
        return try await client
            .from("application_documents")
            .select()
            .eq("application_id", value: applicationId)
            .execute()
            .value
    }

    func fetchLoanApplicationDocumentsClient(applicationId: UUID) async throws -> [LoanApplicationDocument] {
        return try await client
            .from("loan_application_documents")
            .select()
            .eq("application_id", value: applicationId)
            .execute()
            .value
    }

    func updateDocumentStatus(documentId: UUID, status: String, remarks: String? = nil) async throws {
        var updateData: [String: AnyJSON] = ["status": .string(status)]
        if let remarks = remarks {
            updateData["remarks"] = .string(remarks)
        }

        try await client
            .from("loan_application_documents")
            .update(updateData)
            .eq("id", value: documentId)
            .execute()
    }

    /// Upsert a document verification status.
    /// For documents already in `loan_application_documents`, updates the row.
    /// For legacy documents (from the `documents` table), checks if a tracking row
    /// already exists (by application_id + document_type) and updates it, or inserts a new one.
    /// Uses adminClient to bypass RLS restrictions.
    func upsertDocumentStatus(
        documentId: UUID?,
        applicationId: UUID,
        borrowerId: UUID,
        documentType: String,
        fileUrl: String,
        status: String,
        remarks: String? = nil
    ) async throws {
        let adminClient = SupabaseManager.shared.adminClient

        var updateData: [String: AnyJSON] = ["status": .string(status)]
        if let remarks = remarks {
            updateData["remarks"] = .string(remarks)
        }

        if let docId = documentId {
            // We have a known DB row id — update directly
            try await adminClient
                .from("loan_application_documents")
                .update(updateData)
                .eq("id", value: docId)
                .execute()
            print("✅ Document \(docId) updated to status: \(status)")
        } else {
            // Legacy doc: check if a row already exists for this app + doc type
            let existing: [DBLoanApplicationDocument] = try await adminClient
                .from("loan_application_documents")
                .select()
                .eq("application_id", value: applicationId)
                .eq("document_type", value: documentType)
                .limit(1)
                .execute()
                .value

            if let existingDoc = existing.first {
                // Row exists — update it
                try await adminClient
                    .from("loan_application_documents")
                    .update(updateData)
                    .eq("id", value: existingDoc.id)
                    .execute()
                print("✅ Existing row \(existingDoc.id) updated to status: \(status)")
            } else {
                // No row yet — insert one
                var insertData: [String: AnyJSON] = [
                    "application_id": .string(applicationId.uuidString),
                    "borrower_id": .string(borrowerId.uuidString),
                    "document_type": .string(documentType),
                    "file_url": .string(fileUrl),
                    "status": .string(status)
                ]
                if let remarks = remarks {
                    insertData["remarks"] = .string(remarks)
                }
                try await adminClient
                    .from("loan_application_documents")
                    .insert(insertData)
                    .execute()
                print("✅ New row inserted for '\(documentType)' with status: \(status)")
            }
        }
    }

    // MARK: - Generated Reports (Sync with Supabase)
    
    var generatedReports: [GeneratedReport] = []

    func fetchGeneratedReports() async {
        do {
            let fetched: [GeneratedReport] = try await SupabaseManager.shared.adminClient
                .from("generated_reports")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.generatedReports = fetched
            }
        } catch {
            print("Error fetching generated reports: \(error)")
        }
    }

    func uploadGeneratedReport(data: Data, fileName: String, contentType: String = "application/pdf") async throws -> String {
        let path = "reports/\(fileName)"
        
        try await SupabaseManager.shared.adminClient.storage
            .from(SupabaseConfig.storageBucket)
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: contentType, upsert: true)
            )
        
        let url = try SupabaseManager.shared.adminClient.storage
            .from(SupabaseConfig.storageBucket)
            .getPublicURL(path: path)
        
        return url.absoluteString
    }

    func saveGeneratedReportRecord(_ report: GeneratedReport) async {
        do {
            try await SupabaseManager.shared.adminClient
                .from("generated_reports")
                .insert(report)
                .execute()
            
            await fetchGeneratedReports()
        } catch {
            print("Error saving report record: \(error)")
        }
    }

    func deleteGeneratedReport(id: UUID, fileUrl: String) async {
        do {
            // 1. Delete from DB
            try await SupabaseManager.shared.adminClient
                .from("generated_reports")
                .delete()
                .eq("id", value: id)
                .execute()
            
            // 2. Delete from Storage (extract path from URL)
            if let path = fileUrl.components(separatedBy: "/\(SupabaseConfig.storageBucket)/").last {
                try? await SupabaseManager.shared.adminClient.storage
                    .from(SupabaseConfig.storageBucket)
                    .remove(paths: [path])
            }
            
            await fetchGeneratedReports()
        } catch {
            print("Error deleting report: \(error)")
        }
    }

    // MARK: - Borrowers
    
    func fetchBorrowers() async {
        do {
            let fetchedBorrowers: [Borrower] = try await client
                .from("borrower")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                self.borrowers = fetchedBorrowers
            }
        } catch {
            print("Error fetching borrowers: \(error)")
        }
    }
    
    // MARK: - Loan Officer
    
    /// Fetch all loan applications assigned to a specific officer
    func fetchOfficerApplications(officerId: UUID) async throws -> [DBLoanApplication] {
        do {
            let apps: [DBLoanApplication] = try await client
                .from("loan_application")
                .select()
                .eq("assigned_officer_id", value: officerId)
                .order("created_at", ascending: false)
                .execute()
                .value
            print("Officer apps fetched successfully: \(apps.count)")
            return apps
        } catch {
            print("DECODE ERROR in fetchOfficerApplications: \(error)")
            throw error
        }
    }
    
    /// Fetch a single borrower by ID
    func fetchBorrowerDetail(borrowerId: UUID) async throws -> DBBorrower {
        let results: [DBBorrower] = try await client
            .from("borrower")
            .select()
            .eq("id", value: borrowerId)
            .limit(1)
            .execute()
            .value
        
        guard let borrower = results.first else {
            throw NSError(domain: "DatabaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Borrower not found: \(borrowerId)"])
        }
        return borrower
    }
    
    /// Fetch employment record for a borrower
    func fetchEmployment(borrowerId: UUID) async throws -> DBEmployment? {
        let results: [DBEmployment] = try await client
            .from("employment")
            .select()
            .eq("borrower_id", value: borrowerId)
            .execute()
            .value
        return results.first
    }
    
    /// Fetch financials record for a borrower
    func fetchFinancials(borrowerId: UUID) async throws -> DBFinancials? {
        let results: [DBFinancials] = try await client
            .from("financials")
            .select()
            .eq("borrower_id", value: borrowerId)
            .execute()
            .value
        return results.first
    }
    
    /// Fetch credit profile for a borrower
    func fetchCreditProfile(borrowerId: UUID) async throws -> DBCreditProfile? {
        let results: [DBCreditProfile] = try await client
            .from("credit_profile")
            .select()
            .eq("borrower_id", value: borrowerId)
            .execute()
            .value
        return results.first
    }
    
    /// Fetch documents for a borrower (legacy column-based table)
    func fetchDocuments(borrowerId: UUID) async throws -> DBDocuments? {
        let results: [DBDocuments] = try await client
            .from("documents")
            .select()
            .eq("borrower_id", value: borrowerId)
            .execute()
            .value
        return results.first
    }
    
    /// Fetch uploaded documents for a borrower.
    /// Converts the legacy column-based `documents` table into a scalable row-based array.
    func fetchUploadedDocuments(borrowerId: UUID) async throws -> [BorrowerUploadedDocument] {
        if let legacy = try await fetchDocuments(borrowerId: borrowerId) {
            return legacy.toUploadedDocuments()
        }
        return []
    }
    
    /// Update loan application status (approve / reject / recommend)
    func updateLoanStatus(loanId: UUID, status: LoanApplicationStatus, comment: String? = nil) async throws {
        var updateData: [String: AnyJSON] = ["status": .string(status.rawValue)]
        if let comment = comment {
            updateData["status_comment"] = .string(comment)
        }
        try await client
            .from("loan_application")
            .update(updateData)
            .eq("id", value: loanId)
            .execute()
    }
    
    /// Fetch all loan applications for a borrower (loan history)
    func fetchBorrowerLoanHistory(borrowerId: UUID) async throws -> [DBLoanApplication] {
        return try await client
            .from("loan_application")
            .select()
            .eq("borrower_id", value: borrowerId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    

    /// Fetch documents from the `loan_application_documents` table (row-per-document)
    func fetchLoanApplicationDocuments(applicationId: UUID) async throws -> [DBLoanApplicationDocument] {
        return try await SupabaseManager.shared.adminClient
            .from("loan_application_documents")
            .select()
            .eq("application_id", value: applicationId)
            .execute()
            .value
    }
    

    // MARK: - Chat Messages

    private var chatChannel: RealtimeChannelV2?
    private var chatSubscriptionTask: Task<Void, Never>?

    func fetchMessages(applicationId: UUID) async throws -> [DBChatMessage] {
        return try await client
            .from("chat_messages")
            .select()
            .eq("application_id", value: applicationId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    @discardableResult
    func sendMessage(applicationId: UUID, senderId: UUID, content: String, messageType: ChatMessageType, documentType: String?) async throws -> DBChatMessage {
        var insertData: [String: AnyJSON] = [
            "application_id": .string(applicationId.uuidString),
            "sender_id": .string(senderId.uuidString),
            "content": .string(content),
            "message_type": .string(messageType.rawValue)
        ]
        if let documentType {
            insertData["document_type"] = .string(documentType)
        } else {
            insertData["document_type"] = .null
        }

        let saved: DBChatMessage = try await client
            .from("chat_messages")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value
        return saved
    }

    func subscribeToMessages(applicationId: UUID, onNewMessage: @escaping (DBChatMessage) -> Void) {
        unsubscribeFromMessages()

        let channel = client.channel("chat_\(applicationId.uuidString)")

        Task {
            do {
                let stream = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "chat_messages",
                    filter: "application_id=eq.\(applicationId.uuidString)"
                )

                try await channel.subscribeWithError()
                chatChannel = channel

                for await insertion in stream {
                    do {
                        let jsonData = try JSONEncoder().encode(insertion.record)
                        let message = try JSONDecoder().decode(DBChatMessage.self, from: jsonData)
                        onNewMessage(message)
                    } catch {
                        print("Error decoding realtime message: \(error)")
                    }
                }
            } catch {
                print("Error subscribing to chat messages: \(error)")
            }
        }
    }

    func unsubscribeFromMessages() {
        chatSubscriptionTask?.cancel()
        chatSubscriptionTask = nil
        if let channel = chatChannel {
            Task {
                await client.removeChannel(channel)
            }
            chatChannel = nil
        }
    }
    /// Assemble full LoanCase objects for all applications assigned to an officer.
    /// Fetches each borrower's sub-records in parallel per application.
    func fetchFullLoanCases(officerId: UUID) async throws -> [LoanCase] {
        let applications = try await fetchOfficerApplications(officerId: officerId)
        
        var cases: [LoanCase] = []
        
        for app in applications {
            guard let borrowerId = app.borrowerId else { continue }
            
            async let borrowerTask = fetchBorrowerDetail(borrowerId: borrowerId)
            async let employmentTask = fetchEmployment(borrowerId: borrowerId)
            async let financialsTask = fetchFinancials(borrowerId: borrowerId)
            async let creditTask = fetchCreditProfile(borrowerId: borrowerId)
            async let docsTask = fetchDocuments(borrowerId: borrowerId)
            async let appDocsTask = fetchLoanApplicationDocuments(applicationId: app.id)
            
            do {
                let borrower = try await borrowerTask
                
                var employment: DBEmployment? = nil
                do { employment = try await employmentTask } catch { print("⚠️ Employment fetch failed for \(borrowerId): \(error)") }
                
                var financials: DBFinancials? = nil
                do { financials = try await financialsTask } catch { print("⚠️ Financials fetch failed for \(borrowerId): \(error)") }
                
                var credit: DBCreditProfile? = nil
                do { credit = try await creditTask } catch { print("⚠️ CreditProfile fetch failed for \(borrowerId): \(error)") }
                
                var docs: DBDocuments? = nil
                do { docs = try await docsTask } catch { print("⚠️ Documents fetch failed for \(borrowerId): \(error)") }
                
                var appDocs: [DBLoanApplicationDocument] = []
                do { appDocs = try await appDocsTask } catch { print("⚠️ AppDocs fetch failed for \(app.id): \(error)") }
                
                // Merge legacy column-based docs + application-specific row-based docs
                let legacyUploaded = docs?.toUploadedDocuments() ?? []
                let appUploaded = appDocs.map { $0.toUploadedDocument() }
                let uploadedDocs = legacyUploaded + appUploaded
                
                // Fetch required documents from the loan product if product_id exists
                var requiredDocs: [LoanDocumentRequirement]? = nil
                if let productId = app.productId {
                    if let product = try? await fetchLoanProduct(by: productId) {
                        requiredDocs = product.requiredDocuments
                    }
                }
                
                let loanCase = LoanCase(
                    id: app.id,
                    application: app,
                    borrower: borrower,
                    employment: employment,
                    financials: financials,
                    creditProfile: credit,
                    documents: docs,
                    uploadedDocuments: uploadedDocs,
                    requiredDocuments: requiredDocs,
                    appDocuments: appDocs
                )
                cases.append(loanCase)
            } catch {
                print("Error assembling loan case for application \(app.id): \(error)")
            }
        }
        
        return cases
    }
    // MARK: - Insights Analytics

    func fetchPortfolioHealthKPIs(branch: String? = nil) async throws -> [KPIData] {
        let snapshot = try await fetchPortfolioSnapshot(branch: branch)
        let npaRatio = snapshot.totalPortfolio > 0 ? (snapshot.overdueExposure / snapshot.totalPortfolio) * 100 : 0

        return [
            KPIData(id: UUID(), title: "Total Portfolio", value: CurrencyFormatter.indian(snapshot.totalPortfolio), change: "Approved loans"),
            KPIData(id: UUID(), title: "Active Loans", value: "\(snapshot.activeLoanCount)", change: "Currently open"),
            KPIData(id: UUID(), title: "Outstanding", value: CurrencyFormatter.indian(snapshot.outstandingBalance), change: "To be collected"),
            KPIData(id: UUID(), title: "NPA Ratio", value: String(format: "%.2f%%", npaRatio), change: "vs approved portfolio")
        ]
    }

    func fetchPortfolioGrowth(branch: String? = nil) async throws -> [ChartDataEntry] {
        let allApplications = try await managerApplications()
        let approvedApplications = allApplications.filter { $0.status == LoanStatus.approved.rawValue }
        if let branch {
            let borrowers = try await managerBorrowers(branch: branch)
            let borrowerIds = Set(borrowers.map { $0.id })
            let filtered = approvedApplications.filter { borrowerIds.contains($0.borrowerId) }
            let grouped = Dictionary(grouping: filtered) { managerMonthLabel(from: $0.createdAt) }
            var runningTotal = 0.0
            return grouped
                .map { month, rows in
                    (month: month, order: managerMonthOrder(month), amount: rows.map(\.loanAmount).reduce(0, +))
                }
                .sorted { $0.order < $1.order }
                .map { item in
                    runningTotal += item.amount
                    return ChartDataEntry(id: UUID(), label: item.month, category: "Approved", value: runningTotal / 10_000_000)
                }
        }
        let grouped = Dictionary(grouping: approvedApplications) { managerMonthLabel(from: $0.createdAt) }
        var runningTotal = 0.0

        return grouped
            .map { month, rows in
                (month: month, order: managerMonthOrder(month), amount: rows.map(\.loanAmount).reduce(0, +))
            }
            .sorted { $0.order < $1.order }
            .map { item in
                runningTotal += item.amount
                return ChartDataEntry(id: UUID(), label: item.month, category: "Approved", value: runningTotal / 10_000_000)
            }
    }

    func fetchPortfolioStatus(branch: String? = nil) async throws -> [ChartDataEntry] {
        let allApplications = try await managerApplications()
        let applications: [ManagerLoanApplicationRow]
        if let branch {
            let borrowers = try await managerBorrowers(branch: branch)
            let borrowerIds = Set(borrowers.map { $0.id })
            applications = allApplications.filter { borrowerIds.contains($0.borrowerId) }
        } else {
            applications = allApplications
        }
        let grouped = Dictionary(grouping: applications) { $0.status ?? LoanStatus.submitted.rawValue }
        return grouped
            .map { status, rows in
                let label = status
                    .split(separator: "_")
                    .map { $0.capitalized }
                    .joined(separator: " ")
                return ChartDataEntry(id: UUID(), label: label, category: status, value: Double(rows.count))
            }
            .sorted { $0.label < $1.label }
    }

    private func repaymentRows(branch: String? = nil) async throws -> [ManagerRepaymentRow] {
        var repayments: [ManagerRepaymentRow]
        let fromRepayments: [ManagerRepaymentRow] = try await SupabaseManager.shared.adminClient
            .from("repayments")
            .select("loan_id,due_date,amount,paid_amount,status,paid_at")
            .execute()
            .value
        if !fromRepayments.isEmpty {
            repayments = fromRepayments
        } else {
            repayments = try await SupabaseManager.shared.adminClient
                .from("repayment_history")
                .select("loan_id,due_date,amount,status,paid_at")
                .execute()
                .value
        }
        if let branch {
            let borrowers = try await managerBorrowers(branch: branch)
            let borrowerIds = Set(borrowers.map { $0.id })
            let applications = try await managerApplications()
            let branchAppIds = Set(applications.filter { borrowerIds.contains($0.borrowerId) }.map { $0.id })
            repayments = repayments.filter { branchAppIds.contains($0.loanId) }
        }
        return repayments
    }

    private func repaymentActualsByMonth(_ repayments: [ManagerRepaymentRow]) -> [ChartDataEntry] {
        let grouped = Dictionary(grouping: repayments) { row in
            managerMonthLabel(from: row.paidAt ?? row.dueDate)
        }
        return grouped
            .map { month, rows in
                let actual = rows.reduce(0) { total, row in
                    total + (row.paidAmount ?? (row.status?.lowercased() == "paid" ? row.amount : 0))
                }
                return ChartDataEntry(id: UUID(), label: month, category: "Actual", value: actual / 100_000)
            }
            .sorted { managerMonthOrder($0.label) < managerMonthOrder($1.label) }
    }

    func fetchRepaymentKPIs(branch: String? = nil) async throws -> [KPIData] {
        let repayments = try await repaymentRows(branch: branch)
        let totalDue = repayments.map(\.amount).reduce(0, +)
        let totalCollected = repayments.reduce(0) { total, row in
            total + (row.paidAmount ?? (row.status?.lowercased() == "paid" ? row.amount : 0))
        }
        let missed = repayments.filter { ($0.status ?? "").localizedCaseInsensitiveContains("miss") || ($0.status ?? "").localizedCaseInsensitiveContains("overdue") }.count
        let efficiency = totalDue > 0 ? (totalCollected / totalDue) * 100 : 0

        return [
            KPIData(id: UUID(), title: "Total Collected", value: CurrencyFormatter.indian(totalCollected), change: "Received"),
            KPIData(id: UUID(), title: "Expected Collection", value: CurrencyFormatter.indian(totalDue), change: "Scheduled"),
            KPIData(id: UUID(), title: "Missed Payments", value: "\(missed)", change: missed > 0 ? "Needs follow-up" : "On track"),
            KPIData(id: UUID(), title: "Collection Efficiency", value: String(format: "%.1f%%", efficiency), change: "Actual vs target")
        ]
    }

    func fetchRepaymentTrends(branch: String? = nil) async throws -> [ChartDataEntry] {
        let repayments = try await repaymentRows(branch: branch)
        return repaymentActualsByMonth(repayments)
    }

    func fetchRepaymentTargets(branch: String? = nil) async throws -> [ChartDataEntry] {
        let repayments = try await repaymentRows(branch: branch)
        let grouped = Dictionary(grouping: repayments) { managerMonthLabel(from: $0.dueDate) }

        return grouped.flatMap { month, rows in
            let target = rows.map(\.amount).reduce(0, +) / 100_000
            let actual = rows.reduce(0) { total, row in
                total + (row.paidAmount ?? (row.status?.lowercased() == "paid" ? row.amount : 0))
            } / 100_000
            return [
                ChartDataEntry(id: UUID(), label: month, category: "Target", value: target),
                ChartDataEntry(id: UUID(), label: month, category: "Actual", value: actual)
            ]
        }
        .sorted { managerMonthOrder($0.label) < managerMonthOrder($1.label) }
    }

    func fetchRepaymentCumulative(branch: String? = nil) async throws -> [ChartDataEntry] {
        let monthly = try await fetchRepaymentTrends(branch: branch).sorted { managerMonthOrder($0.label) < managerMonthOrder($1.label) }
        var runningTotal = 0.0
        return monthly.map { item in
            runningTotal += item.value
            return ChartDataEntry(id: UUID(), label: item.label, category: "Cumulative", value: runningTotal)
        }
    }

    func fetchNPAKPIs(branch: String? = nil) async throws -> [KPIData] {
        let snapshot = try await fetchPortfolioSnapshot(branch: branch)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let code = systemConfig.defaultCurrency.uppercased()
        formatter.currencySymbol = (code == "INR") ? "₹" : ((code == "USD") ? "$" : code + " ")
        formatter.maximumFractionDigits = 0
        
        return [
            KPIData(id: UUID(), title: "Total NPA Exposure", value: formatter.string(from: NSNumber(value: snapshot.overdueExposure)) ?? "₹0", change: "At Risk"),
            KPIData(id: UUID(), title: "NPA Cases", value: "\(snapshot.npaCaseCount)", change: snapshot.npaCaseCount > 0 ? "Action Required" : "Stable"),
            KPIData(id: UUID(), title: "NPA Ratio", value: String(format: "%.2f%%", snapshot.totalPortfolio > 0 ? (snapshot.overdueExposure / snapshot.totalPortfolio) * 100 : 0), change: "vs Portfolio"),
            KPIData(id: UUID(), title: "Provisioning Coverage", value: "85.0%", change: "Regulatory Standard")
        ]
    }

    func fetchNPAAgingBuckets(branch: String? = nil) async throws -> [ChartDataEntry] {
        let overdueLoans = try await fetchOverdueLoans(branch: branch)
        let buckets: [(String, ClosedRange<Int>)] = [
            ("1-30", 1...30),
            ("31-60", 31...60),
            ("61-90", 61...90),
            ("90+", 91...Int.max)
        ]

        return buckets.map { label, range in
            ChartDataEntry(
                id: UUID(),
                label: label,
                category: "DPD",
                value: Double(overdueLoans.filter { range.contains($0.dpd) }.count)
            )
        }
    }

    func fetchNPATrends(branch: String? = nil) async throws -> [ChartDataEntry] {
        let allApplications = try await managerApplications()
        let allActiveLoans = try await managerActiveLoans()
        let applications: [ManagerLoanApplicationRow]
        let activeLoans: [ManagerActiveLoanRow]
        if let branch {
            let borrowers = try await managerBorrowers(branch: branch)
            let borrowerIds = Set(borrowers.map { $0.id })
            let filteredAppIds = Set(allApplications.filter { borrowerIds.contains($0.borrowerId) }.map { $0.id })
            applications = allApplications.filter { borrowerIds.contains($0.borrowerId) }
            activeLoans = allActiveLoans.filter { active in
                guard let appId = active.applicationId else { return false }
                return filteredAppIds.contains(appId)
            }
        } else {
            applications = allApplications
            activeLoans = allActiveLoans
        }
        let applicationsDict = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: activeLoans) { managerMonthLabel(from: $0.disbursedAt) }

        return grouped
            .map { month, rows in
                let npaExposure = rows.filter { $0.isNpa == true }.map(\.outstandingBalance).reduce(0, +)
                let approvedAmount = rows.reduce(0) { total, active in
                    guard let applicationId = active.applicationId,
                          applicationsDict[applicationId]?.status == LoanStatus.approved.rawValue else {
                        return total
                    }
                    return total + (applicationsDict[applicationId]?.loanAmount ?? 0)
                }
                let ratio = approvedAmount > 0 ? (npaExposure / approvedAmount) * 100 : 0
                return ChartDataEntry(id: UUID(), label: month, category: "NPA", value: ratio)
            }
            .sorted { managerMonthOrder($0.label) < managerMonthOrder($1.label) }
    }

    func fetchNPAExposure(branch: String? = nil) async throws -> [ChartDataEntry] {
        let allApplications = try await managerApplications()
        let allActiveLoans = try await managerActiveLoans()
        let npaLoans = allActiveLoans.filter { $0.isNpa == true }
        let applicationsDict: [UUID: ManagerLoanApplicationRow]
        let filteredNpaLoans: [ManagerActiveLoanRow]
        if let branch {
            let borrowers = try await managerBorrowers(branch: branch)
            let borrowerIds = Set(borrowers.map { $0.id })
            let filteredAppIds = Set(allApplications.filter { borrowerIds.contains($0.borrowerId) }.map { $0.id })
            applicationsDict = Dictionary(uniqueKeysWithValues: allApplications.filter { borrowerIds.contains($0.borrowerId) }.map { ($0.id, $0) })
            filteredNpaLoans = npaLoans.filter { active in
                guard let appId = active.applicationId else { return false }
                return filteredAppIds.contains(appId)
            }
        } else {
            applicationsDict = Dictionary(uniqueKeysWithValues: allApplications.map { ($0.id, $0) })
            filteredNpaLoans = npaLoans
        }
        var exposureByType: [String: Double] = ["Secured": 0, "Unsecured": 0]

        for active in filteredNpaLoans {
            guard let applicationId = active.applicationId,
                  let application = applicationsDict[applicationId] else {
                continue
            }
            let purpose = (application.purpose ?? "").lowercased()
            let secured = purpose.contains("home")
                || purpose.contains("vehicle")
                || purpose.contains("auto")
                || purpose.contains("business")
                || purpose.contains("property")
            exposureByType[secured ? "Secured" : "Unsecured", default: 0] += active.outstandingBalance
        }

        return exposureByType.map { type, amount in
            ChartDataEntry(id: UUID(), label: type, category: type, value: amount / 10_000_000)
        }
        .sorted { $0.label < $1.label }
    }

    func fetchAuditComplianceKPIs(branch: String? = nil, actor: String? = nil) async throws -> [KPIData] {
        let entries = try await fetchAuditTrailEntries(branch: branch, actor: actor)
        let completed = entries.filter { $0.displayStatus.localizedCaseInsensitiveContains("complete") }.count
        let pending = entries.filter { $0.displayStatus.localizedCaseInsensitiveContains("pending") }.count
        let critical = entries.filter {
            $0.displayStatus.localizedCaseInsensitiveContains("critical")
            || $0.displayStatus.localizedCaseInsensitiveContains("failed")
            || $0.displayStatus.localizedCaseInsensitiveContains("rejected")
        }.count

        return [
            KPIData(id: UUID(), title: "Total Audits", value: "\(entries.count)", change: "All records"),
            KPIData(id: UUID(), title: "Completed", value: "\(completed)", change: "Closed"),
            KPIData(id: UUID(), title: "Pending", value: "\(pending)", change: "Open"),
            KPIData(id: UUID(), title: "Critical Issues", value: "\(critical)", change: critical > 0 ? "Review needed" : "Clear")
        ]
    }

    func fetchAuditStatus(branch: String? = nil, actor: String? = nil) async throws -> [ChartDataEntry] {
        let entries = try await fetchAuditTrailEntries(branch: branch, actor: actor)
        let grouped = Dictionary(grouping: entries) { $0.displayStatus.isEmpty ? "Unknown" : $0.displayStatus }
        return grouped
            .map { status, rows in ChartDataEntry(id: UUID(), label: status, category: status, value: Double(rows.count)) }
            .sorted { $0.label < $1.label }
    }

    func fetchAuditIssueSeverity(branch: String? = nil, actor: String? = nil) async throws -> [ChartDataEntry] {
        let entries = try await fetchAuditTrailEntries(branch: branch, actor: actor)
        let grouped = Dictionary(grouping: entries) { entry in
            let status = entry.displayStatus.lowercased()
            if status.contains("critical") || status.contains("failed") || status.contains("rejected") { return "Critical" }
            if status.contains("pending") || status.contains("review") { return "Warning" }
            return "Normal"
        }
        return grouped
            .map { severity, rows in ChartDataEntry(id: UUID(), label: severity, category: severity, value: Double(rows.count)) }
            .sorted { $0.label < $1.label }
    }

    func fetchAuditTrailEntries(branch: String? = nil, actor: String? = nil) async throws -> [AuditEntry] {
        var query = SupabaseManager.shared.client
            .from("audit_trail")
            .select()
        if let branch {
            query = query.eq("branch", value: branch)
        }
        if let actor {
            query = query.eq("actor", value: actor)
        }
        return try await query
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // Loan compliance log — real loan actions from loan_application table
    struct LoanComplianceEntry: Identifiable, Codable {
        let id: UUID
        let status: String
        let createdAt: String
        let loanAmount: Double?
        let borrowerId: UUID?
        let assignedOfficerId: UUID?

        enum CodingKeys: String, CodingKey {
            case id
            case status
            case createdAt = "created_at"
            case loanAmount = "loan_amount"
            case borrowerId = "borrower_id"
            case assignedOfficerId = "assigned_officer_id"
        }

        var displayStatus: String {
            switch status {
            case "submitted":              return "Submitted"
            case "under_review":           return "Under Review"
            case "recommended":            return "Recommended"
            case "approved":               return "Approved"
            case "rejected":               return "Rejected"
            case "returned_for_correction": return "Returned"
            default:                       return status.capitalized
            }
        }

        var date: String { String(createdAt.prefix(10)) }
    }

    func fetchLoanComplianceLog() async throws -> [LoanComplianceEntry] {
        return try await SupabaseManager.shared.adminClient
            .from("loan_application")
            .select("id, status, created_at, loan_amount, borrower_id, assigned_officer_id")
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
    }
    
    // MARK: - GDPR Compliance (Admin Only)
    
    func fetchPrivacySettings() async {
        do {
            let settings: [PrivacySettings] = try await SupabaseManager.shared.adminClient
                .from("privacy_settings")
                .select()
                .limit(1)
                .execute()
                .value
            
            if let first = settings.first {
                await MainActor.run {
                    self.privacySettings = first
                }
            }
        } catch {
            print("Error fetching privacy settings: \(error)")
        }
    }
    
    func savePrivacySettings(_ settings: PrivacySettings) async {
        do {
            try await SupabaseManager.shared.adminClient
                .from("privacy_settings")
                .upsert(settings)
                .execute()
            await fetchPrivacySettings()
        } catch {
            print("Error saving privacy settings: \(error)")
        }
    }
    
    func fetchConsentTemplates() async {
        do {
            let templates: [ConsentTemplate] = try await SupabaseManager.shared.adminClient
                .from("consent_templates")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.consentTemplates = templates
            }
        } catch {
            print("Error fetching consent templates: \(error)")
        }
    }
    
    func saveConsentTemplate(_ template: ConsentTemplate) async {
        do {
            try await SupabaseManager.shared.adminClient
                .from("consent_templates")
                .upsert(template)
                .execute()
            await fetchConsentTemplates()
        } catch {
            print("Error saving consent template: \(error)")
        }
    }
    
    func fetchSystemConfig() async {
        do {
            let configs: [SystemConfig] = try await SupabaseManager.shared.adminClient
                .from("system_config")
                .select()
                .limit(1)
                .execute()
                .value
            
            if let config = configs.first {
                var sanitized = config
                if sanitized.institutionName.localizedCaseInsensitiveContains("credflow") {
                    sanitized.institutionName = "उधार De Institutional Banking"
                }
                
                await MainActor.run {
                    self.systemConfig = sanitized
                }
            }
        } catch {
            print("Error fetching system config: \(error)")
        }
    }
    
    func saveSystemConfig(_ config: SystemConfig) async {
        do {
            try await SupabaseManager.shared.adminClient
                .from("system_config")
                .upsert(config)
                .execute()
            await fetchSystemConfig()
        } catch {
            print("Error saving system config: \(error)")
        }
    }
    
    // MARK: - Sanction Letter
    func uploadSanctionLetter(pdfData: Data, loanId: UUID) async throws -> String {
        let fileName = "sanction_letter_\(loanId.uuidString).pdf"
        let path = "sanction-letters/\(fileName)"

        // Upload to Storage
        try await SupabaseManager.shared.client.storage
            .from(SupabaseConfig.storageBucket)
            .upload(
                path: path,
                file: pdfData,
                options: FileOptions(contentType: "application/pdf", upsert: true)
            )

        // Get public URL
        let url = try SupabaseManager.shared.client.storage
            .from(SupabaseConfig.storageBucket)
            .getPublicURL(path: path)

        let urlString = url.absoluteString
        print("✅ PDF uploaded: \(urlString)")

        // Update active_loan — match on application_id
        let updateData: [String: AnyJSON] = [
            "sanction_letter_url": .string(urlString)
        ]

        let response = try await SupabaseManager.shared.adminClient
            .from("active_loan")
            .update(updateData)
            .eq("application_id", value: loanId.uuidString.lowercased())
            .execute()

        print("✅ active_loan update response: \(response)")

        return urlString
    }
    func fetchSanctionLetterUrl(loanId: UUID) async throws -> String? {
        struct Row: Codable {
            let sanctionLetterUrl: String?
            enum CodingKeys: String, CodingKey {
                case sanctionLetterUrl = "sanction_letter_url"
            }
        }

        let rows: [Row] = try await SupabaseManager.shared.client
            .from("active_loan")
            .select("sanction_letter_url")
            .eq("application_id", value: loanId.uuidString.lowercased())  // ADD .lowercased()
            .execute()
            .value

        return rows.first?.sanctionLetterUrl
    }
    
    func fetchLoanComments(loanId: UUID) async throws -> [LoanComment] {
        let response = try await client
            .from("loan_comments")
            .select()
            .eq("loan_id", value: loanId)
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([LoanComment].self, from: response.data)
    }

    // MARK: - Real Defaulted Loans for Reports
    
    struct RealOverdueLoan: Codable {
        let outstandingBalance: Double
        let borrowerName: String
        
        enum CodingKeys: String, CodingKey {
            case outstandingBalance = "outstanding_balance"
            case borrowerName = "full_name"
        }
    }
    
    // MARK: - Realtime Live Refresh

    private var liveChannel: RealtimeChannelV2?
    private var liveStreamTasks: [Task<Void, Never>] = []
    private var liveRefreshCallbacks: [() -> Void] = []
    private var debounceTask: Task<Void, Never>?
    private var isLiveRefreshActive = false

    func startLiveRefresh(onRefresh: @escaping () -> Void) {
        liveRefreshCallbacks.append(onRefresh)
        guard !isLiveRefreshActive else { return }
        isLiveRefreshActive = true

        let channel = client.channel("live_refresh")

        let loanAppInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "loan_application")
        let loanAppUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "loan_application")
        let activeLoanInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "active_loan")
        let activeLoanUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "active_loan")
        let emiInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "emi_schedule")
        let emiUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "emi_schedule")
        let borrowerInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "borrower")
        let borrowerUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "borrower")
        let userInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "users")
        let userUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "users")
        let userDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "users")
        let productInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "loan_products")
        let productUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "loan_products")
        let productDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "loan_products")
        let competitiveRatesInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "competitive_rates")
        let competitiveRatesUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "competitive_rates")
        let auditInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "audit_trail")

        let setupTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await channel.subscribeWithError()
                await MainActor.run { self.liveChannel = channel }

                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in loanAppInserts { self.handleLiveChange(table: "loan_application", record: event.record, eventType: "INSERT") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in loanAppUpdates { self.handleLiveChange(table: "loan_application", record: event.record, eventType: "UPDATE") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in activeLoanInserts { self.handleLiveChange(table: "active_loan", record: event.record, eventType: "INSERT") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in activeLoanUpdates { self.handleLiveChange(table: "active_loan", record: event.record, eventType: "UPDATE") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in emiInserts { self.handleLiveChange(table: "emi_schedule", record: event.record, eventType: "INSERT") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in emiUpdates { self.handleLiveChange(table: "emi_schedule", record: event.record, eventType: "UPDATE") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in borrowerInserts { self.autoMergeUserEditable(table: "borrower", record: event.record, eventType: "INSERT") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in borrowerUpdates { self.autoMergeUserEditable(table: "borrower", record: event.record, eventType: "UPDATE") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in userInserts { self.autoMergeUserEditable(table: "users", record: event.record, eventType: "INSERT") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in userUpdates { self.autoMergeUserEditable(table: "users", record: event.record, eventType: "UPDATE") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in userDeletes { self.autoMergeDelete(table: "users", oldRecord: event.oldRecord) }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in productInserts { self.autoMergeUserEditable(table: "loan_products", record: event.record, eventType: "INSERT") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in productUpdates { self.autoMergeUserEditable(table: "loan_products", record: event.record, eventType: "UPDATE") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in productDeletes { self.autoMergeDelete(table: "loan_products", oldRecord: event.oldRecord) }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in competitiveRatesInserts { self.autoMergeUserEditable(table: "competitive_rates", record: event.record, eventType: "INSERT") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in competitiveRatesUpdates { self.autoMergeUserEditable(table: "competitive_rates", record: event.record, eventType: "UPDATE") }
                })
                self.liveStreamTasks.append(Task { @MainActor in
                    for await event in auditInserts { self.autoMergeAuditTrail(record: event.record) }
                })
            } catch {
                print("Live refresh subscription error: \(error)")
            }
        }
        liveStreamTasks.append(setupTask)
    }

    func stopLiveRefresh() {
        isLiveRefreshActive = false
        liveRefreshCallbacks = []
        debounceTask?.cancel()
        debounceTask = nil
        for task in liveStreamTasks { task.cancel() }
        liveStreamTasks = []
        if let channel = liveChannel {
            let ch = channel
            Task { await client.removeChannel(ch) }
            liveChannel = nil
        }
    }

    @MainActor
    private func handleLiveChange(table: String, record: [String: AnyJSON], eventType: String) {
        scheduleLiveRefresh()
    }

    @MainActor
    private func autoMergeUserEditable(table: String, record: [String: AnyJSON], eventType: String) {
        switch table {
        case "users":
            if let item = decodeRecord(record, as: UserSession.self) {
                if let index = users.firstIndex(where: { $0.id == item.id }) {
                    users[index] = item
                } else {
                    users.append(item)
                }
            }
        case "borrower":
            if let item = decodeRecord(record, as: Borrower.self) {
                if let index = borrowers.firstIndex(where: { $0.id == item.id }) {
                    borrowers[index] = item
                } else {
                    borrowers.append(item)
                }
            }
        case "loan_products":
            if let item = decodeRecord(record, as: LoanProduct.self) {
                if let index = loanProducts.firstIndex(where: { $0.id == item.id }) {
                    loanProducts[index] = item
                } else {
                    loanProducts.append(item)
                }
            }
        case "competitive_rates":
            if let item = decodeRecord(record, as: CompetitiveRate.self) {
                if let index = competitiveRates.firstIndex(where: { $0.id == item.id }) {
                    competitiveRates[index] = item
                } else {
                    competitiveRates.append(item)
                }
            }
        default:
            break
        }
        scheduleLiveRefresh()
    }

    @MainActor
    private func autoMergeDelete(table: String, oldRecord: [String: AnyJSON]) {
        guard let idValue = oldRecord["id"]?.stringValue,
              let id = UUID(uuidString: idValue) else { return }
        switch table {
        case "users":
            users.removeAll { $0.id == id }
        case "loan_products":
            loanProducts.removeAll { $0.id == id }
        case "competitive_rates":
            competitiveRates.removeAll { $0.id == id }
        default:
            break
        }
        scheduleLiveRefresh()
    }

    @MainActor
    private func autoMergeAuditTrail(record: [String: AnyJSON]) {
        if let entry = decodeRecord(record, as: AuditEntry.self) {
            auditTrail.insert(entry, at: 0)
        }
        scheduleLiveRefresh()
    }

    private func decodeRecord<T: Decodable>(_ record: [String: AnyJSON], as type: T.Type) -> T? {
        do {
            let data = try JSONEncoder().encode(record)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Live refresh decode error for \(type): \(error)")
            return nil
        }
    }

    @MainActor
    private func scheduleLiveRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            let callbacks = self.liveRefreshCallbacks
            for callback in callbacks {
                callback()
            }
        }
    }

    func fetchRealDefaultedLoans(allBorrowers: [Borrower]) async throws -> [OverdueLoan] {
        let adminClient = SupabaseManager.shared.adminClient
        
        // Fetch active loans that are marked as NPA, joining only with loan_application
        let response = try await adminClient
            .from("active_loan")
            .select("""
                outstanding_balance,
                is_npa,
                loan_application!inner (
                    borrower_id
                )
            """)
            .eq("is_npa", value: true)
            .execute()
        
        guard let data = response.data as Data? else { return [] }
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        
        let borrowerMap = Dictionary(uniqueKeysWithValues: allBorrowers.map { ($0.id, $0.fullName) })
        
        return json.compactMap { dict in
            let balance = dict["outstanding_balance"] as? Double ?? 0
            let app = dict["loan_application"] as? [String: Any]
            let borrowerIdStr = app?["borrower_id"] as? String ?? ""
            let borrowerId = UUID(uuidString: borrowerIdStr)
            
            let name = borrowerId.flatMap { borrowerMap[$0] } ?? "Unknown Borrower"
            
            return OverdueLoan(
                id: UUID(),
                borrowerName: name,
                amount: "₹\(Int(balance))",
                dpd: 91,
                risk: .high,
                officer: "System",
                status: .defaulted
            )
        }
    }
    
    func fetchOfficerUserSession(officerId: UUID) async throws -> UserSession? {
        let results: [UserSession] = try await SupabaseManager.shared.adminClient
            .from("users")
            .select()
            .eq("id", value: officerId.uuidString)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    // MARK: - User Notifications (Loan Officer)

    private var notificationChannel: RealtimeChannelV2?
    private var notificationSubscriptionTask: Task<Void, Never>?

    /// Fetch all notifications for a given officer, newest first
    func fetchOfficerNotifications(userId: UUID) async throws -> [DBUserNotification] {
        return try await client
            .from("user_notifications")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    /// Mark a single notification as read
    func markNotificationRead(id: UUID) async throws {
        try await client
            .from("user_notifications")
            .update(["is_read": AnyJSON.bool(true)])
            .eq("id", value: id)
            .execute()
    }

    /// Mark all notifications as read for a user
    func markAllNotificationsRead(userId: UUID) async throws {
        try await client
            .from("user_notifications")
            .update(["is_read": AnyJSON.bool(true)])
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }

    /// Delete a notification
    func deleteNotification(id: UUID) async throws {
        try await client
            .from("user_notifications")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Delete all notifications for a user
    func deleteAllNotifications(userId: UUID) async throws {
        try await client
            .from("user_notifications")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    /// Subscribe to realtime inserts on user_notifications for a specific user
    func subscribeToNotifications(userId: UUID, onNewNotification: @escaping (DBUserNotification) -> Void) {
        unsubscribeFromNotifications()

        let channel = client.channel("notifications_\(userId.uuidString)")

        notificationSubscriptionTask = Task {
            do {
                let stream = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "user_notifications",
                    filter: "user_id=eq.\(userId.uuidString)"
                )

                try await channel.subscribeWithError()
                notificationChannel = channel

                for await insertion in stream {
                    do {
                        let jsonData = try JSONEncoder().encode(insertion.record)
                        let notification = try JSONDecoder().decode(DBUserNotification.self, from: jsonData)
                        onNewNotification(notification)
                    } catch {
                        print("Error decoding realtime notification: \(error)")
                    }
                }
            } catch {
                print("Error subscribing to notifications: \(error)")
            }
        }
    }

    /// Tear down the notification realtime channel
    func unsubscribeFromNotifications() {
        notificationSubscriptionTask?.cancel()
        notificationSubscriptionTask = nil
        if let channel = notificationChannel {
            Task {
                await client.removeChannel(channel)
            }
            notificationChannel = nil
        }
    }
}
