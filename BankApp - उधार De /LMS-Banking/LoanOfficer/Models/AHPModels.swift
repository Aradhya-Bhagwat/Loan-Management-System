import SwiftUI
import Combine

// MARK: - Data Models

struct AHPCriterion: Identifiable {
    let id = UUID()
    let name: String
    let weight: Double
}

struct AHPMatrix {
    let matrix: [[Double]]
}

struct LoanApplicantProfile {
    let income: Double
    let creditScore: Double
    let employmentYears: Double
    let existingDebt: Double
    let savingsBalance: Double
    let creditUtilization: Double
    let loanAmount: Double
    let tenure: Int
}

// MARK: - AHP Engine

class AHPEngine {

    func calculateWeights(matrix: [[Double]]) -> [Double] {
        guard !matrix.isEmpty else { return [] }
        let size = matrix.count

        var colSums = [Double](repeating: 0, count: size)
        for col in 0..<size {
            for row in 0..<size {
                colSums[col] += matrix[row][col]
            }
        }

        var normalizedMatrix = matrix
        for row in 0..<size {
            for col in 0..<size {
                if colSums[col] != 0 {
                    normalizedMatrix[row][col] /= colSums[col]
                }
            }
        }

        var weights = [Double](repeating: 0, count: size)
        for row in 0..<size {
            let rowSum = normalizedMatrix[row].reduce(0, +)
            weights[row] = rowSum / Double(size)
        }

        return weights
    }

    func calculateScore(profile: LoanApplicantProfile, weights: [Double]) -> (score: Double, inputs: [Double]) {
        guard weights.count == 5 else { return (0, []) }

        // Income vs Loan EMI capacity (can they afford this loan?)
        let estimatedEMI = (profile.loanAmount * 1.12) / Double(max(profile.tenure, 1))
        let totalObligations = profile.existingDebt + estimatedEMI
        let incomeCapacity = profile.income > 0 ? max(0, 1.0 - (totalObligations / profile.income)) : 0

        // Credit Score normalized (300–900 range)
        let creditNorm = max(0.0, min((profile.creditScore - 300.0) / 600.0, 1.0))

        // Employment Stability (capped at 15 yrs as "maximum stability")
        let stabilityNorm = min(profile.employmentYears / 15.0, 1.0)

        // Credit Utilization (lower is better, 0–100% range)
        let utilizationNorm = max(0, 1.0 - min(profile.creditUtilization / 100.0, 1.0))

        // Savings Buffer (months of EMI covered by savings)
        let monthsCovered = estimatedEMI > 0 ? (profile.savingsBalance / estimatedEMI) : 0
        let savingsNorm = min(monthsCovered / 12.0, 1.0) // 12 months coverage = perfect

        let inputs = [incomeCapacity, creditNorm, stabilityNorm, utilizationNorm, savingsNorm]

        var score = 0.0
        for i in 0..<5 {
            score += inputs[i] * weights[i]
        }

        return (score, inputs)
    }

    func riskCategory(score: Double) -> String {
        if score > 0.75 { return "Low Risk" }
        if score >= 0.5 { return "Medium Risk" }
        return "High Risk"
    }
}

// MARK: - ViewModel

class LoanScoringViewModel: ObservableObject {
    @Published var profile: LoanApplicantProfile
    @Published var weights: [Double] = []
    @Published var normalizedInputs: [Double] = []
    @Published var score: Double = 0.0
    @Published var riskCategory: String = ""
    @Published var insightLine1: String = ""
    @Published var insightLine2: String = ""

    private let engine = AHPEngine()
    let criteriaNames = [
        "Repayment Capacity",
        "Credit History",
        "Employment Stability",
        "Credit Utilization",
        "Savings Buffer"
    ]

    let criteriaDescriptions = [
        "Can they afford this loan's EMI on top of existing debt?",
        "How reliable is their past repayment behavior?",
        "How long and stable is their current employment?",
        "How much of their available credit are they using?",
        "How many months of EMI can their savings cover?"
    ]

    init(profile: LoanApplicantProfile) {
        self.profile = profile
        computeScore()
    }

    func computeScore() {
        let defaultMatrix = [
            [1.0,   3.0,   5.0,   7.0,   5.0],
            [1.0/3.0, 1.0,   3.0,   5.0,   3.0],
            [1.0/5.0, 1.0/3.0, 1.0,   3.0,   3.0],
            [1.0/7.0, 1.0/5.0, 1.0/3.0, 1.0,   1.0],
            [1.0/5.0, 1.0/3.0, 1.0/3.0, 1.0,   1.0]
        ]

        self.weights = engine.calculateWeights(matrix: defaultMatrix)
        let result = engine.calculateScore(profile: profile, weights: weights)
        self.score = result.score
        self.normalizedInputs = result.inputs
        self.riskCategory = engine.riskCategory(score: score)
        generateInsight()
    }

    private func generateInsight() {
        guard normalizedInputs.count == 5 else { return }

        // Find the weakest and strongest factors
        let weakestIndex = normalizedInputs.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
        let strongestIndex = normalizedInputs.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0

        let weakName = criteriaNames[weakestIndex]
        let strongName = criteriaNames[strongestIndex]

        // Line 1: What's working
        if normalizedInputs[strongestIndex] >= 0.7 {
            insightLine1 = "Primary Strength: \(strongName) is well above average."
        } else {
            insightLine1 = "Profile Status: No primary strength identified."
        }

        // Line 2: What needs attention
        if normalizedInputs[weakestIndex] < 0.4 {
            insightLine2 = "Primary Risk: \(weakName) requires further verification."
        } else {
            insightLine2 = "Risk Status: All factors are within acceptable limits."
        }
    }

    var riskColor: Color {
        switch riskCategory {
        case "Low Risk": return .green
        case "Medium Risk": return .orange
        case "High Risk": return .red
        default: return .secondary
        }
    }
}
