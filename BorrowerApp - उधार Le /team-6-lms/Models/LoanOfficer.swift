import Foundation

struct LoanOfficer: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let email: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case role
    }
}
