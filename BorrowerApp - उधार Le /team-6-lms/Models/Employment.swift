

import Foundation

struct Employment: Codable {
    let id: Int?
    let borrowerId: UUID
    let employmentType: EmploymentType
    let companyName: String?
    let industryType: String?
    let jobRole: String?
    let yearsExperience: Int?
    let monthlyIncome: Double
    let incomeStabilityScore: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case employmentType = "employment_type"
        case companyName = "company_name"
        case industryType = "industry_type"
        case jobRole = "job_role"
        case yearsExperience = "years_experience"
        case monthlyIncome = "monthly_income"
        case incomeStabilityScore = "income_stability_score"
    }
}
