import Foundation

struct CompetitiveRate: Identifiable, Codable {
    var id: UUID = UUID()
    var productType: String
    var rateMin: Double
    var rateAvg: Double
    var rateMax: Double
    var feeMin: Double
    var feeAvg: Double
    var feeMax: Double
    var tenureMin: Int
    var tenureAvg: Int
    var tenureMax: Int
    var amountMin: Double
    var amountAvg: Double
    var amountMax: Double
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case productType = "product_type"
        case rateMin = "rate_min"
        case rateAvg = "rate_avg"
        case rateMax = "rate_max"
        case feeMin = "fee_min"
        case feeAvg = "fee_avg"
        case feeMax = "fee_max"
        case tenureMin = "tenure_min"
        case tenureAvg = "tenure_avg"
        case tenureMax = "tenure_max"
        case amountMin = "amount_min"
        case amountAvg = "amount_avg"
        case amountMax = "amount_max"
        case updatedAt = "updated_at"
    }
}