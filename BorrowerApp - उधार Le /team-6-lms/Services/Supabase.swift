

import Foundation
import Supabase
import Auth

@Observable
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client = SupabaseClient(
        supabaseURL: URL(string: "https://vghdgjndpwfwbchwbnak.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZnaGRnam5kcHdmd2JjaHdibmFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxNTk1MDYsImV4cCI6MjA5MTczNTUwNn0.WRj3YyKXqhmHmtHRE7n2VCatvpsivhVBeZ3o2IYSQB0",
        options: SupabaseClientOptions(
            auth: .init(
                storage: KeychainLocalStorage(),
                flowType: .implicit, 
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    // MARK: - Auth Methods

    func signUpWithMagicLink(email: String, fullName: String, mobile: String, dob: String, bankDetails: [String: String], branch: String) async throws {
        let metadata: [String: AnyJSON] = [
            "full_name": AnyJSON.string(fullName),
            "mobile": AnyJSON.string(mobile),
            "dob": AnyJSON.string(dob),
            "role": AnyJSON.string("Borrower"),
            "acc_holder": AnyJSON.string(bankDetails["acc_holder"] ?? ""),
            "acc_number": AnyJSON.string(bankDetails["acc_number"] ?? ""),
            "ifsc": AnyJSON.string(bankDetails["ifsc"] ?? ""),
            "branch": AnyJSON.string(branch)
        ]

        try await client.auth.signInWithOTP(
            email: email,
            redirectTo: URL(string: "udharle-borrower://"),
            shouldCreateUser: true,
            data: metadata
        )
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func updatePassword(password: String) async throws {
        try await client.auth.update(
            user: UserAttributes(password: password)
        )
    }

    @discardableResult
    func handleDeepLink(url: URL) async throws -> Session {
        print("🔗 [SupabaseManager] Exchanging session from URL...")
        return try await client.auth.session(from: url)
    }

    func fetchUserStatus() async throws -> String {
        guard let session = try? await client.auth.session else { return "None" }
        let authUserId = session.user.id

        do {
            let response: [[String: AnyJSON]] = try await client
                .from("users")
                .select("status")
                .eq("id", value: authUserId.uuidString)
                .execute()
                .value

            return response.first?["status"]?.stringValue ?? "Pending"
        } catch {
            return "Pending"
        }
    }

    func sendMagicLink(email: String) async throws {

        let redirectToURL = URL(string: "udharle-borrower://")

        try await client.auth.signInWithOTP(
            email: email,
            redirectTo: redirectToURL,
            shouldCreateUser: false
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
        UserDefaults.standard.removeObject(forKey: "currentBorrowerId")
    }

    // MARK: - Database Methods

    func createBorrower(profile: BorrowerProfile) async throws {

        let session = try await client.auth.session
        let authUserId = session.user.id

        var sanitizedMobile = profile.mobile.replacingOccurrences(of: " ", with: "")
        if sanitizedMobile.count > 10 {
            sanitizedMobile = String(sanitizedMobile.suffix(10))
        }

        var borrowerData: [String: AnyJSON] = [
            "id": AnyJSON.string(authUserId.uuidString),
            "full_name": (profile.fullName?.isEmpty == false) ? AnyJSON.string(profile.fullName!) : AnyJSON.null,
            "mobile": AnyJSON.string(sanitizedMobile),
            "email": (profile.email?.isEmpty == false) ? AnyJSON.string(profile.email!) : AnyJSON.null,
            "dob": (profile.dob?.isEmpty == false) ? AnyJSON.string(profile.dob!) : AnyJSON.null,
            "account_holder_name": (profile.accountHolderName?.isEmpty == false) ? AnyJSON.string(profile.accountHolderName!) : AnyJSON.null,
            "bank_account_number": (profile.bankAccountNumber?.isEmpty == false) ? AnyJSON.string(profile.bankAccountNumber!) : AnyJSON.null,
            "ifsc_code": (profile.ifscCode?.isEmpty == false) ? AnyJSON.string(profile.ifscCode!) : AnyJSON.null,
            "credit_score": AnyJSON.double(Double(profile.creditScore))
        ]
        if let branch = profile.branch {
            borrowerData["branch"] = AnyJSON.string(branch.rawValue)
        }

        try await client.from("borrower").upsert(borrowerData).execute()

        var userData: [String: AnyJSON] = [
            "id": AnyJSON.string(authUserId.uuidString),
            "full_name": AnyJSON.string(profile.fullName ?? ""),
            "email": AnyJSON.string(profile.email ?? ""),
            "role": AnyJSON.string("Borrower"),
            "status": AnyJSON.string("Verified"),
            "phone": AnyJSON.string(sanitizedMobile)
        ]
        if let branch = profile.branch {
            userData["branch"] = AnyJSON.string(branch.rawValue)
        }
        try await client.from("users").upsert(userData).execute()

        let existingDocs: [[String: AnyJSON]] = try await client
            .from("documents")
            .select("id")
            .eq("borrower_id", value: authUserId.uuidString)
            .execute()
            .value

        if existingDocs.isEmpty {
            let blankDoc: [String: AnyJSON] = ["borrower_id": AnyJSON.string(authUserId.uuidString)]
            try await client.from("documents").insert(blankDoc).execute()
        }
    }

    func fetchCurrentBorrower() async throws -> BorrowerProfile? {
        let session = try await client.auth.session
        let authUserId = session.user.id

        let profiles: [BorrowerProfile] = try await client
            .from("borrower")
            .select()
            .eq("id", value: authUserId.uuidString)
            .execute()
            .value

        return profiles.first
    }

    func fetchDocuments() async throws -> BorrowerDocuments? {
        let session = try await client.auth.session
        let authUserId = session.user.id

        let docs: [BorrowerDocuments] = try await client
            .from("documents")
            .select()
            .eq("borrower_id", value: authUserId.uuidString)
            .execute()
            .value

        return docs.first
    }

    // MARK: - Product Methods

    func fetchLoanProducts() async throws -> [LoanProduct] {
        let products: [LoanProduct] = try await client
            .from("loan_products")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
        return products
    }

    // MARK: - Employment Methods

    func fetchEmployment() async throws -> Employment? {
        let session = try await client.auth.session
        let authUserId = session.user.id

        let records: [Employment] = try await client
            .from("employment")
            .select()
            .eq("borrower_id", value: authUserId.uuidString)
            .execute()
            .value

        return records.first
    }

    func saveEmployment(_ employment: Employment) async throws {
        let session = try await client.auth.session
        let authUserId = session.user.id

        let existing: [Employment] = try await client
            .from("employment")
            .select()
            .eq("borrower_id", value: authUserId.uuidString)
            .execute()
            .value

        var empToSave = employment

        struct EmploymentData: Codable {
            let borrower_id: UUID
            let employment_type: String
            let company_name: String?
            let industry_type: String?
            let job_role: String?
            let years_experience: Int?
            let monthly_income: Double
        }

        let payload = EmploymentData(
            borrower_id: authUserId,
            employment_type: employment.employmentType.rawValue,
            company_name: employment.companyName,
            industry_type: employment.industryType,
            job_role: employment.jobRole,
            years_experience: employment.yearsExperience,
            monthly_income: employment.monthlyIncome
        )

        if let first = existing.first, let id = first.id {

            try await client
                .from("employment")
                .update(payload)
                .eq("id", value: id)
                .execute()
        } else {

            try await client
                .from("employment")
                .insert(payload)
                .execute()
        }

        try await updateProfileEmployment(type: employment.employmentType.rawValue, income: employment.monthlyIncome)
    }

    func updateProfileEmployment(type: String, income: Double) async throws {
        let session = try await client.auth.session
        let authUserId = session.user.id

        try await client
            .from("borrower")
            .update([
                "employment_type": AnyJSON.string(type),
                "declared_monthly_income": AnyJSON.double(income)
            ])
            .eq("id", value: authUserId.uuidString)
            .execute()
    }

    func uploadChatDocument(data: Data, isPDF: Bool, docType: DocumentRequestType, applicationId: UUID, borrowerId: UUID) async throws -> String {
        let fileExtension = isPDF ? "pdf" : "jpg"
        let contentType = isPDF ? "application/pdf" : "image/jpeg"
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let filePath = "uploads/\(fileName)"

        try await client.storage
            .from("documents")
            .upload(filePath, data: data, options: FileOptions(contentType: contentType))

        let publicURL = try client.storage.from("documents").getPublicURL(path: filePath)
        let urlString = publicURL.absoluteString

        let entry: [String: AnyJSON] = [
            "application_id": .string(applicationId.uuidString),
            "borrower_id": .string(borrowerId.uuidString),
            "document_type": .string(docType.dbDocumentType),
            "file_url": .string(urlString),
            "status": .string("Pending")
        ]

        try await client
            .from("loan_application_documents")
            .insert(entry)
            .execute()

        let profileDocType: String? = {
            switch docType {
            case .panCard: return "PAN"
            case .aadhaarCard, .addressProof: return "Address"
            case .incomeProof: return "Income"
            case .collateralPaper: return "Collateral"
            case .bankStatement: return nil
            case .gstRegistration: return nil
            case .other: return nil
            }
        }()

        if let profileType = profileDocType {
            try? await uploadDocumentAndUpdateTable(docType: profileType, data: data, isPDF: isPDF)
        }

        return urlString
    }

    func fetchUploadedDocuments(applicationId: UUID, borrowerId: UUID) async throws -> [String: String] {
        let rows: [[String: AnyJSON]] = try await client
            .from("loan_application_documents")
            .select("document_type, status")
            .eq("application_id", value: applicationId.uuidString)
            .eq("borrower_id", value: borrowerId.uuidString)
            .execute()
            .value

        var dict: [String: String] = [:]
        for row in rows {
            if let type = row["document_type"]?.stringValue,
               let status = row["status"]?.stringValue {
                dict[type] = status
            }
        }
        return dict
    }

    func saveApplicationDocuments(applicationId: UUID, documents: [String: String]) async throws {
                let currentUser = try await client.auth.session.user

                let documentEntries = documents.map { (docType, url) in
                    return [
                        "application_id": AnyJSON.string(applicationId.uuidString),
                        "borrower_id": AnyJSON.string(currentUser.id.uuidString),
                        "document_type": AnyJSON.string(docType),
                        "file_url": AnyJSON.string(url),
                        "status": AnyJSON.string("Pending")
                    ]
                }

                try await client
                    .from("loan_application_documents")
                    .insert(documentEntries)
                    .execute()
            }

    // MARK: - Storage Methods

    @discardableResult
    func uploadDocumentAndUpdateTable(docType: String, data: Data, isPDF: Bool) async throws -> String {
        let session = try await client.auth.session
        let authUserId = session.user.id

        let existingDocs: [[String: AnyJSON]] = try await client
            .from("documents")
            .select("id")
            .eq("borrower_id", value: authUserId.uuidString)
            .execute()
            .value

        if existingDocs.isEmpty {
            let blankDoc: [String: AnyJSON] = ["borrower_id": AnyJSON.string(authUserId.uuidString)]
            try await client.from("documents").insert(blankDoc).execute()
        }

        let fileExtension = isPDF ? "pdf" : "jpg"
        let contentType = isPDF ? "application/pdf" : "image/jpeg"
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let filePath = "uploads/\(fileName)"

        try await client.storage
            .from("documents")
            .upload(filePath, data: data, options: FileOptions(contentType: contentType))

        let publicURL = try client.storage.from("documents").getPublicURL(path: filePath)
        let urlString = publicURL.absoluteString

        if docType == "PAN" {
            struct UpdatePAN: Codable { let pan_doc_url: String }
            try await client.from("documents").update(UpdatePAN(pan_doc_url: urlString)).eq("borrower_id", value: authUserId.uuidString).execute()
        } else if docType == "Address" {
            struct UpdateAddress: Codable { let aadhaar_doc_url: String }
            try await client.from("documents").update(UpdateAddress(aadhaar_doc_url: urlString)).eq("borrower_id", value: authUserId.uuidString).execute()
        } else if docType == "Income" {
            struct UpdateIncome: Codable { let income_proof_url: String }
            try await client.from("documents").update(UpdateIncome(income_proof_url: urlString)).eq("borrower_id", value: authUserId.uuidString).execute()
        } else if docType == "Collateral" {
            struct UpdateCollateral: Codable { let collateral_doc_url: String }
            try await client.from("documents").update(UpdateCollateral(collateral_doc_url: urlString)).eq("borrower_id", value: authUserId.uuidString).execute()
        } else if docType == "Business Proof" {
            struct UpdateBusiness: Codable { let business_proof_url: String }
            try await client.from("documents").update(UpdateBusiness(business_proof_url: urlString)).eq("borrower_id", value: authUserId.uuidString).execute()
        }

        return urlString
    }

    func submitApplicationWithAssignment(loanAmount: Double, tenure: Int, purpose: String, employer: String, income: Double, productId: UUID? = nil) async throws -> UUID {
        let session = try await client.auth.session
        let currentUser = session.user

        let borrowerRows: [[String: AnyJSON]] = try await client
            .from("borrower")
            .select("branch")
            .eq("id", value: currentUser.id.uuidString)
            .execute()
            .value
        let borrowerBranch = borrowerRows.first?["branch"]?.stringValue

        var officerQuery = client
            .from("users")
            .select("id")
            .eq("role", value: "Loan Officer")

        var officerRows: [[String: AnyJSON]]
        if let branch = borrowerBranch, !branch.isEmpty {
            officerRows = try await officerQuery
                .eq("branch", value: branch)
                .execute()
                .value
        } else {
            officerRows = []
        }

        if officerRows.isEmpty {
            officerRows = try await client
                .from("users")
                .select("id")
                .eq("role", value: "Loan Officer")
                .execute()
                .value
        }

        guard let randomOfficerData = officerRows.randomElement(),
              let officerIdString = randomOfficerData["id"]?.stringValue else {
            throw NSError(domain: "AssignmentError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No loan officers found."])
        }

        var finalData: [String: AnyJSON] = [
            "borrower_id": AnyJSON.string(currentUser.id.uuidString),
            "loan_amount": AnyJSON.double(loanAmount),
            "tenure_months": AnyJSON.integer(tenure),
            "purpose": AnyJSON.string(purpose),
            "status": AnyJSON.string("submitted"),
            "assigned_officer_id": AnyJSON.string(officerIdString),
            "employer_name": AnyJSON.string(employer),
            "monthly_income": AnyJSON.double(income)
        ]

        if let pid = productId {
            finalData["product_id"] = AnyJSON.string(pid.uuidString)
        }

        let insertResponse: [[String: AnyJSON]] = try await client
            .from("loan_application")
            .insert(finalData)
            .select("id")
            .execute()
            .value

        guard let appIdString = insertResponse.first?["id"]?.stringValue,
              let appId = UUID(uuidString: appIdString) else {
            throw NSError(domain: "DBError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve application ID."])
        }

        return appId
    }

    func fetchMyApplications() async throws -> [LoanApplication] {
        let session = try await client.auth.session
        let authUserId = session.user.id

        let applications: [LoanApplication] = try await client
            .from("loan_application")
            .select()
            .eq("borrower_id", value: authUserId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return applications
    }

    func fetchUpcomingEMIs() async throws -> [EMISchedule] {
        let activeLoans = try await fetchActiveLoans()
        guard !activeLoans.isEmpty else { return [] }

        let loanIds = activeLoans.map { $0.id.uuidString }

        let emis: [EMISchedule] = try await client
            .from("emi_schedule")
            .select()
            .in("loan_id", values: loanIds)
            .eq("status", value: "Upcoming")
            .order("due_date", ascending: true)
            .execute()
            .value

        return emis
    }

    func fetchPredictiveAlerts() async throws -> [FinancialInsight] {
        let session = try await client.auth.session
        let authUserId = session.user.id

        let alerts: [FinancialInsight] = try await client
            .from("financial_insights")
            .select()
            .eq("borrower_id", value: authUserId.uuidString)
            .order("generated_at", ascending: false)
            .execute()
            .value
        return alerts
    }

    func fetchRecentActivity() async throws -> [AuditLog] {
        let session = try await client.auth.session
        let userEmail = session.user.email ?? ""

        let logs: [AuditLog] = try await client
            .from("audit_trail")
            .select()
            .eq("actor", value: userEmail)
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
            .value
        return logs
    }

    func fetchActiveLoans() async throws -> [ActiveLoan] {
        let session = try await client.auth.session
        let authUserId = session.user.id

        let apps: [LoanApplication] = try await client
            .from("loan_application")
            .select()
            .eq("borrower_id", value: authUserId.uuidString)
            .execute()
            .value

        guard !apps.isEmpty else { return [] }

        let appIds = apps.compactMap { $0.id?.uuidString }
        guard !appIds.isEmpty else { return [] }

        print("🔍 fetchActiveLoans: querying active_loan with app_ids: \(appIds)")

        let activeLoans: [ActiveLoan] = try await client
            .from("active_loan")
            .select()
            .in("application_id", values: appIds)
            .execute()
            .value

        if activeLoans.isEmpty {
            let allLoans: [[String: AnyJSON]] = try await client
                .from("active_loan")
                .select("id, application_id")
                .execute()
                .value
            print("⚠️ fetchActiveLoans: .in() returned 0. All active_loan rows in DB:")
            for row in allLoans {
                print("   id=\(row["id"]?.stringValue ?? "?") application_id=\(row["application_id"]?.stringValue ?? "?")")
            }
        }

        print("🔍 fetchActiveLoans: \(apps.count) apps → \(activeLoans.count) active loans")
        for loan in activeLoans {
            print("   active_loan id=\(loan.id.uuidString.prefix(8)) app_id=\(loan.applicationId.uuidString.prefix(8))")
        }
        return activeLoans
    }

    func fetchEMISchedule() async throws -> [EMISchedule] {
        let session = try await client.auth.session
        let authUserId = session.user.id

        let activeLoans = try await fetchActiveLoans()
        guard !activeLoans.isEmpty else { return [] }

        let loanIds = activeLoans.map { $0.id.uuidString }

        let schedule: [EMISchedule] = try await client
            .from("emi_schedule")
            .select()
            .in("loan_id", values: loanIds)
            .execute()
            .value

        print("🔍 fetchEMISchedule: \(activeLoans.count) loans → \(schedule.count) EMIs")
        let grouped = Dictionary(grouping: schedule, by: { $0.loanId })
        for (loanId, emis) in grouped {
            print("   loan \(loanId.uuidString.prefix(8)): \(emis.count) EMIs")
        }
        return schedule
    }

    func fetchOfficer(id: UUID) async throws -> LoanOfficer? {
        let officers: [LoanOfficer] = try await client
            .from("users")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value

        return officers.first
    }

    func deleteDocument(docType: String) async throws {
        let session = try await client.auth.session
        let authUserId = session.user.id

        var column = ""
        if docType == "PAN" { column = "pan_doc_url" }
        else if docType == "Address" { column = "aadhaar_doc_url" }
        else if docType == "Income" { column = "income_proof_url" }
        else if docType == "Collateral" { column = "collateral_doc_url" }
        else if docType == "Business Proof" { column = "business_proof_url" }

        guard !column.isEmpty else { return }

        try await client
            .from("documents")
            .update([column: AnyJSON.null])
            .eq("borrower_id", value: authUserId.uuidString)
            .execute()
    }

    func updateUserStatus(to status: String) async throws {
        let currentUser = try await client.auth.session.user

        try await client
            .from("users")
            .update(["status": AnyJSON.string(status)])
            .eq("id", value: currentUser.id.uuidString)
            .execute()
    }

    func checkAndUpdateNPAStatus() async throws {
        let schedule = try await fetchEMISchedule()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()

        var loansToMarkNPA: Set<UUID> = []

        for emi in schedule {
            if emi.status.lowercased() != "paid",
               let dueDate = formatter.date(from: emi.dueDate),
               dueDate < today {
                loansToMarkNPA.insert(emi.loanId)
            }
        }

        for loanId in loansToMarkNPA {
            try await client
                .from("active_loan")
                .update(["is_npa": AnyJSON.bool(true)])
                .eq("id", value: loanId.uuidString)
                .execute()

            let auditData: [String: AnyJSON] = [
                "title": AnyJSON.string("Loan Marked as NPA"),
                "actor": AnyJSON.string("System"),
                "category": AnyJSON.string("Risk"),
                "status": AnyJSON.string("Warning"),
                "icon": AnyJSON.string("exclamationmark.octagon.fill"),
                "icon_color": AnyJSON.string("red"),
                "branch": AnyJSON.string("Risk Engine")
            ]
            try? await client.from("audit_trail").insert(auditData).execute()
        }
    }

    func recordPayment(emi: EMISchedule, paymentId: String, orderId: String, signature: String) async throws {
        let session = try await client.auth.session
        let userId = session.user.id

        let paidAt = ISO8601DateFormatter().string(from: Date())

        try await client
            .from("emi_schedule")
            .update([
                "status": AnyJSON.string("Paid"),
                "paid_at": AnyJSON.string(paidAt)
            ])
            .eq("id", value: emi.id.uuidString)
            .execute()

        let activeLoans: [ActiveLoan] = try await client
            .from("active_loan")
            .select()
            .eq("id", value: emi.loanId.uuidString)
            .execute()
            .value

        var applicationId: UUID?

        if let loan = activeLoans.first {
            let newBalance = max(0, loan.outstandingBalance - emi.amount)
            applicationId = loan.applicationId

            try await client
                .from("active_loan")
                .update([
                    "outstanding_balance": AnyJSON.double(newBalance),
                    "updated_at": AnyJSON.string(paidAt)
                ])
                .eq("id", value: loan.id.uuidString)
                .execute()
        }

        let transactionData: [String: AnyJSON] = [
            "user_id": AnyJSON.string(userId.uuidString),
            "payment_kind": AnyJSON.string("emi"),
            "emi_id": AnyJSON.string(emi.id.uuidString),
            "loan_id": AnyJSON.string(emi.loanId.uuidString),
            "amount_paise": AnyJSON.integer(Int(emi.amount * 100)),
            "currency": AnyJSON.string("INR"),
            "status": AnyJSON.string("success"),
            "cashfree_order_id": AnyJSON.string(orderId),
            "cashfree_payment_id": AnyJSON.string(paymentId),
            "cashfree_signature": AnyJSON.string(signature),
            "verified_at": AnyJSON.string(paidAt)
        ]
        try await client.from("payment_transactions").insert(transactionData).execute()

        if let appId = applicationId {

            let repaymentUpdate: [String: AnyJSON] = [
                "status": AnyJSON.string("Paid"),
                "paid_amount": AnyJSON.double(emi.amount),
                "paid_at": AnyJSON.string(paidAt)
            ]
            try? await client
                .from("repayments")
                .update(repaymentUpdate)
                .eq("loan_id", value: appId.uuidString)
                .eq("due_date", value: emi.dueDate)
                .execute()

            let existingRepayments: [[String: AnyJSON]] = try await client
                .from("repayments")
                .select("id")
                .eq("loan_id", value: appId.uuidString)
                .eq("due_date", value: emi.dueDate)
                .execute()
                .value

            if existingRepayments.isEmpty {
                let newRepayment: [String: AnyJSON] = [
                    "loan_id": AnyJSON.string(appId.uuidString),
                    "due_date": AnyJSON.string(emi.dueDate),
                    "amount": AnyJSON.double(emi.amount),
                    "paid_amount": AnyJSON.double(emi.amount),
                    "status": AnyJSON.string("Paid"),
                    "paid_at": AnyJSON.string(paidAt)
                ]
                try? await client.from("repayments").insert(newRepayment).execute()
            }
        }

        if let appId = applicationId {
            let historyData: [String: AnyJSON] = [
                "loan_id": AnyJSON.string(appId.uuidString),
                "due_date": AnyJSON.string(emi.dueDate),
                "amount": AnyJSON.double(emi.amount),
                "status": AnyJSON.string("Paid"),
                "paid_at": AnyJSON.string(paidAt)
            ]
            try? await client.from("repayment_history").insert(historyData).execute()
        }

        let insightData: [String: AnyJSON] = [
            "borrower_id": AnyJSON.string(userId.uuidString),
            "insight_type": AnyJSON.string("Info"),
            "content": AnyJSON.string("✅ Payment Successful: ₹\(Int(emi.amount)) paid towards your loan. Payment ID: \(paymentId)")
        ]
        try? await client.from("financial_insights").insert(insightData).execute()

        try? await sendNotification(
            title: "EMI Payment Successful",
            message: "Your EMI of ₹\(Int(emi.amount).formatted()) has been paid successfully. Payment ID: \(paymentId)",
            type: "payment"
        )
    }

    // MARK: - Notifications

    func fetchUnreadNotificationCount() async throws -> Int {
        let session = try await client.auth.session
        let notifications: [UserNotification] = try await client
            .from("user_notifications")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .eq("is_read", value: false)
            .execute()
            .value
        return notifications.count
    }

    func fetchNotifications() async throws -> [UserNotification] {
        let session = try await client.auth.session
        let userId = session.user.id

        let notifications: [UserNotification] = try await client
            .from("user_notifications")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        return notifications
    }

    func markNotificationRead(id: UUID) async throws {
        try await client
            .from("user_notifications")
            .update(["is_read": AnyJSON.bool(true)])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func sendNotification(title: String, message: String, type: String, metadata: [String: String]? = nil) async throws {
        let session = try await client.auth.session
        let userId = session.user.id

        var data: [String: AnyJSON] = [
            "user_id": AnyJSON.string(userId.uuidString),
            "title": AnyJSON.string(title),
            "message": AnyJSON.string(message),
            "type": AnyJSON.string(type),
            "is_read": AnyJSON.bool(false)
        ]

        if let metadata = metadata {
            if let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                data["metadata"] = AnyJSON.string(jsonString)
            }
        }

        do {
            try await client.from("user_notifications").insert(data).execute()
        } catch {

            data.removeValue(forKey: "metadata")
            try await client.from("user_notifications").insert(data).execute()
        }
    }
    // MARK: - KYC Verification

    func savePANVerification(pan: String, verified: Bool) async throws {
        let session = try await client.auth.session
        try await client
            .from("borrower")
            .update([
                "pan_number": AnyJSON.string(pan),
                "pan_verified": AnyJSON.bool(verified)
            ])
            .eq("id", value: session.user.id.uuidString)
            .execute()
    }

    func saveAadhaarVerification(aadhaarNumber: String, refId: String?, verified: Bool) async throws {
        let session = try await client.auth.session
        var update: [String: AnyJSON] = [
            "aadhaar_number": AnyJSON.string(aadhaarNumber),
            "aadhaar_verified": AnyJSON.bool(verified)
        ]
        if let refId { update["aadhaar_ref_id"] = AnyJSON.string(refId) }
        try await client
            .from("borrower")
            .update(update)
            .eq("id", value: session.user.id.uuidString)
            .execute()
    }
}

extension AnyJSON {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
}

// MARK: - Keychain Storage Implementation

struct KeychainLocalStorage: AuthLocalStorage {
    private let service = "com.credflow.auth"

    func store(key: String, value: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [kSecValueData as String: value]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = value
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    func retrieve(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return result as? Data
    }

    func remove(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
