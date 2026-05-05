import Foundation

enum OverdueStatus: String, Codable {
    case overdue = "Overdue"
    case defaulted = "Default"
}

struct OverdueLoan: Identifiable, Codable {
    var id = UUID()
    let borrowerName: String
    let amount: String
    let dpd: Int
    let risk: RiskLevel
    let officer: String
    let status: OverdueStatus
    var assignedOfficerId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerName = "borrower_name"
        case amount
        case dpd
        case risk
        case officer
        case status
        case assignedOfficerId = "assigned_officer_id"
    }
}
