import Foundation

enum KYCStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case verified = "verified"
    case rejected = "rejected"
}

struct Borrower: Identifiable, Codable {
    let id: UUID
    let fullName: String
    let dob: String? // Changed to String for simplicity with JSON, can be Date with custom decoder
    let gender: String?
    let mobile: String?
    let email: String?
    let panNumber: String?
    let aadhaarNumber: String?
    let address: String?
    var kycStatus: KYCStatus = .pending
    let accountHolderName: String?
    let bankAccountNumber: String?
    let ifscCode: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case dob
        case gender
        case mobile
        case email
        case panNumber = "pan_number"
        case aadhaarNumber = "aadhaar_number"
        case address
        case kycStatus = "kyc_status"
        case accountHolderName = "account_holder_name"
        case bankAccountNumber = "bank_account_number"
        case ifscCode = "ifsc_code"
    }
}

struct CreditProfile: Identifiable, Codable {
    let id: UUID
    let borrowerId: Int
    let creditScore: Int
    let missedPayments: Int
    let creditHistoryLength: Int
    let creditUtilization: Double
}
