

import AppIntents
import Foundation

struct CheckOutstandingBalanceIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Outstanding Loan Balance"
    static let description = IntentDescription("Tells you the current outstanding principal balance on your active loan.")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Loan", requestValueDialog: "Which loan's balance would you like to check?")
    var loan: LoanEntity?

    func perform() async throws -> some ProvidesDialog {
        print("🎙️ [Siri] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎙️ [Siri] CheckOutstandingBalanceIntent.perform() triggered!")
        print("🎙️ [Siri] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        _ = try await LMSAuthenticationManager.shared.requireAuthenticatedUserId()

        print("📡 [Siri Balance] Fetching active loans...")
        let activeLoans  = try await SupabaseManager.shared.fetchActiveLoans()
        let applications = try await SupabaseManager.shared.fetchMyApplications()
        print("📡 [Siri Balance] Found \(activeLoans.count) active loan(s).")

        guard !activeLoans.isEmpty else {
            print("⚠️ [Siri Balance] No active loans found.")
            return .result(dialog: "You don't have any active loans in CredFlow Go.")
        }

        let appMap = Dictionary(uniqueKeysWithValues: applications.compactMap { app -> (UUID, LoanApplication)? in
            guard let id = app.id else { return nil }; return (id, app)
        })

        let targetLoan: ActiveLoan
        if activeLoans.count == 1 {
            targetLoan = activeLoans[0]
            print("✅ [Siri Balance] Single loan auto-selected.")
        } else if let preselected = loan,
                  let found = activeLoans.first(where: { $0.id == preselected.id }) {
            targetLoan = found
            print("✅ [Siri Balance] Pre-selected loan used.")
        } else {
            print("🔀 [Siri Balance] Multiple loans — showing picker...")
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
                dialog: "Which loan's balance do you want?"
            )
            guard let chosen = loan,
                  let found = activeLoans.first(where: { $0.id == chosen.id }) else {
                print("⚠️ [Siri Balance] No loan selected by user.")
                return .result(dialog: "No loan was selected.")
            }
            targetLoan = found
            print("✅ [Siri Balance] User selected: \(targetLoan.id.uuidString.prefix(8))")
        }

        let purpose = appMap[targetLoan.applicationId]?.purpose ?? "your loan"
        let balance = targetLoan.outstandingBalance
        print("💰 [Siri Balance] Outstanding balance for \(purpose): ₹\(Int(balance))")

        if balance <= 0 {
            return .result(dialog: "Congratulations! Your \(purpose) has been fully repaid.")
        }

        let formatted = formatCurrency(balance)
        print("✅ [Siri Balance] Responding with balance: \(formatted)")
        return .result(dialog: "Your current outstanding balance for your \(purpose) is \(formatted).")
    }

    private func formatCurrency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencySymbol = "₹"
        f.maximumFractionDigits = 0; f.locale = Locale(identifier: "en_IN")
        return f.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }
}
