import SwiftUI

// MARK: - Risk Level

enum OfficerRiskLevel: String, CaseIterable {
    case low, medium, high
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .low: return OfficerTheme.iconGreen
        case .medium: return OfficerTheme.iconAmber
        case .high: return OfficerTheme.iconRed
        }
    }

    /// Compute risk from credit score (client-side)
    static func from(creditScore: Int) -> OfficerRiskLevel {
        if creditScore >= 750 { return .low }
        if creditScore >= 680 { return .medium }
        return .high
    }
}

// MARK: - Application Status

enum LoanApplicationStatus: String, Codable, CaseIterable {
    case submitted = "submitted"
    case underReview = "under_review"
    case approved = "approved"
    case rejected = "rejected"
    case recommended = "recommended"
    case returnedForCorrection = "returned_for_correction"

    var title: String {
        switch self {
        case .submitted: return "Pending Review"
        case .underReview: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .recommended: return "Recommended"
        case .returnedForCorrection: return "Returned for Correction"
        }
    }

    var actionTitle: String {
        switch self {
        case .approved: return "Approve"
        case .rejected: return "Reject"
        case .recommended: return "Recommend"
        case .returnedForCorrection: return "Returned"
        default: return title
        }
    }

    var shortTitle: String {
        switch self {
        case .underReview: return "Review"
        case .submitted: return "Pending"
        case .returnedForCorrection: return "Returned"
        default: return title
        }
    }

    var color: Color {
        switch self {
        case .submitted: return OfficerTheme.iconAmber
        case .underReview: return OfficerTheme.iconAmber
        case .approved: return OfficerTheme.iconGreen
        case .rejected: return OfficerTheme.iconRed
        case .recommended: return OfficerTheme.accentBlue
        case .returnedForCorrection: return OfficerTheme.iconAmber
        }
    }
}

// MARK: - Status Filter

enum StatusFilter: String, CaseIterable, Identifiable {
    case all, pending, approved, rejected, recommended, returned

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .recommended: return "Recommended"
        case .returned: return "Returned"
        }
    }

    var color: Color {
        switch self {
        case .all: return OfficerTheme.accentGreen
        case .pending: return OfficerTheme.iconAmber
        case .approved: return OfficerTheme.iconGreen
        case .rejected: return OfficerTheme.iconRed
        case .recommended: return OfficerTheme.accentBlue
        case .returned: return OfficerTheme.iconRed
        }
    }
}

// MARK: - Document Type

enum DocumentType: String, CaseIterable, Identifiable {
    case identityProof
    case addressProof
    case incomeDocument
    case collateralPaper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .identityProof: return "Identity Proof"
        case .addressProof: return "Address Proof"
        case .incomeDocument: return "Income Document"
        case .collateralPaper: return "Collateral Paper"
        }
    }

    var shortTitle: String {
        switch self {
        case .identityProof: return "Identity"
        case .addressProof: return "Address"
        case .incomeDocument: return "Income"
        case .collateralPaper: return "Collateral"
        }
    }
}

// MARK: - Supabase DB Models

