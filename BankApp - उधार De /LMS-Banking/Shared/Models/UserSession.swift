import Foundation
import SwiftUI

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case borrower = "Borrower"
    case officer = "Loan Officer"
    case manager = "Manager"
    case admin = "Admin"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .borrower: return "Borrower"
        case .officer: return "Officer"
        case .manager: return "Manager"
        case .admin: return "Admin"
        }
    }

    var subtitle: String {
        switch self {
        case .borrower: return "Borrower"
        case .officer: return "Loan Officer"
        case .manager: return "Manager"
        case .admin: return "Admin"
        }
    }
}

enum UserVerificationStatus: String, Codable {
    case verified = "Verified"
    case pending = "Pending"
    case rejected = "Rejected"
    case blocked = "Blocked"

    var title: String { rawValue }

    var textColor: Color {
        switch self {
        case .verified: return Color.appGreen
        case .pending: return Color.appOrange
        case .rejected: return Color.appRed
        case .blocked: return Color.appRed
        }
    }

    var backgroundColor: Color {
        switch self {
        case .verified: return Color.appGreen.opacity(0.1)
        case .pending: return Color.appOrange.opacity(0.1)
        case .rejected: return Color.appRed.opacity(0.1)
        case .blocked: return Color.appRed.opacity(0.1)
        }
    }
}

enum Branch: String, Codable, CaseIterable, Identifiable {
    case north = "North: Delhi"
    case south = "South: Bengaluru"
    case east = "East: Kolkata"
    case west = "West: Mumbai"
    case central = "Central: Nagpur"

    var id: String { rawValue }
    var title: String { rawValue }
}

struct UserSession: Codable, Identifiable {
    let id: UUID
    let name: String
    let email: String
    let phone: String?
    let role: UserRole
    let department: String?
    let branch: String?
    let status: UserVerificationStatus?
    let joinedAt: Date?
    let failedLoginAttempts: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name = "full_name"
        case email
        case phone
        case role
        case department
        case branch
        case status
        case joinedAt = "joined_at"
        case failedLoginAttempts = "failed_login_attempts"
    }

    init(
        id: UUID,
        name: String,
        email: String,
        role: UserRole,
        status: UserVerificationStatus? = .pending,
        phone: String? = nil,
        department: String? = nil,
        branch: String? = nil,
        joinedAt: Date? = nil,
        failedLoginAttempts: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.status = status
        self.phone = phone
        self.department = department
        self.branch = branch
        self.joinedAt = joinedAt
        self.failedLoginAttempts = failedLoginAttempts
    }
}
