

import AppIntents
import Foundation

struct CheckNextEMIIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Next EMI Payment"
    static let description = IntentDescription("Tells you the amount and due date of your next upcoming EMI payment.")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Loan", requestValueDialog: "Which loan would you like to check?")
    var loan: LoanEntity?

    func perform() async throws -> some ProvidesDialog {
        print("🎙️ [Siri] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎙️ [Siri] CheckNextEMIIntent.perform() triggered!")
        print("🎙️ [Siri] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        _ = try await LMSAuthenticationManager.shared.requireAuthenticatedUserId()

        print("📡 [Siri EMI] Fetching upcoming EMIs from Supabase...")
        let allUpcomingEMIs = try await SupabaseManager.shared.fetchUpcomingEMIs()
        print("📡 [Siri EMI] Fetched \(allUpcomingEMIs.count) upcoming EMI(s).")

        print("📡 [Siri EMI] Fetching active loans...")
        let activeLoans = try await SupabaseManager.shared.fetchActiveLoans()
        print("📡 [Siri EMI] Found \(activeLoans.count) active loan(s).")

        let applications = try await SupabaseManager.shared.fetchMyApplications()

        guard !activeLoans.isEmpty else {
            print("⚠️ [Siri EMI] No active loans found — returning early.")
            return .result(dialog: "You don't have any active loans in CredFlow Go.")
        }

        let targetLoanId: UUID
        if activeLoans.count == 1 {
            targetLoanId = activeLoans[0].id
            print("✅ [Siri EMI] Single loan auto-selected: \(targetLoanId.uuidString.prefix(8))")
        } else if let preselected = loan {
            targetLoanId = preselected.id
            print("✅ [Siri EMI] Pre-selected loan used: \(targetLoanId.uuidString.prefix(8))")
        } else {
            print("🔀 [Siri EMI] Multiple loans — showing disambiguation picker...")
            let appMap = Dictionary(uniqueKeysWithValues: applications.compactMap { app -> (UUID, LoanApplication)? in
                guard let id = app.id else { return nil }; return (id, app)
            })
            let entities = activeLoans.map { loanObj -> LoanEntity in
                let purpose = appMap[loanObj.applicationId]?.purpose ?? "Active Loan"
                return LoanEntity(
                    id: loanObj.id,
                    displayLabel: "\(purpose) – ₹\(Int(loanObj.outstandingBalance))",
                    outstandingBalance: loanObj.outstandingBalance,
                    purpose: purpose
                )
            }
            loan = try await $loan.requestDisambiguation(
                among: entities,
                dialog: "You have \(activeLoans.count) active loans. Which one?"
            )
            guard let chosen = loan else {
                print("⚠️ [Siri EMI] User did not select a loan.")
                return .result(dialog: "No loan was selected.")
            }
            targetLoanId = chosen.id
            print("✅ [Siri EMI] User selected loan: \(targetLoanId.uuidString.prefix(8))")
        }

        let loanEMIs = allUpcomingEMIs
            .filter { $0.loanId == targetLoanId }
            .sorted {
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                return (f.date(from: $0.dueDate) ?? .distantFuture) < (f.date(from: $1.dueDate) ?? .distantFuture)
            }
        print("📅 [Siri EMI] EMIs for selected loan: \(loanEMIs.count)")

        guard let next = loanEMIs.first else {
            print("ℹ️ [Siri EMI] No upcoming EMIs for this loan.")
            return .result(dialog: "You have no upcoming EMIs right now — you're all caught up!")
        }

        let appMap2 = Dictionary(uniqueKeysWithValues: applications.compactMap { app -> (UUID, LoanApplication)? in
            guard let id = app.id else { return nil }; return (id, app)
        })
        let loanObj  = activeLoans.first(where: { $0.id == targetLoanId })
        let purpose  = loanObj.flatMap { appMap2[$0.applicationId]?.purpose } ?? "your loan"
        let amount   = formatCurrency(next.amount)
        let date     = formatDate(next.dueDate)

        print("✅ [Siri EMI] Responding: \(purpose) — \(amount) due \(date)")
        return .result(dialog: "Your next \(purpose) payment of \(amount) is due on \(date).")
    }

    private func formatCurrency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencySymbol = "₹"
        f.maximumFractionDigits = 0; f.locale = Locale(identifier: "en_IN")
        return f.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }

    private func formatDate(_ s: String) -> String {
        let i = DateFormatter(); i.dateFormat = "yyyy-MM-dd"
        guard let d = i.date(from: s) else { return s }
        let o = DateFormatter(); o.dateStyle = .long; o.timeStyle = .none
        return o.string(from: d)
    }
}
