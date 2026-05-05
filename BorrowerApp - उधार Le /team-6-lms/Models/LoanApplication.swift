

import Foundation

struct LoanApplication: Codable, Identifiable {
    let id: UUID?
    let borrowerId: UUID?
    let loanAmount: Double
    let tenureMonths: Int
    let interestRate: Double?
    let purpose: String
    let status: ApplicationStatus
    var createdAt: String?
    var updatedAt: String?
    var assignedOfficerId: UUID?
    var employerName: String?
    var monthlyIncome: Double?
    let productId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case loanAmount = "loan_amount"
        case tenureMonths = "tenure_months"
        case interestRate = "interest_rate"
        case purpose
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case assignedOfficerId = "assigned_officer_id"
        case employerName = "employer_name"
        case monthlyIncome = "monthly_income"
        case productId = "product_id"
    }

    func withStatus(_ newStatus: ApplicationStatus) -> LoanApplication {
        LoanApplication(
            id: id,
            borrowerId: borrowerId,
            loanAmount: loanAmount,
            tenureMonths: tenureMonths,
            interestRate: interestRate,
            purpose: purpose,
            status: newStatus,
            createdAt: createdAt,
            updatedAt: updatedAt,
            assignedOfficerId: assignedOfficerId,
            employerName: employerName,
            monthlyIncome: monthlyIncome,
            productId: productId
        )
    }
}
