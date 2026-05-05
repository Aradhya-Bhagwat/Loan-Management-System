import Foundation

struct LoanOfficer: Identifiable, Codable {
//    var id = UUID()
    let id: UUID
    let name: String
    let role: String
    let loansHandled: Int
    let approvalRate: Double
    let defaultRate: Double
    let activeLoans: Int
    let initials: String

    enum CodingKeys: String, CodingKey {
        case id
        case name = "full_name"
        case role
        case loansHandled = "loans_handled"
        case approvalRate = "approval_rate"
        case defaultRate = "default_rate"
        case activeLoans = "active_loans"
        case initials
    }
}
