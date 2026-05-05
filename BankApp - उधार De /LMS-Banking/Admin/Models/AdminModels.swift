import SwiftUI

enum AdminTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case users = "Users"
    case control = "Control"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .users: return "person.2.fill"
        case .control: return "gearshape.fill"
        }
    }
}

struct DashboardLayoutMetrics {
    let width: CGFloat

    var isCompact: Bool { width < 820 }
    var isLargePadLayout: Bool { width >= 1000 }
    var isNarrowPhone: Bool { width < 390 }
    var horizontalPadding: CGFloat { isCompact ? 14 : 34 }
    var sectionSpacing: CGFloat { isCompact ? 18 : 30 }
    var contentWidth: CGFloat { min(width - (horizontalPadding * 2), 1500) }
    var metricColumns: [GridItem] {
        let count = isCompact ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: isCompact ? 16 : 24), count: count)
    }
    var userGridColumns: [GridItem] {
        let count: Int
        if width > 1200 {
            count = 4
        } else {
            count = 2
        }
        return Array(repeating: GridItem(.flexible(), spacing: isCompact ? 12 : 20), count: count)
    }
    var pageTitleFont: Font { isCompact ? .system(size: 32, weight: .bold) : .system(size: 56, weight: .bold) }
    var sectionTitleFont: Font { isCompact ? .title3.bold() : .title2.bold() }
}


struct UserItem: Identifiable {
    let id: UUID
    let name: String
    let initials: String
    let role: UserRole
    let status: UserVerificationStatus
    let email: String
    let phone: String
    let joined: String
    let branch: String
}

struct AuditEntry: Identifiable, Decodable {
    let id: UUID
    private let title: String?
    private let actor: String?
    private let category: String?
    private let branch: String?
    private let status: String?
    private let icon: String?
    private let iconColorName: String?
    private let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, actor, category, branch, status, icon
        case iconColorName = "icon_color"
        case createdAt = "created_at"
    }

    var displayTitle: String { title ?? "Unknown Action" }
    var displayActor: String { actor ?? "System" }
    var displayCategory: String { category ?? "General" }
    var displayBranch: String { branch ?? "Main" }
    var displayStatus: String { status ?? "Processed" }
    var displayIcon: String { icon ?? "bell.fill" }

    var time: String {
        guard let createdAt = createdAt else { return "Recent" }
        return String(createdAt.prefix(10)) 
    }

    var iconColor: Color {
        switch (iconColorName ?? "").lowercased() {
        case "green": return Color.appGreen
        case "red": return Color.appRed
        case "blue": return .appBlue
        case "orange": return Color.appOrange
        default: return .secondary
        }
    }

    var statusColor: Color {
        switch displayStatus {
        case "Approved": return Color.appGreen
        case "Rejected": return Color.appRed
        case "Banned": return Color.appRed
        case "Active": return Color.appGreen
        default: return Color.appOrange
        }
    }
}

enum AuditSearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case actor = "Actor"
    case action = "Action"

    var id: String { rawValue }
    var title: String { rawValue }
}

enum AdminReportType: String, CaseIterable, Codable {
    case portfolioHealth
    case repaymentTrend
    case npaAnalysis
    case auditCompliance

    var title: String {
        switch self {
        case .portfolioHealth: return "Portfolio Health"
        case .repaymentTrend: return "Repayment Trends"
        case .npaAnalysis: return "NPA Analysis"
        case .auditCompliance: return "Active Loans"
        }
    }

    var previewTitle: String {
        switch self {
        case .portfolioHealth: return "Institution Portfolio Snapshot"
        case .repaymentTrend: return "Repayment Performance Report"
        case .npaAnalysis: return "NPA Exposure Summary"
        case .auditCompliance: return "Currently Active Loan Portfolio"
        }
    }

    var tint: Color {
        switch self {
        case .portfolioHealth: return Color.appGreen
        case .repaymentTrend: return Color.appGreen
        case .npaAnalysis: return Color.appGreen
        case .auditCompliance: return Color.appGreen
        }
    }

    var tintLabel: String {
        switch self {
        case .portfolioHealth: return "Portfolio"
        case .repaymentTrend: return "Repayment"
        case .npaAnalysis: return "Risk"
        case .auditCompliance: return "Compliance"
        }
    }
}

enum ReportRange: String, CaseIterable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"

    var title: String { rawValue }

    var summaryText: String {
        switch self {
        case .daily: return "Short-form report focused on today's operational movement."
        case .weekly: return "Branch and portfolio summary for the last 7 days."
        case .monthly: return "Comprehensive export covering the full monthly cycle."
        case .custom: return "Report covering your selected date range."
        }
    }
}

