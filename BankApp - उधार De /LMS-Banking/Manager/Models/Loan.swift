import Foundation

enum RiskLevel: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum LoanStatus: String, Codable {
    case submitted = "submitted"
    case underReview = "under_review"
    case recommended = "recommended"
    case approved = "approved"
    case rejected = "rejected"
    case returnedForCorrection = "returned_for_correction"
}

struct Loan: Identifiable, Codable, Hashable {
    let id: UUID
    let borrowerId: UUID?
    let borrowerName: String
    let amount: String
    let amountValue: Double
    let risk: RiskLevel
    let officer: String
    let status: LoanStatus
    let purpose: String
    let tenure: String
    let creditScore: Int
    let income: String
    let sanctionLetterUrl: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case borrowerName = "borrower_name"
        case amount
        case amountValue = "amount_value"
        case risk
        case officer
        case status
        case purpose
        case tenure
        case creditScore = "credit_score"
        case income
        case sanctionLetterUrl = "sanction_letter_url"
    }

    init(id: UUID, borrowerId: UUID?, borrowerName: String, amount: String, amountValue: Double,
         risk: RiskLevel, officer: String, status: LoanStatus, purpose: String, tenure: String,
         creditScore: Int, income: String, sanctionLetterUrl: String?, createdAt: Date? = nil) {
        self.id = id
        self.borrowerId = borrowerId
        self.borrowerName = borrowerName
        self.amount = amount
        self.amountValue = amountValue
        self.risk = risk
        self.officer = officer
        self.status = status
        self.purpose = purpose
        self.tenure = tenure
        self.creditScore = creditScore
        self.income = income
        self.sanctionLetterUrl = sanctionLetterUrl
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        borrowerId = try container.decodeIfPresent(UUID.self, forKey: .borrowerId)
        borrowerName = try container.decode(String.self, forKey: .borrowerName)
        amount = try container.decode(String.self, forKey: .amount)
        amountValue = try container.decode(Double.self, forKey: .amountValue)
        risk = try container.decode(RiskLevel.self, forKey: .risk)
        officer = try container.decode(String.self, forKey: .officer)
        status = try container.decode(LoanStatus.self, forKey: .status)
        purpose = try container.decode(String.self, forKey: .purpose)
        tenure = try container.decode(String.self, forKey: .tenure)
        creditScore = try container.decode(Int.self, forKey: .creditScore)
        income = try container.decode(String.self, forKey: .income)
        sanctionLetterUrl = try container.decodeIfPresent(String.self, forKey: .sanctionLetterUrl)
        createdAt = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(borrowerId, forKey: .borrowerId)
        try container.encode(borrowerName, forKey: .borrowerName)
        try container.encode(amount, forKey: .amount)
        try container.encode(amountValue, forKey: .amountValue)
        try container.encode(risk, forKey: .risk)
        try container.encode(officer, forKey: .officer)
        try container.encode(status, forKey: .status)
        try container.encode(purpose, forKey: .purpose)
        try container.encode(tenure, forKey: .tenure)
        try container.encode(creditScore, forKey: .creditScore)
        try container.encode(income, forKey: .income)
        try container.encodeIfPresent(sanctionLetterUrl, forKey: .sanctionLetterUrl)
    }
}

enum LoanSegment: String, CaseIterable {
    case loanProduct = "Loan Product"
    case risk = "Risk"
    case officers = "Officers"
}

struct ApplicationIDGenerator {
    static func generate(from uuid: UUID) -> String {
        let short = uuid.uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(6)
            .uppercased()

        return "APP-\(short)"
    }
}