struct DBLoanApplication: Codable, Identifiable, Hashable {
    let id: UUID
    let borrowerId: UUID?
    let productId: UUID?
    let loanAmount: Double
    let tenureMonths: Int
    let interestRate: Double?
    let purpose: String?
    let status: LoanApplicationStatus
    let createdAt: String?
    let updatedAt: String?
    let assignedOfficerId: UUID?
    let employerName: String?
    let monthlyIncome: Double?
    let managerComment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case productId = "product_id"
        case loanAmount = "loan_amount"
        case tenureMonths = "tenure_months"
        case interestRate = "interest_rate"
        case purpose, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case assignedOfficerId = "assigned_officer_id"
        case employerName = "employer_name"
        case monthlyIncome = "monthly_income"
        case managerComment = "manager_comment"
    }

    init(
        id: UUID,
        borrowerId: UUID?,
        productId: UUID? = nil,
        loanAmount: Double,
        tenureMonths: Int,
        interestRate: Double?,
        purpose: String?,
        status: LoanApplicationStatus,
        createdAt: String?,
        updatedAt: String?,
        assignedOfficerId: UUID?,
        employerName: String?,
        monthlyIncome: Double?,
        managerComment: String? = nil
    ) {
        self.id = id
        self.borrowerId = borrowerId
        self.productId = productId
        self.loanAmount = loanAmount
        self.tenureMonths = tenureMonths
        self.interestRate = interestRate
        self.purpose = purpose
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.assignedOfficerId = assignedOfficerId
        self.employerName = employerName
        self.monthlyIncome = monthlyIncome
        self.managerComment = managerComment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        borrowerId = try c.decodeIfPresent(UUID.self, forKey: .borrowerId)
        productId = try? c.decodeIfPresent(UUID.self, forKey: .productId)
        loanAmount = try c.decode(Double.self, forKey: .loanAmount)
        tenureMonths = try c.decode(Int.self, forKey: .tenureMonths)
        interestRate = try c.decodeIfPresent(Double.self, forKey: .interestRate)
        purpose = try c.decodeIfPresent(String.self, forKey: .purpose)
        status = try c.decode(LoanApplicationStatus.self, forKey: .status)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        assignedOfficerId = try c.decodeIfPresent(UUID.self, forKey: .assignedOfficerId)
        employerName = try c.decodeIfPresent(String.self, forKey: .employerName)
        monthlyIncome = try c.decodeIfPresent(Double.self, forKey: .monthlyIncome)
        managerComment = try c.decodeIfPresent(String.self, forKey: .managerComment)
    }

    var createdDate: Date? {
        guard let createdAt = createdAt else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: createdAt)
    }
}

struct DBBorrower: Codable, Identifiable, Hashable {
    let id: UUID
    let fullName: String?
    let dob: String?
    let gender: String?
    let mobile: String?
    let email: String?
    let panNumber: String?
    let aadhaarNumber: String?
    let address: String?
    let kycStatus: String?
    let accountHolderName: String?
    let bankAccountNumber: String?
    let ifscCode: String?
    let creditScore: Int?
    let declaredMonthlyIncome: Double?
    let employmentType: String?
    let branch: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case dob, gender, mobile, email
        case panNumber = "pan_number"
        case aadhaarNumber = "aadhaar_number"
        case address
        case kycStatus = "kyc_status"
        case accountHolderName = "account_holder_name"
        case bankAccountNumber = "bank_account_number"
        case ifscCode = "ifsc_code"
        case creditScore = "credit_score"
        case declaredMonthlyIncome = "declared_monthly_income"
        case employmentType = "employment_type"
        case branch
    }

    var displayName: String {
        fullName ?? "Unknown"
    }

    var initials: String {
        displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }
}

struct DBEmployment: Codable, Identifiable, Hashable {
    let id: Int
    let borrowerId: UUID?
    let employmentType: String?
    let companyName: String?
    let industryType: String?
    let jobRole: String?
    let yearsExperience: Int?
    let monthlyIncome: Double?
    let incomeStabilityScore: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case employmentType = "employment_type"
        case companyName = "company_name"
        case industryType = "industry_type"
        case jobRole = "job_role"
        case yearsExperience = "years_experience"
        case monthlyIncome = "monthly_income"
        case incomeStabilityScore = "income_stability_score"
    }
}

struct DBFinancials: Codable, Identifiable, Hashable {
    let id: Int
    let borrowerId: UUID?
    let existingLoansCount: Int?
    let totalEmi: Double?
    let creditCardUsage: Double?
    let savingsBalance: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case existingLoansCount = "existing_loans_count"
        case totalEmi = "total_emi"
        case creditCardUsage = "credit_card_usage"
        case savingsBalance = "savings_balance"
    }
}

struct DBCreditProfile: Codable, Identifiable, Hashable {
    let id: Int
    let borrowerId: UUID?
    let creditScore: Int?
    let missedPayments: Int?
    let creditHistoryLength: Int?
    let creditUtilization: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case creditScore = "credit_score"
        case missedPayments = "missed_payments"
        case creditHistoryLength = "credit_history_length"
        case creditUtilization = "credit_utilization"
    }
}

