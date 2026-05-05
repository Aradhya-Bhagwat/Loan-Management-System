//
//  LoanOfficerAIInsightsCard.swift
//  LMS-Banking
//
//  AI Insights section for Loan Officer – Application Details Screen.
//  Uses AHP (Analytic Hierarchy Process) weighted scoring across
//  10 industry-standard underwriting factors to produce a Loan Health Score.
//

import SwiftUI

// MARK: - AHP Evaluation Engine

/// Pure-value result produced by the AHP engine.
struct AHPEvaluation {
    let healthScore: Double          // 0 – 100
    let riskLevel: AHPRiskLevel
    let decisionFlag: AHPDecisionFlag
    let factors: [AHPFactor]
    let remarks: [AHPRemark]
    let hardRuleViolations: [String] // non-empty → auto-reject triggers
}

enum AHPRiskLevel: String {
    case low    = "Low Risk"
    case medium = "Medium Risk"
    case high   = "High Risk"

    var color: Color {
        switch self {
        case .low:    return OfficerTheme.iconGreen
        case .medium: return OfficerTheme.iconAmber
        case .high:   return OfficerTheme.iconRed
        }
    }

    var icon: String {
        switch self {
        case .low:    return "checkmark.shield.fill"
        case .medium: return "exclamationmark.shield.fill"
        case .high:   return "xmark.shield.fill"
        }
    }
}

enum AHPDecisionFlag: String {
    case pass   = "Pass"
    case review = "Needs Review"
    case fail   = "Fail"

    var color: Color {
        switch self {
        case .pass:   return OfficerTheme.iconGreen
        case .review: return OfficerTheme.iconAmber
        case .fail:   return OfficerTheme.iconRed
        }
    }
}

struct AHPFactor: Identifiable {
    let id = UUID()
    let name: String
    let weight: Double       // e.g. 0.20
    let score: Double        // 0.0 – 1.0  (normalised)
    let icon: String
    let tint: Color
}

struct AHPRemark: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let sentiment: RemarkSentiment

    enum RemarkSentiment {
        case positive, neutral, negative
        var color: Color {
            switch self {
            case .positive: return OfficerTheme.iconGreen
            case .neutral:  return OfficerTheme.iconAmber
            case .negative: return OfficerTheme.iconRed
            }
        }
    }
}

// MARK: - Scoring Functions

enum AHPScoringEngine {

    /// AHP weights — must sum to 1.0
    static let weights: [(String, Double, String, Color)] = [
        ("Credit Score",          0.20, "creditcard.fill",              OfficerTheme.accentBlue),
        ("Repayment History",     0.15, "clock.arrow.circlepath",       OfficerTheme.iconGreen),
        ("Income Level",          0.10, "indianrupeesign",              OfficerTheme.iconGreen),
        ("Debt-to-Income",        0.10, "chart.bar.fill",              OfficerTheme.iconAmber),
        ("Employment Stability",  0.10, "briefcase.fill",              OfficerTheme.accentBlue),
        ("Employment Risk",       0.10, "building.2.fill",             OfficerTheme.iconAmber),
        ("Existing Debt",         0.08, "banknote.fill",               OfficerTheme.iconRed),
        ("Loan-to-Income",        0.07, "arrow.up.right",              OfficerTheme.iconAmber),
        ("Tenure Risk",           0.05, "calendar.badge.exclamationmark", OfficerTheme.iconAmber),
        ("Fraud / KYC Risk",      0.05, "shield.lefthalf.filled",      OfficerTheme.iconRed),
    ]

    // MARK: Score individual factors (0.0 – 1.0)

    static func scoreCreditScore(_ score: Int) -> Double {
        if score >= 800 { return 1.0 }
        if score >= 750 { return 0.9 }
        if score >= 700 { return 0.8 }
        if score >= 650 { return 0.6 }
        if score >= 600 { return 0.4 }
        return 0.2
    }

    static func scoreRepaymentHistory(missed: Int) -> Double {
        if missed == 0 { return 1.0 }
        if missed <= 1 { return 0.8 }
        if missed <= 3 { return 0.5 }
        return 0.2
    }

    static func scoreIncome(_ monthlyIncome: Double) -> Double {
        if monthlyIncome >= 100_000 { return 1.0 }
        if monthlyIncome >= 60_000  { return 0.8 }
        if monthlyIncome >= 35_000  { return 0.6 }
        if monthlyIncome >= 20_000  { return 0.4 }
        return 0.2
    }

