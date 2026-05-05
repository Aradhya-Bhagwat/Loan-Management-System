

import AppIntents
import Foundation

struct CheckLoanStatusIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Loan Application Status"
    static let description = IntentDescription("Tells you the current status of your loan application.")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Application", requestValueDialog: "Which loan application do you want to check?")
    var application: LoanApplicationEntity?

    func perform() async throws -> some ProvidesDialog {
        print("🎙️ [Siri] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎙️ [Siri] CheckLoanStatusIntent.perform() triggered!")
        print("🎙️ [Siri] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        _ = try await LMSAuthenticationManager.shared.requireAuthenticatedUserId()

        print("📡 [Siri Status] Fetching loan applications...")
        let applications = try await SupabaseManager.shared.fetchMyApplications()
        print("📡 [Siri Status] Found \(applications.count) application(s).")

        guard !applications.isEmpty else {
            print("⚠️ [Siri Status] No applications found.")
            return .result(dialog: "You haven't submitted any loan applications in CredFlow Go yet.")
        }

        let targetApp: LoanApplication
        if applications.count == 1 {
            targetApp = applications[0]
            print("✅ [Siri Status] Single application auto-selected: \(targetApp.purpose)")
        } else if let preselected = application,
                  let found = applications.first(where: { $0.id == preselected.id }) {
            targetApp = found
            print("✅ [Siri Status] Pre-selected application: \(targetApp.purpose)")
        } else {
            print("🔀 [Siri Status] Multiple applications — showing picker...")
            let entities = applications.compactMap { app -> LoanApplicationEntity? in
                guard let id = app.id else { return nil }
                return LoanApplicationEntity(
                    id: id, purpose: app.purpose, loanAmount: app.loanAmount,
                    status: app.status.rawValue,
                    statusPhrase: statusToPhrase(app.status.rawValue)
                )
            }
            application = try await $application.requestDisambiguation(
                among: entities,
                dialog: "You have \(applications.count) applications. Which one?"
            )
            guard let chosen = application,
                  let found = applications.first(where: { $0.id == chosen.id }) else {
                print("⚠️ [Siri Status] No application selected.")
                return .result(dialog: "No application was selected.")
            }
            targetApp = found
            print("✅ [Siri Status] User selected: \(targetApp.purpose)")
        }

        let phrase  = statusToPhrase(targetApp.status.rawValue)
        let amount  = formatCurrency(targetApp.loanAmount)
        print("✅ [Siri Status] Responding — \(targetApp.purpose), status: \(targetApp.status.rawValue)")
        return .result(dialog: "Your \(targetApp.purpose) application for \(amount) is currently \(phrase).")
    }

    private func statusToPhrase(_ raw: String) -> String {
        switch raw {
        case "submitted":    return "submitted and awaiting review"
        case "under_review": return "under review by our credit team"
        case "recommended":  return "recommended for approval"
        case "approved":     return "approved — disbursement in progress"
        case "disbursed":    return "disbursed — funds have been transferred"
        case "rejected":     return "rejected — please check the app for details"
        default:             return raw.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencySymbol = "₹"
        f.maximumFractionDigits = 0; f.locale = Locale(identifier: "en_IN")
        return f.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }
}

// MARK: - Loan Application Entity

struct LoanApplicationEntity: AppEntity {
    let id: UUID
    let purpose: String
    let loanAmount: Double
    let status: String
    let statusPhrase: String

    static var defaultQuery = LoanApplicationEntityQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Loan Application")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(purpose)", subtitle: "\(statusPhrase)")
    }
}

struct LoanApplicationEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [LoanApplicationEntity] {
        let apps = try await SupabaseManager.shared.fetchMyApplications()
        return apps.compactMap { app -> LoanApplicationEntity? in
            guard let id = app.id, identifiers.contains(id) else { return nil }
            return LoanApplicationEntity(
                id: id, purpose: app.purpose, loanAmount: app.loanAmount,
                status: app.status.rawValue,
                statusPhrase: app.status.rawValue.replacingOccurrences(of: "_", with: " ")
            )
        }
    }

    func suggestedEntities() async throws -> [LoanApplicationEntity] {
        let apps = try await SupabaseManager.shared.fetchMyApplications()
        return apps.compactMap { app -> LoanApplicationEntity? in
            guard let id = app.id else { return nil }
            return LoanApplicationEntity(
                id: id, purpose: app.purpose, loanAmount: app.loanAmount,
                status: app.status.rawValue,
                statusPhrase: app.status.rawValue.replacingOccurrences(of: "_", with: " ")
            )
        }
    }
}
