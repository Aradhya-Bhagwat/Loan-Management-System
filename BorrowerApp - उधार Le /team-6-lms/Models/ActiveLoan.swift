import Foundation

struct ActiveLoan: Codable, Identifiable {
    let id: UUID
    let applicationId: UUID
    let disbursedAt: String?
    let outstandingBalance: Double
    let isNpa: Bool
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
