import Foundation
internal import PostgREST
import Supabase

@Observable
class LoansViewModel {
    var loans: [Loan] = []
    var officers: [LoanOfficer] = []
    var overdueLoans: [OverdueLoan] = []
    var portfolioSummaryCards: [DashboardMetric] = []
    var riskSummaryItems: [DashboardMetric] = []
    var loanDistribution: [LoanDistribution] = []
    var monthlyDisbursements: [MonthlyDisbursement] = []
    var sectorPerformance: [SectorPerformance] = []
    var loanProducts: [LoanProduct] {
        DatabaseService.shared.loanProducts
    }
    var competitiveRates: [CompetitiveRate] {
        DatabaseService.shared.competitiveRates
    }
    var searchText: String = ""
    var riskFilter: RiskLevel? = nil
    var statusFilter: LoanStatus? = nil
    var startDate: Date? = nil
    var endDate: Date? = nil
    var selectedLoan: Loan? = nil
    var showAlert: Bool = false
    var alertMessage: String = ""
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
                let l = try await DatabaseService.shared.fetchLoans(branch: b)
                let o = try await DatabaseService.shared.fetchLoanOfficers(branch: b)
                let ov = try await DatabaseService.shared.fetchOverdueLoans(branch: b)
                let ps = try await DatabaseService.shared.fetchPortfolioSummaryMetrics(branch: b)
                let rs = try await DatabaseService.shared.fetchRiskSummaryMetrics(branch: b)
                let ld = try await DatabaseService.shared.fetchLoanDistribution(branch: b)
                let md = try await DatabaseService.shared.fetchMonthlyDisbursements(branch: b)
                let sp = try await DatabaseService.shared.fetchSectorPerformance(branch: b)
                
                await DatabaseService.shared.fetchLoanProducts()
                await DatabaseService.shared.fetchCompetitiveRates()

                await MainActor.run {
                    self.loans = l
                    self.officers = o
                    self.overdueLoans = ov
                    self.portfolioSummaryCards = ps
                    self.riskSummaryItems = rs
                    self.loanDistribution = ld
                    self.monthlyDisbursements = md
                    self.sectorPerformance = sp
                    self.isLoading = false
                }
            } catch {
                print("Error loading loans data: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    func approveLoan(_ loan: Loan) async {
        // Validate against loan product guidelines
        if let product = loanProducts.first(where: { loan.purpose.localizedCaseInsensitiveContains($0.name) || $0.name.localizedCaseInsensitiveContains(loan.purpose) }) {
            
            let minAmount = product.managerMinAmount ?? product.minAmount
            if loan.amountValue < minAmount {
                await MainActor.run {
                    self.alertMessage = "Cannot approve: Amount (₹\(Int(loan.amountValue))) is below the minimum allowed (₹\(Int(minAmount))) for \(product.name)."
                    self.showAlert = true
                }
                return
            }
            
            let maxAmount = product.managerMaxAmount ?? product.maxAmount
            if loan.amountValue > maxAmount {
                await MainActor.run {
                    self.alertMessage = "Cannot approve: Amount (₹\(Int(loan.amountValue))) exceeds the maximum allowed (₹\(Int(maxAmount))) for \(product.name)."
                    self.showAlert = true
                }
                return
            }
            
            let tenureString = loan.tenure.lowercased().replacingOccurrences(of: "months", with: "").replacingOccurrences(of: "month", with: "").trimmingCharacters(in: .whitespaces)
            if let tenureMonths = Int(tenureString) {
                let minTenure = product.managerMinTenureMonths ?? product.minTenureMonths
                if tenureMonths < minTenure {
                    await MainActor.run {
                        self.alertMessage = "Cannot approve: Tenure (\(tenureMonths) months) is below the minimum allowed (\(minTenure) months) for \(product.name)."
                        self.showAlert = true
                    }
                    return
                }
                
                let maxTenure = product.managerMaxTenureMonths ?? product.maxTenureMonths
                if tenureMonths > maxTenure {
                    await MainActor.run {
                        self.alertMessage = "Cannot approve: Tenure (\(tenureMonths) months) exceeds the maximum allowed (\(maxTenure) months) for \(product.name)."
                        self.showAlert = true
                    }
                    return
                }
            }
        }
        
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

    func assignRecovery(_ overdueLoan: OverdueLoan, officerId: String) async {
        do {
            try await DatabaseService.shared.assignRecoveryOfficer(loanId: overdueLoan.id, officerId: officerId)
            await DatabaseService.shared.logAudit(
                title: "Recovery Officer Assigned: \(overdueLoan.borrowerName)",
                actor: "Manager",
                category: "Recovery",
                status: "Processed",
                icon: "person.badge.plus",
                color: "blue",
                branch: branch
            )
            loadData()
        } catch {
            print("Error assigning recovery officer: \(error)")
        }
    }

    func refreshLoans() async {
        if let l = try? await DatabaseService.shared.fetchLoans(branch: branch) {
            await MainActor.run { self.loans = l }
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
            loadData()
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
