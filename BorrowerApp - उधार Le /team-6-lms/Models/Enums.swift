

import Foundation
import SwiftUI

enum KYCStatus: String, Codable {
    case pending = "pending"
    case verified = "verified"
    case rejected = "rejected"
}

enum ApplicationStatus: String, Codable {
    case submitted = "submitted"
    case underReview = "under_review"
    case recommended = "recommended"
    case approved = "approved"
    case disbursed = "disbursed"
    case rejected = "rejected"

    var color: Color {
            switch self {
            case .submitted, .underReview, .recommended: return Color.theme.warning
            case .approved, .disbursed: return Color.theme.success
            case .rejected: return Color.theme.danger
            }
        }

        var icon: String {
            switch self {
            case .submitted, .underReview, .recommended: return "clock.fill"
            case .approved, .disbursed: return "checkmark.circle.fill"
            case .rejected: return "xmark.circle.fill"
            }
        }
}

enum EmploymentType: String, Codable {
    case salaried = "salaried"
    case selfEmployed = "self_employed"
}

enum Branch: String, Codable, CaseIterable {
    case north = "North: Delhi"
    case south = "South: Bengaluru"
    case east = "East: Kolkata"
    case west = "West: Mumbai"
    case central = "Central: Nagpur"

    var displayName: String {
        switch self {
        case .north: return "Delhi"
        case .south: return "Bengaluru"
        case .east: return "Kolkata"
        case .west: return "Mumbai"
        case .central: return "Nagpur"
        }
    }

    var ifscPrefix: String {
        switch self {
        case .north:   return "CRED0"   
        case .south:   return "CRED1"   
        case .east:    return "CRED2"   
        case .west:    return "CRED3"   
        case .central: return "CRED4"   
        }
    }

    var suggestedIFSC: String {
        switch self {
        case .north:   return "CRED0001001"   
        case .south:   return "CRED0001002"   
        case .east:    return "CRED0001003"   
        case .west:    return "CRED0001004"   
        case .central: return "CRED0001005"   
        }
    }

    func isValidIFSC(_ ifsc: String) -> Bool {
        ifsc.uppercased().hasPrefix(ifscPrefix)
    }
}
