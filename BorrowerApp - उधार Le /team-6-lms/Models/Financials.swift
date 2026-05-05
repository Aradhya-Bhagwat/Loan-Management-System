

import Foundation

struct Financials: Codable {
    let borrowerId: Int
    let existingLoansCount: Int
    let totalEmi: Double
    let creditCardUsage: Double?
    let savingsBalance: Double?

    enum CodingKeys: String, CodingKey {
        case borrowerId = "borrower_id"
        case existingLoansCount = "existing_loans_count"
        case totalEmi = "total_emi"
        case creditCardUsage = "credit_card_usage"
        case savingsBalance = "savings_balance"
    }
}
