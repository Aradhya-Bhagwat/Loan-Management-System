

import Foundation

struct CreditProfile: Codable {
    let borrowerId: Int
    let creditScore: Int
    let missedPayments: Int
    let creditHistoryLength: Int 
    let creditUtilization: Double

    enum CodingKeys: String, CodingKey {
        case borrowerId = "borrower_id"
        case creditScore = "credit_score"
        case missedPayments = "missed_payments"
        case creditHistoryLength = "credit_history_length"
        case creditUtilization = "credit_utilization"
    }
}
