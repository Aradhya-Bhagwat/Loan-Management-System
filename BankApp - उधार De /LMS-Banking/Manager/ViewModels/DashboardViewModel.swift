import Foundation

@Observable
class DashboardViewModel {
    var kpis: [KPI] = []
    var loans: [Loan] = []
    
    var loanDistribution: [LoanDistribution] = []
    var monthlyDisbursements: [MonthlyDisbursement] = []
    var defaultTrends: [DefaultTrend] = []
    var sectorPerformance: [SectorPerformance] = []

    var searchText: String = ""
    var riskFilter: RiskLevel? = nil
    var statusFilter: LoanStatus? = nil
    var startDate: Date? = nil
    var endDate: Date? = nil
    var selectedLoan: Loan? = nil
    var branch: String? = nil

    var filteredLoans: [Loan] {
        loans.filter { loan in
            let matchRisk = riskFilter == nil || loan.risk == riskFilter
            let matchStatus = statusFilter == nil || loan.status == statusFilter
            let matchSearch = searchText.isEmpty || loan.borrowerName.localizedCaseInsensitiveContains(searchText)
            let matchDate: Bool = {
                guard let start = startDate, let end = endDate, let date = loan.createdAt else { return true }
                let cal = Calendar.current
                let startOfDay = cal.startOfDay(for: start)
                let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
                return date >= startOfDay && date <= endOfDay
            }()
            return matchRisk && matchStatus && matchSearch && matchDate
        }
    }

    var isLoading = false

    init() {
        loadData()
    }

    func loadData() {
        isLoading = true
        Task {
            do {
                let b = branch
                let k = try await DatabaseService.shared.fetchKPIs(branch: b)
                print("✅ KPIs: \(k.count)")
                let l = try await DatabaseService.shared.fetchLoans(branch: b)
                print("✅ Loans: \(l.count)")
                
                let ld = try await DatabaseService.shared.fetchLoanDistribution(branch: b)
                print("✅ LoanDistribution: \(ld.count) — \(ld)")
                let md = try await DatabaseService.shared.fetchMonthlyDisbursements(branch: b)
                print("✅ MonthlyDisbursements: \(md.count) — \(md)")
                let dt = try await DatabaseService.shared.fetchDefaultTrends(branch: b)
                print("✅ DefaultTrends: \(dt.count)")
                let sp = try await DatabaseService.shared.fetchSectorPerformance(branch: b)
                print("✅ SectorPerformance: \(sp.count) — \(sp)")
                
                await MainActor.run {
                    // Manager-specific: replace "Active Loans" with "Audit Compliance"
                    // so the card navigates to AuditComplianceView. Admin is unaffected.
                    self.kpis = k.map { kpi in
                        guard kpi.title == "Active Loans" else { return kpi }
                        return KPI(
                            title: "Audit Compliance",
                            value: "\(kpi.value) Active Loans",
                            change: kpi.change,
                            iconName: "shield.checkered",
                            accent: kpi.accent
                        )
                    }
                    self.loans = l
                    
                    self.loanDistribution = ld
                    self.monthlyDisbursements = md
                    self.defaultTrends = dt
                    self.sectorPerformance = sp
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading dashboard data: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    func refreshKPIs() async {
        if let k = try? await DatabaseService.shared.fetchKPIs(branch: branch) {
            await MainActor.run {
                // Manager-specific: keep "Audit Compliance" label in sync on refresh
                self.kpis = k.map { kpi in
                    guard kpi.title == "Active Loans" else { return kpi }
                    return KPI(
                        title: "Audit Compliance",
                        value: "\(kpi.value) Active Loans",
                        change: kpi.change,
                        iconName: "shield.checkered",
                        accent: kpi.accent
                    )
                }
            }
        }
    }

    func refreshLoans() async {
        if let l = try? await DatabaseService.shared.fetchLoans(branch: branch) {
            await MainActor.run { self.loans = l }
        }
    }

    func approveLoan(_ loan: Loan) async {
        do {
            try await DatabaseService.shared.updateLoanStatus(id: loan.id, status: .approved)
            await DatabaseService.shared.logAudit(
                title: "Loan Approved: \(loan.borrowerName)",
                actor: "Manager",
                category: "Loan Decision",
                status: "Completed",
                icon: "checkmark.shield.fill",
                color: "green",
                branch: branch
            )
            await refreshLoans()
        } catch {
            print("Error approving loan: \(error)")
        }
    }

    func rejectLoan(_ loan: Loan) async {
        do {
            try await DatabaseService.shared.updateLoanStatus(id: loan.id, status: .rejected)
            await DatabaseService.shared.logAudit(
                title: "Loan Rejected: \(loan.borrowerName)",
                actor: "Manager",
                category: "Loan Decision",
                status: "Rejected",
                icon: "xmark.shield.fill",
                color: "red",
                branch: branch
            )
            await refreshLoans()
        } catch {
            print("Error rejecting loan: \(error)")
        }
    }
    
    func returnLoan(_ loan: Loan, comment: String) async {
        do {
            try await DatabaseService.shared.updateLoanStatus(id: loan.id, status: .returnedForCorrection, comment: comment)
            await DatabaseService.shared.logAudit(
                title: "Loan Returned for Correction: \(loan.borrowerName)",
                actor: "Manager",
                category: "Loan Decision",
                status: "Pending",
                icon: "arrow.uturn.backward.fill",
                color: "orange",
                branch: branch
            )
            await refreshLoans()
        } catch {
            print("Error returning loan: \(error)")
        }
    }

    func startLiveRefresh() {
        DatabaseService.shared.startLiveRefresh { [weak self] in
            Task { @MainActor in
                self?.loadData()
            }
        }
    }

    func stopLiveRefresh() {
        DatabaseService.shared.stopLiveRefresh()
    }
}