    static func scoreDTI(totalEmi: Double, monthlyIncome: Double) -> Double {
        guard monthlyIncome > 0 else { return 0.2 }
        let dti = (totalEmi / monthlyIncome) * 100.0
        if dti < 30  { return 1.0 }
        if dti < 50  { return 0.7 }
        if dti < 70  { return 0.4 }
        return 0.2
    }

    static func scoreEmploymentStability(yearsExp: Int, incomeStability: Double?) -> Double {
        let stabScore = incomeStability ?? 0.7
        let expScore: Double
        if yearsExp >= 10 { expScore = 1.0 }
        else if yearsExp >= 5 { expScore = 0.8 }
        else if yearsExp >= 2 { expScore = 0.6 }
        else { expScore = 0.3 }
        return (expScore + stabScore) / 2.0
    }

    static func scoreEmploymentRisk(type: String?) -> Double {
        switch (type ?? "").lowercased() {
        case "government", "govt":          return 1.0
        case "mnc":                         return 0.9
        case "private", "salaried":         return 0.8
        case "startup":                     return 0.6
        case "freelancer", "self-employed", "self_employed": return 0.5
        default:                            return 0.7
        }
    }

    static func scoreExistingDebt(count: Int) -> Double {
        if count == 0 { return 1.0 }
        if count <= 1 { return 0.8 }
        if count <= 3 { return 0.5 }
        return 0.2
    }

    static func scoreLoanToIncome(loanAmount: Double, monthlyIncome: Double) -> Double {
        guard monthlyIncome > 0 else { return 0.2 }
        let annualIncome = monthlyIncome * 12
        let ratio = loanAmount / annualIncome
        if ratio < 1   { return 1.0 }
        if ratio < 2   { return 0.8 }
        if ratio < 4   { return 0.5 }
        return 0.2
    }

    static func scoreTenureRisk(months: Int) -> Double {
        if months <= 12  { return 1.0 }
        if months <= 36  { return 0.8 }
        if months <= 60  { return 0.6 }
        return 0.4
    }

    static func scoreFraudKYC(kycStatus: String?) -> Double {
        switch (kycStatus ?? "").lowercased() {
        case "verified":  return 1.0
        case "pending":   return 0.5
        default:          return 0.3
        }
    }

    // MARK: Hard Rules

    static func hardRuleViolations(creditScore: Int, dtiPercent: Double, kycStatus: String?) -> [String] {
        var violations: [String] = []
        if creditScore > 0 && creditScore < 600 {
            violations.append("Credit score below 600 — automatic reject threshold")
        }
        if dtiPercent > 80 {
            violations.append("Debt-to-Income ratio exceeds 80% — unacceptable repayment burden")
        }
        let kyc = (kycStatus ?? "").lowercased()
        if kyc != "verified" && kyc != "pending" {
            violations.append("KYC status unverified — potential fraud risk")
        }
        return violations
    }

    // MARK: Remark Generation

