import Foundation
import SwiftUI
import Observation
import Supabase

@Observable
final class HomeViewModel {
    var totalLoanAmount: Double = 0
    var outstandingBalance: Double = 0
    var repaidAmount: Double = 0
    var tenureLeft: Int = 0
    var upcomingEMIs: [EMISchedule] = []
    var alerts: [FinancialInsight] = []
    var creditScore: Int = 0
    var recentActivity: [AuditLog] = []
    var isLoading = false
    var isNPA = false
    var hasActiveLoans = false
    var unreadNotificationCount = 0

    func refreshData() async {
        isLoading = true
        defer { isLoading = false }

        do {

            try? await SupabaseManager.shared.checkAndUpdateNPAStatus()

            if let profile = try await SupabaseManager.shared.fetchCurrentBorrower() {
                await MainActor.run {
                    self.creditScore = profile.creditScore
                }
            }

            let apps = try await SupabaseManager.shared.fetchMyApplications()

            let approvedApps = apps.filter { $0.status == .approved }
            self.totalLoanAmount = approvedApps.reduce(0) { $0 + $1.loanAmount }

            let activeLoans = try await SupabaseManager.shared.fetchActiveLoans()
            self.hasActiveLoans = !activeLoans.isEmpty
            print("🏦 HomeViewModel: \(activeLoans.count) active loans, \(apps.count) applications")

            self.isNPA = activeLoans.contains(where: { $0.isNpa })

            if activeLoans.isEmpty {
                self.outstandingBalance = approvedApps.reduce(0) { $0 + $1.loanAmount }
            } else {
                self.outstandingBalance = activeLoans.reduce(0) { $0 + $1.outstandingBalance }
            }

            self.repaidAmount = max(0, self.totalLoanAmount - self.outstandingBalance)

            let fullSchedule = try await SupabaseManager.shared.fetchEMISchedule()
            print("📅 HomeViewModel: \(fullSchedule.count) EMI rows fetched")

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            let now = Date()
            let calendar = Calendar.current

            guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: now),
                  let nextMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonthDate)),
                  let nextMonthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: nextMonthStart) else {
                return
            }

            let filteredEMIs = fullSchedule.filter { emi in
                guard let dueDate = formatter.date(from: emi.dueDate) else { return false }

                let isCurrentMonth = dueDate >= currentMonthStart && dueDate < nextMonthStart
                let isNextMonth = dueDate >= nextMonthStart && dueDate <= nextMonthEnd
                let isOverdue = emi.status.lowercased() != "paid" && dueDate < currentMonthStart

                return isCurrentMonth || isNextMonth || isOverdue
            }

            self.upcomingEMIs = filteredEMIs.sorted {
                let d1 = formatter.date(from: $0.dueDate) ?? Date.distantFuture
                let d2 = formatter.date(from: $1.dueDate) ?? Date.distantFuture
                return d1 < d2
            }

            self.tenureLeft = fullSchedule.filter { $0.status.lowercased() != "paid" }.count

            self.alerts = try await SupabaseManager.shared.fetchPredictiveAlerts()

            self.recentActivity = try await SupabaseManager.shared.fetchRecentActivity()

            self.unreadNotificationCount = try await SupabaseManager.shared.fetchUnreadNotificationCount()

        } catch {
            print("Error refreshing Home data: \(error)")
        }
    }
}
