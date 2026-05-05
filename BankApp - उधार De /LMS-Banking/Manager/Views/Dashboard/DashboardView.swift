import SwiftUI

struct DashboardView: View {
    @Bindable var controller: DashboardViewModel
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var isShowingAllApplications = false
    
    private var totalPortfolioValue: Double {
        guard let kpi = controller.kpis.first(where: { $0.title.contains("Portfolio") }) else { return 0 }
        let clean = kpi.value
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if clean.hasSuffix("Cr") {
            return (Double(clean.dropLast(2)) ?? 0) * 10_000_000
        } else if clean.hasSuffix("L") {
            return (Double(clean.dropLast(1)) ?? 0) * 100_000
        }
        return Double(clean) ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                KpiCardsView(kpis: controller.kpis)

                LoanTableView(
                    loans: controller.loans,
                    searchText: $controller.searchText,
                    statusFilter: $controller.statusFilter,
                    selectedLoan: $controller.selectedLoan,
                    mode: .overview,
                    isShowingAll: $isShowingAllApplications,
                    startDate: $controller.startDate,
                    endDate: $controller.endDate,
                    onApprove: { loan in Task { await controller.approveLoan(loan) } },
                    onReject: { loan in Task { await controller.rejectLoan(loan) } },
                    onReturn: { loan, comment in Task { await controller.returnLoan(loan, comment: comment) } }
                )

                ChartsView(
                    distribution: controller.loanDistribution,
                    disbursements: controller.monthlyDisbursements,
                    trends: controller.defaultTrends,
                    sector: controller.sectorPerformance,
                    totalPortfolioValue: totalPortfolioValue
                )
            }
            .padding(.horizontal, sizeClass == .regular ? 32 : 16)
            .padding(.vertical, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Overview")
        .refreshable {
            controller.loadData()
        }
        .navigationDestination(isPresented: $isShowingAllApplications) {
            AllApplicationsView(controller: controller)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(controller: DashboardViewModel())
    }
}
