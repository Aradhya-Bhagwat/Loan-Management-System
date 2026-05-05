

import Foundation

struct BorrowerDocuments: Codable {
    let borrowerId: UUID?
    var panDocUrl: String?
    var aadhaarDocUrl: String?
    var incomeProofUrl: String?
    var collateralDocUrl: String?
    var businessProofUrl: String?

    enum CodingKeys: String, CodingKey {
        case borrowerId = "borrower_id"
        case panDocUrl = "pan_doc_url"
        case aadhaarDocUrl = "aadhaar_doc_url"
        case incomeProofUrl = "income_proof_url"
        case collateralDocUrl = "collateral_doc_url"
        case businessProofUrl = "business_proof_url"
    }
}
