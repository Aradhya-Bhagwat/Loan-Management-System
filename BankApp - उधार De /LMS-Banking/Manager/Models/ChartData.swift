import Foundation

struct MonthlyDisbursement: Identifiable, Codable {
    var id = UUID()
    let month: String
    let amount: Double
}

struct DefaultTrend: Identifiable, Codable {
    var id = UUID()
    let month: String
    let count: Int
}

struct LoanDistribution: Identifiable, Codable {
    var id = UUID()
    let type: String
    let percentage: Double
}

struct SectorPerformance: Identifiable, Codable {
    var id = UUID()
    let sector: String
    let disbursed: Double
    let recovered: Double
}