struct DBDocuments: Codable, Identifiable, Hashable {
    let id: UUID
    let borrowerId: UUID?
    let panDocUrl: String?
    let aadhaarDocUrl: String?
    let incomeProofUrl: String?
    let businessProofUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case panDocUrl = "pan_doc_url"
        case aadhaarDocUrl = "aadhaar_doc_url"
        case incomeProofUrl = "income_proof_url"
        case businessProofUrl = "business_proof_url"
    }

    var hasPanDoc: Bool { panDocUrl != nil && !panDocUrl!.isEmpty }
    var hasAadhaarDoc: Bool { aadhaarDocUrl != nil && !aadhaarDocUrl!.isEmpty }
    var hasIncomeProof: Bool { incomeProofUrl != nil && !incomeProofUrl!.isEmpty }
    var hasBusinessProof: Bool {
        guard let url = businessProofUrl, !url.isEmpty, url != "NULL" else { return false }
        return true
    }

    func toUploadedDocuments() -> [BorrowerUploadedDocument] {
        var result: [BorrowerUploadedDocument] = []
        if hasPanDoc {
            result.append(BorrowerUploadedDocument(id: UUID(), borrowerId: borrowerId, documentName: "PAN Card", fileUrl: panDocUrl, uploadedAt: nil))
        }
        if hasAadhaarDoc {
            result.append(BorrowerUploadedDocument(id: UUID(), borrowerId: borrowerId, documentName: "Aadhaar Card", fileUrl: aadhaarDocUrl, uploadedAt: nil))
        }
        if hasIncomeProof {
            result.append(BorrowerUploadedDocument(id: UUID(), borrowerId: borrowerId, documentName: "Income Proof", fileUrl: incomeProofUrl, uploadedAt: nil))
        }
        if hasBusinessProof {
            result.append(BorrowerUploadedDocument(id: UUID(), borrowerId: borrowerId, documentName: "Business Proof", fileUrl: businessProofUrl, uploadedAt: nil))
        }
        return result
    }
}

struct BorrowerUploadedDocument: Codable, Identifiable, Hashable {
    let id: UUID
    let borrowerId: UUID?
    let documentName: String
    let fileUrl: String?
    let uploadedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case documentName = "document_name"
        case fileUrl = "file_url"
        case uploadedAt = "uploaded_at"
    }

    var isUploaded: Bool {
        guard let url = fileUrl, !url.isEmpty else { return false }
        return true
    }
}

struct DBLoanApplicationDocument: Codable, Identifiable, Hashable {
    let id: UUID
    let applicationId: UUID?
    let borrowerId: UUID?
    let documentType: String
    let fileUrl: String
    let createdAt: String?
    let status: String?
    let remarks: String?

    enum CodingKeys: String, CodingKey {
        case id
        case applicationId = "application_id"
        case borrowerId = "borrower_id"
        case documentType = "document_type"
        case fileUrl = "file_url"
        case createdAt = "created_at"
        case status
        case remarks
    }

    func toUploadedDocument() -> BorrowerUploadedDocument {
        BorrowerUploadedDocument(
            id: id,
            borrowerId: borrowerId,
            documentName: documentType,
            fileUrl: fileUrl,
            uploadedAt: createdAt
        )
    }
}

// MARK: - Composite Loan Case (assembled from multiple tables)

struct LoanCase: Identifiable, Hashable {
    let id: UUID
    let application: DBLoanApplication
    let borrower: DBBorrower
    let employment: DBEmployment?
    let financials: DBFinancials?
    let creditProfile: DBCreditProfile?
    let documents: DBDocuments?
    let uploadedDocuments: [BorrowerUploadedDocument]
    let requiredDocuments: [LoanDocumentRequirement]?
    /// Verification status data from loan_application_documents
    let appDocuments: [DBLoanApplicationDocument]

    var riskLevel: OfficerRiskLevel {
        return OfficerRiskLevel.from(creditScore: creditScore)
    }

    var creditScore: Int {
        creditProfile?.creditScore ?? borrower.creditScore ?? 0
    }

    var documentSummary: DocumentSummary {
        let reqs = requiredDocuments ?? DocumentSummary.defaultRequirements
        return DocumentSummary.build(from: reqs, uploadedDocs: uploadedDocuments, appDocs: appDocuments)
    }
}

struct DocumentSummary: Hashable {
    let items: [DocumentItem]

    var verifiedCount: Int {
        items.filter { $0.verificationStatus == "Verified" }.count
    }
    var uploadedCount: Int {
        items.filter { $0.isAvailable }.count
    }
    var totalCount: Int { items.count }
    var hasMissingItems: Bool { uploadedCount < totalCount }

