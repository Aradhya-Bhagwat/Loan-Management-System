

import AppIntents
import Foundation

// MARK: - LoanEntity

struct LoanEntity: AppEntity {

    let id: UUID

    let displayLabel: String

    let outstandingBalance: Double

    let purpose: String

    // MARK: - AppEntity conformance

    static var defaultQuery = LoanEntityQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Active Loan")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayLabel)")
    }
}

// MARK: - LoanEntity Query

struct LoanEntityQuery: EntityQuery {

    func entities(for identifiers: [UUID]) async throws -> [LoanEntity] {

        let all = try await fetchAllLoanEntities()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LoanEntity] {
        return try await fetchAllLoanEntities()
    }

    // MARK: - Private helpers

    private func fetchAllLoanEntities() async throws -> [LoanEntity] {

        let activeLoans = try await SupabaseManager.shared.fetchActiveLoans()
        let applications = try await SupabaseManager.shared.fetchMyApplications()

        let appMap = Dictionary(uniqueKeysWithValues: applications.compactMap { app -> (UUID, LoanApplication)? in
            guard let id = app.id else { return nil }
            return (id, app)
        })

        return activeLoans.map { loan in
            let purpose = appMap[loan.applicationId]?.purpose ?? "Active Loan"
            let formatted = "₹\(Int(loan.outstandingBalance).formatted())"
            return LoanEntity(
                id: loan.id,
                displayLabel: "\(purpose) – \(formatted)",
                outstandingBalance: loan.outstandingBalance,
                purpose: purpose
            )
        }
    }
}
