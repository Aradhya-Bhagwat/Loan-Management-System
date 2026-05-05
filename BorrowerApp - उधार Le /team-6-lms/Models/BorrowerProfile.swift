import Foundation

struct BorrowerProfile: Codable, Identifiable {
    var id: UUID? = nil
    var fullName: String? = nil
    var dob: String? = nil
    var gender: String? = nil
    var mobile: String
    var email: String? = nil
    var panNumber: String? = nil
    var aadhaarNumber: String? = nil
    var address: String? = nil
    var kycStatus: KYCStatus? = nil
    var creditScore: Int = 750
    var declaredMonthlyIncome: Double? = nil
    var employmentType: String? = nil

    var panVerified: Bool = false
    var aadhaarVerified: Bool = false
    var aadhaarRefId: String? = nil

    var accountHolderName: String? = nil
    var bankAccountNumber: String? = nil
    var ifscCode: String? = nil

    var branch: Branch? = nil

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
        case creditScore = "credit_score"
        case declaredMonthlyIncome = "declared_monthly_income"
        case employmentType = "employment_type"

        case accountHolderName = "account_holder_name"
        case bankAccountNumber = "bank_account_number"
        case ifscCode = "ifsc_code"
        case branch
        case panVerified = "pan_verified"
        case aadhaarVerified = "aadhaar_verified"
        case aadhaarRefId = "aadhaar_ref_id"
    }
}