    /// Default 3 document requirements when no product is linked
    static let defaultRequirements: [LoanDocumentRequirement] = [
        LoanDocumentRequirement(name: "PAN Card", isRequired: true),
        LoanDocumentRequirement(name: "Aadhaar Card", isRequired: true),
        LoanDocumentRequirement(name: "Income Proof", isRequired: true),
    ]

    static func isDocumentUploaded(name: String, uploadedDocs: [BorrowerUploadedDocument]) -> Bool {
        return uploadedDocs.contains { doc in
            doc.isUploaded && docNamesMatch(name, doc.documentName)
        }
    }

    static func findUploadedUrl(name: String, uploadedDocs: [BorrowerUploadedDocument]) -> String? {
        return uploadedDocs.first { docNamesMatch(name, $0.documentName) && $0.isUploaded }?.fileUrl
    }

    static func namesMatch(_ a: String, _ b: String) -> Bool {
        return docNamesMatch(a, b)
    }

    private static func docNamesMatch(_ a: String, _ b: String) -> Bool {
        let normA = normalizeDocName(a)
        let normB = normalizeDocName(b)
        if normA == normB { return true }
        if !normA.isEmpty && !normB.isEmpty {
            if normA.contains(normB) || normB.contains(normA) { return true }
        }
        return false
    }

    private static func normalizeDocName(_ name: String) -> String {
        var s = name.lowercased()
        s = s.replacingOccurrences(of: "aadhaar", with: "aadhar")
        for word in ["card", "proof", "document", "copy", "certificate"] {
            s = s.replacingOccurrences(of: word, with: "")
        }
        s = s.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        return s
    }

    private static func parseDocumentDate(_ raw: String?) -> Date {
        guard let raw, !raw.isEmpty else { return .distantPast }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractional.date(from: raw) {
            return parsed
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: raw) ?? .distantPast
    }

    private static func latestMatchingDocument(
        for name: String,
        in appDocs: [DBLoanApplicationDocument]
    ) -> DBLoanApplicationDocument? {
        appDocs
            .filter { doc in namesMatch(name, doc.documentType) }
            .max { lhs, rhs in
                parseDocumentDate(lhs.createdAt) < parseDocumentDate(rhs.createdAt)
            }
    }

    static func build(from requirements: [LoanDocumentRequirement], uploadedDocs: [BorrowerUploadedDocument], appDocs: [DBLoanApplicationDocument] = []) -> DocumentSummary {
        let items = requirements.map { req in
            let uploaded = isDocumentUploaded(name: req.name, uploadedDocs: uploadedDocs)
            let matchingDoc = latestMatchingDocument(for: req.name, in: appDocs)
            let status = matchingDoc?.status ?? (uploaded ? "Pending" : "Not Uploaded")
            return DocumentItem(
                title: req.name,
                isAvailable: uploaded,
                verificationStatus: status
            )
        }
        return DocumentSummary(items: items)
    }
}

struct DocumentItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let isAvailable: Bool
    var verificationStatus: String = "Pending"
}


struct DocumentsRecord: Hashable {
    let identityProof: Bool
    let addressProof: Bool
    let incomeDocument: Bool
    let collateralPaper: Bool

    var items: [DocumentItem] {
        [
            DocumentItem(title: "Identity Proof", isAvailable: identityProof),
            DocumentItem(title: "Address Proof", isAvailable: addressProof),
            DocumentItem(title: "Income Document", isAvailable: incomeDocument),
            DocumentItem(title: "Collateral Paper", isAvailable: collateralPaper)
        ]
    }

    var missingTypes: [DocumentType] {
        var types: [DocumentType] = []
        if !identityProof { types.append(.identityProof) }
        if !addressProof { types.append(.addressProof) }
        if !incomeDocument { types.append(.incomeDocument) }
        if !collateralPaper { types.append(.collateralPaper) }
        return types
    }

    var hasMissingItems: Bool {
        !missingTypes.isEmpty
    }
}


// MARK: - Application ID Generator



// MARK: - User Notification (DB Model)

struct DBUserNotification: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let message: String
    let type: String
    let isRead: Bool
    let createdAt: String
    let metadata: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, message, type
        case isRead = "is_read"
        case createdAt = "created_at"
        case metadata
    }

    var applicationId: UUID? {
        guard let metadata = metadata,
              let data = metadata.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let appIdString = json["application_id"] as? String else {
            return nil
        }
        return UUID(uuidString: appIdString)
    }

    var createdDate: Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: createdAt)
    }
}
