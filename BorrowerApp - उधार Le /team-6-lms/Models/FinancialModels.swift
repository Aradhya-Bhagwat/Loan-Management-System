import Foundation

struct EMISchedule: Codable, Identifiable {
    let id: UUID
    let loanId: UUID
    let dueDate: String
    let amount: Double
    let status: String 
    let paidAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case loanId = "loan_id"
        case dueDate = "due_date"
        case amount
        case status
        case paidAt = "paid_at"
    }
}

struct FinancialInsight: Codable, Identifiable {
    let id: Int
    let borrowerId: UUID
    let insightType: String
    let content: String
    let isAcknowledged: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case insightType = "insight_type"
        case content
        case isAcknowledged = "is_acknowledged"
    }
}
