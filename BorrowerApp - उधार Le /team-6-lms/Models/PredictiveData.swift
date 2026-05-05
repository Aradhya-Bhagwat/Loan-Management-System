import Foundation

struct PredictiveData: Encodable {
    let borrower_id: UUID
    let monthly_income: Double
    let salary_date: Int
    let income_stability: String
    let monthly_expenses: Double
    let essential_expenses: Double
    let non_essential_expenses: Double
    let current_balance: Double
    let avg_balance_30d: Double
    let balance_before_emi: Double
    let emi_amount: Double
    let emi_due_date: String
    let emi_history: String
    let delay_days: Int
    let total_emi: Double
    let num_loans: Int
    let missed_payments: Int
    let credit_score_trend: String
    let late_payment_freq: Int
    let payment_just_before_due: Bool
    let partial_payments: Bool
}