enum ReportFormat: String, CaseIterable, Codable {
    case pdf = "PDF"
    case csv = "CSV"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .csv: return "tablecells"
        }
    }
}

struct GeneratedReport: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let type: AdminReportType
    let range: ReportRange
    let format: ReportFormat
    let generatedAt: String
    let includesAuditTrail: Bool
    let includesBranchBreakdown: Bool
    var fileUrl: String? = nil
    var createdAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, name, type, range, format
        case generatedAt = "generated_at"
        case includesAuditTrail = "includes_audit_trail"
        case includesBranchBreakdown = "includes_branch_breakdown"
        case fileUrl = "file_url"
        case createdAt = "created_at"
    }
}

struct LoanProduct: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var baseRate: Double
    var maxRate: Double
    var processingFee: Double
    var minTenureMonths: Int
    var maxTenureMonths: Int
    var minAmount: Double
    var maxAmount: Double
    var eligibilityRules: String
    var requiredDocuments: [LoanDocumentRequirement]
    
    // Manager-configured exact parameters (constrained by Admin bounds)
    var managerRate: Double?
    var managerProcessingFee: Double?
    var managerMinTenureMonths: Int?
    var managerMaxTenureMonths: Int?
    var managerMinAmount: Double?
    var managerMaxAmount: Double?

    enum CodingKeys: String, CodingKey {
        case id, name
        case baseRate = "base_rate"
        case maxRate = "max_rate"
        case processingFee = "processing_fee"
        case minTenureMonths = "min_tenure"
        case maxTenureMonths = "max_tenure"
        case minAmount = "min_amount"
        case maxAmount = "max_amount"
        case eligibilityRules = "eligibility_rules"
        case requiredDocuments = "required_documents"
        case managerRate = "manager_rate"
        case managerProcessingFee = "manager_processing_fee"
        case managerMinTenureMonths = "manager_min_tenure"
        case managerMaxTenureMonths = "manager_max_tenure"
        case managerMinAmount = "manager_min_amount"
        case managerMaxAmount = "manager_max_amount"
    }
}

struct LoanDocumentRequirement: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    var isRequired: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case isRequired = "is_required"
    }
}

struct NotificationSetting: Identifiable, Codable {
    var id = UUID()
    let title: String
    var isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, title
        case isEnabled = "is_enabled"
    }
}

struct NotificationTemplate: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subject: String
    var body: String

    enum CodingKeys: String, CodingKey {
        case id, title, subject, body
    }
}

// MARK: - GDPR Compliance Models

struct PrivacySettings: Identifiable, Codable {
    var id: UUID = UUID()
    var retentionPeriodYears: Int = 10
    var isAutoPurgeEnabled: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case id
        case retentionPeriodYears = "retention_period_years"
        case isAutoPurgeEnabled = "auto_purge_enabled"
    }
}

struct ConsentTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String = "Master Services & Privacy Agreement"
    var version: String = "1.0"
    var content: String = """
    Institutional Privacy Policy & Master Terms of Service
    Effective Date: January 1, 2026
    
    1. Data Collection and Usage
    We collect personal and financial information (e.g., identity documents, credit history) strictly for evaluating loan applications, managing accounts, and fulfilling legal/regulatory obligations (KYC/AML).
    
    2. Data Security and Storage
    All sensitive data is encrypted using AES-256 in transit and at rest. Strict role-based access controls limit internal visibility.
    
    3. Data Retention (GDPR Article 5)
    In compliance with financial regulations, loan records and associated personal data are securely retained for a minimum of ten (10) years following account closure. After this period, data is automatically purged.
    
    4. Financial Obligations & Fraud
    Borrowers must adhere strictly to agreed-upon EMI schedules. Falsifying financial documents constitutes fraud and will result in immediate termination, legal action, and reporting to authorities.
    
    5. Your Rights
    You have the right to access your data, request corrections, and request erasure (subject to legal financial retention mandates). Contact our Data Protection Officer for inquiries.
    """
    var isActive: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case id, title, version, content
        case isActive = "is_active"
    }
}

struct SystemConfig: Identifiable, Codable {
    var id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var institutionName: String = "उधार De Institutional Banking"
    var supportPhone: String = "+1 (800) 555-0199"
    var supportEmail: String = "support@udharde.com"
    var defaultCurrency: String = "INR"
    var headquartersCity: String = "New York, NY"
    
    enum CodingKeys: String, CodingKey {
        case id
        case institutionName = "institution_name"
        case supportPhone = "support_phone"
        case supportEmail = "support_email"
        case defaultCurrency = "default_currency"
        case headquartersCity = "headquarters_city"
    }
}
