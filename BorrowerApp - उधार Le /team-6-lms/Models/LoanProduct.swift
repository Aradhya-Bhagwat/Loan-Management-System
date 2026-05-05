

import Foundation

struct LoanProduct: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let baseRate: Double
    let maxRate: Double
    let processingFee: Double
    let minTenure: Int
    let maxTenure: Int
    let eligibilityRules: String?
    let requiredDocuments: [LoanProductDocument]
    let requiredEmploymentFields: [String]?
    let minAmount: Double?
    let maxAmount: Double?
    let managerRate: Double?
    let managerProcessingFee: Double?
    let managerMinTenure: Int?
    let managerMaxTenure: Int?
    let managerMinAmount: Double?
    let managerMaxAmount: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case baseRate = "base_rate"
        case maxRate = "max_rate"
        case processingFee = "processing_fee"
        case minTenure = "min_tenure"
        case maxTenure = "max_tenure"
        case eligibilityRules = "eligibility_rules"
        case requiredDocuments = "required_documents"
        case requiredEmploymentFields = "required_employment_fields"
        case minAmount = "min_amount"
        case maxAmount = "max_amount"
        case managerRate = "manager_rate"
        case managerProcessingFee = "manager_processing_fee"
        case managerMinTenure = "manager_min_tenure"
        case managerMaxTenure = "manager_max_tenure"
        case managerMinAmount = "manager_min_amount"
        case managerMaxAmount = "manager_max_amount"
    }
}

struct LoanProductDocument: Codable, Hashable {
    let name: String
    let isRequired: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self.name = str
            self.isRequired = true
        } else {
            let dict = try decoder.container(keyedBy: CodingKeys.self)

            if let n = try? dict.decode(String.self, forKey: .name) {
                self.name = n
            } else if let t = try? dict.decode(String.self, forKey: .title) {
                self.name = t
            } else {
                self.name = "Unknown Document"
            }
            self.isRequired = try? dict.decode(Bool.self, forKey: .isRequired)
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, title, label
        case isRequired = "required"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(isRequired, forKey: .isRequired)
    }
}