    static func generateRemarks(loan: LoanCase, scores: [Double], dtiPercent: Double) -> [AHPRemark] {
        var remarks: [AHPRemark] = []

        let cs = loan.creditScore
        if cs >= 750 {
            remarks.append(AHPRemark(icon: "star.fill", text: "Strong credit score (CIBIL \(cs))", sentiment: .positive))
        } else if cs >= 650 {
            remarks.append(AHPRemark(icon: "star.leadinghalf.filled", text: "Average credit score (\(cs)) — room for improvement", sentiment: .neutral))
        } else if cs > 0 {
            remarks.append(AHPRemark(icon: "exclamationmark.triangle.fill", text: "Low credit score (\(cs)) — high default risk", sentiment: .negative))
        }

        if dtiPercent < 30 {
            remarks.append(AHPRemark(icon: "checkmark.circle.fill", text: "Healthy debt-to-income ratio (\(String(format: "%.0f", dtiPercent))%)", sentiment: .positive))
        } else if dtiPercent < 60 {
            remarks.append(AHPRemark(icon: "exclamationmark.circle.fill", text: "Moderate repayment burden (DTI \(String(format: "%.0f", dtiPercent))%)", sentiment: .neutral))
        } else {
            remarks.append(AHPRemark(icon: "xmark.circle.fill", text: "High repayment burden (DTI \(String(format: "%.0f", dtiPercent))%)", sentiment: .negative))
        }

        let empType = (loan.employment?.employmentType ?? "").lowercased()
        if empType.contains("govt") || empType.contains("government") {
            remarks.append(AHPRemark(icon: "building.columns.fill", text: "Government employment — highest income stability", sentiment: .positive))
        } else if empType.contains("freelan") || empType.contains("self") {
            remarks.append(AHPRemark(icon: "person.fill.questionmark", text: "Self-employed / Freelancer — income uncertainty risk", sentiment: .negative))
        } else if empType.contains("startup") {
            remarks.append(AHPRemark(icon: "lightbulb.fill", text: "Startup employment — moderate income uncertainty", sentiment: .neutral))
        }

        if let exp = loan.employment?.yearsExperience, exp >= 5 {
            remarks.append(AHPRemark(icon: "briefcase.fill", text: "Strong employment tenure (\(exp) years)", sentiment: .positive))
        } else if let exp = loan.employment?.yearsExperience, exp < 2 {
            remarks.append(AHPRemark(icon: "clock.badge.exclamationmark", text: "Limited work experience (\(exp) year\(exp == 1 ? "" : "s"))", sentiment: .negative))
        }

        let missed = loan.creditProfile?.missedPayments ?? 0
        if missed == 0 {
            remarks.append(AHPRemark(icon: "checkmark.seal.fill", text: "Zero missed payments — excellent repayment track record", sentiment: .positive))
        } else if missed > 3 {
            remarks.append(AHPRemark(icon: "xmark.seal.fill", text: "\(missed) missed payments — poor repayment behaviour", sentiment: .negative))
        }

        if let count = loan.financials?.existingLoansCount, count >= 3 {
            remarks.append(AHPRemark(icon: "exclamationmark.triangle.fill", text: "Multiple existing loans (\(count)) — high debt exposure", sentiment: .negative))
        }

        return remarks
    }

    // MARK: Main Evaluate

    static func evaluate(loan: LoanCase) -> AHPEvaluation {
        let credit     = loan.creditProfile
        let employment = loan.employment
        let financials = loan.financials
        let income     = loan.application.monthlyIncome ?? employment?.monthlyIncome ?? 0
        let totalEmi   = financials?.totalEmi ?? 0
        let dtiPercent = income > 0 ? (totalEmi / income) * 100 : 0

        let scores: [Double] = [
            scoreCreditScore(loan.creditScore),
            scoreRepaymentHistory(missed: credit?.missedPayments ?? 0),
            scoreIncome(income),
            scoreDTI(totalEmi: totalEmi, monthlyIncome: income),
            scoreEmploymentStability(yearsExp: employment?.yearsExperience ?? 0, incomeStability: employment?.incomeStabilityScore),
            scoreEmploymentRisk(type: employment?.employmentType),
            scoreExistingDebt(count: financials?.existingLoansCount ?? 0),
            scoreLoanToIncome(loanAmount: loan.application.loanAmount, monthlyIncome: income),
            scoreTenureRisk(months: loan.application.tenureMonths),
            scoreFraudKYC(kycStatus: loan.borrower.kycStatus),
        ]

        var healthScore: Double = 0
        var factors: [AHPFactor] = []
        for (i, (name, weight, icon, tint)) in weights.enumerated() {
            healthScore += weight * scores[i]
            factors.append(AHPFactor(name: name, weight: weight, score: scores[i], icon: icon, tint: tint))
        }
        healthScore = (healthScore * 100).rounded()

        let risk: AHPRiskLevel
        if healthScore >= 75 { risk = .low }
        else if healthScore >= 55 { risk = .medium }
        else { risk = .high }

        let hardViolations = hardRuleViolations(creditScore: loan.creditScore, dtiPercent: dtiPercent, kycStatus: loan.borrower.kycStatus)
        let decision: AHPDecisionFlag
        if !hardViolations.isEmpty { decision = .fail }
        else if healthScore >= 80 { decision = .pass }
        else if healthScore >= 60 { decision = .review }
        else { decision = .fail }

        let remarks = generateRemarks(loan: loan, scores: scores, dtiPercent: dtiPercent)

        return AHPEvaluation(
            healthScore: healthScore,
            riskLevel: risk,
            decisionFlag: decision,
            factors: factors,
            remarks: remarks,
            hardRuleViolations: hardViolations
        )
    }
}


// MARK: - AI Insights Card

struct AIInsightsCard: View {
    let loan: LoanCase
    @State private var isExpanded = true

    private var evaluation: AHPEvaluation {
        AHPScoringEngine.evaluate(loan: loan)
    }

    var body: some View {
        WhiteCard {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ──────────────────────────────────────────────
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OfficerTheme.accentBlue)

                        Text("AI Insights")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OfficerTheme.textPrimary)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OfficerTheme.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    let eval = evaluation

                    VStack(alignment: .leading, spacing: 16) {

                        // ── Score Row ────────────────────────────────────
                        MinimalScoreRow(score: eval.healthScore, risk: eval.riskLevel, decision: eval.decisionFlag)
                            .padding(.top, 14)

                        // ── Hard Rule Violations ─────────────────────────
                        if !eval.hardRuleViolations.isEmpty {
                            MinimalViolationsSection(violations: eval.hardRuleViolations)
                        }

                        Divider()

                        // ── Remarks ──────────────────────────────────────
                        MinimalRemarksSection(remarks: eval.remarks)

                        Divider()

                        // ── Factor Breakdown ─────────────────────────────
                        MinimalFactorBreakdown(factors: eval.factors)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}


// MARK: - Score Row

private struct MinimalScoreRow: View {
    let score: Double
    let risk: AHPRiskLevel
    let decision: AHPDecisionFlag

    @State private var appeared = false

    private var scoreColor: Color {
        if score >= 75 { return OfficerTheme.iconGreen }
        if score >= 55 { return OfficerTheme.iconAmber }
        return OfficerTheme.iconRed
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {

            // Score number
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(Int(appeared ? score : 0))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.8), value: appeared)
                    Text("/ 100")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(OfficerTheme.textSecondary)
                }
                Text("Loan Health Score")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(OfficerTheme.textSecondary)
            }

            Spacer()

            // Risk + Decision pills
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: risk.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(risk.rawValue)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(risk.color)

                HStack(spacing: 4) {
                    Circle()
                        .fill(decision.color)
                        .frame(width: 6, height: 6)
                    Text(decision.rawValue)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(OfficerTheme.textSecondary)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
        }
    }
}


// MARK: - Violations Section

private struct MinimalViolationsSection: View {
    let violations: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Hard Rule Violations", systemImage: "exclamationmark.octagon.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OfficerTheme.iconRed)

            ForEach(violations, id: \.self) { violation in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(OfficerTheme.iconRed)
                        .padding(.top, 1)
                    Text(violation)
                        .font(.system(size: 13))
                        .foregroundStyle(OfficerTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OfficerTheme.iconRed.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}


// MARK: - Remarks Section

private struct MinimalRemarksSection: View {
    let remarks: [AHPRemark]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Remarks")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OfficerTheme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.3)

            VStack(spacing: 8) {
                ForEach(remarks) { remark in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: remark.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(remark.sentiment.color)
                            .frame(width: 16)
                            .padding(.top, 2)

                        Text(remark.text)
                            .font(.system(size: 13))
                            .foregroundStyle(OfficerTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}


// MARK: - Factor Breakdown

private struct MinimalFactorBreakdown: View {
    let factors: [AHPFactor]
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Risk Factors")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OfficerTheme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.3)

            VStack(spacing: 10) {
                ForEach(factors) { factor in
                    MinimalFactorRow(factor: factor, animated: appeared)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                appeared = true
            }
        }
    }
}

private struct MinimalFactorRow: View {
    let factor: AHPFactor
    let animated: Bool

    private var barColor: Color {
        if factor.score >= 0.8 { return OfficerTheme.iconGreen }
        if factor.score >= 0.5 { return OfficerTheme.iconAmber }
        return OfficerTheme.iconRed
    }

    var body: some View {
        HStack(spacing: 10) {
            // Name + bar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text(factor.name)
                        .font(.system(size: 12))
                        .foregroundStyle(OfficerTheme.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f", factor.score * 100))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(barColor)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(OfficerTheme.filterBackground)
                            .frame(height: 4)
                        Capsule()
                            .fill(barColor)
                            .frame(width: proxy.size.width * (animated ? factor.score : 0), height: 4)
                            .animation(.easeOut(duration: 0.5), value: animated)
                    }
                }
                .frame(height: 4)
            }
        }
    }
}
