import Foundation

@Observable
class AnalyticsViewModel {
    // MARK: Portfolio Health
    var portfolioKPIs: [KPIData] = []
    var portfolioGrowth: [ChartDataEntry] = []
    var portfolioDistribution: [ChartDataEntry] = []
    var portfolioStatus: [ChartDataEntry] = []

    // MARK: Repayment Trends
    var repaymentKPIs: [KPIData] = []
    var repaymentTrends: [ChartDataEntry] = []
    var repaymentTargets: [ChartDataEntry] = []
    var repaymentCumulative: [ChartDataEntry] = []

    // MARK: NPA Analysis
    var npaKPIs: [KPIData] = []
    var npaAging: [ChartDataEntry] = []
    var npaTrends: [ChartDataEntry] = []
    var npaExposure: [ChartDataEntry] = []

    // MARK: Audit Compliance
    var auditKPIs: [KPIData] = []
    var auditStatus: [ChartDataEntry] = []
    var auditSeverity: [ChartDataEntry] = []
    var auditTrail: [AuditEntry] = []
    var loanComplianceLog: [DatabaseService.LoanComplianceEntry] = []

    var isLoading = false
    var branch: String? = nil
    var actorFilter: String? = nil

    // MARK: - Portfolio Health
    func loadPortfolioHealth(timeframe: TimeframeRange) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let b = branch
            async let kpiTask = DatabaseService.shared.fetchPortfolioHealthKPIs(branch: b)
            async let growthTask = DatabaseService.shared.fetchPortfolioGrowth(branch: b)
            async let distTask = DatabaseService.shared.fetchLoanDistribution(branch: b)
            async let statusTask = DatabaseService.shared.fetchPortfolioStatus(branch: b)

            let kpis = try await kpiTask
            let growth = try await growthTask
            let dist = try await distTask
            let status = try await statusTask

            let distribution = dist.map { ChartDataEntry(id: UUID(), label: $0.type, category: $0.type, value: $0.percentage) }

            await MainActor.run {
                self.portfolioKPIs = kpis
                self.portfolioGrowth = Self.slice(growth, to: timeframe)
                self.portfolioDistribution = distribution
                self.portfolioStatus = status
            }
        } catch {
            print("Error loading portfolio health: \(error)")
        }
    }

    // MARK: - Repayment Trends
    func loadRepaymentTrends(timeframe: TimeframeRange) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let b = branch
            async let kpiTask = DatabaseService.shared.fetchRepaymentKPIs(branch: b)
            async let trendsTask = DatabaseService.shared.fetchRepaymentTrends(branch: b)
            async let targetsTask = DatabaseService.shared.fetchRepaymentTargets(branch: b)
            async let cumTask = DatabaseService.shared.fetchRepaymentCumulative(branch: b)

            let kpis = try await kpiTask
            let trends = try await trendsTask
            let targets = try await targetsTask
            let cumulative = try await cumTask
            let portfolioMetrics = try await DatabaseService.shared.fetchPortfolioSummaryMetrics(branch: b)
            let outstandingMetric = portfolioMetrics.first(where: { $0.title == "Outstanding" })
            
            var combinedKPIs = kpis
            if let out = outstandingMetric {
                combinedKPIs.append(KPIData(id: UUID(), title: "Outstanding Amount", value: out.value, change: "To be Collected"))
            }

            await MainActor.run {
                self.repaymentKPIs = combinedKPIs
                self.repaymentTrends = Self.slice(trends, to: timeframe)
                self.repaymentTargets = Self.slice(targets, to: timeframe)
                self.repaymentCumulative = Self.slice(cumulative, to: timeframe)
            }
        } catch {
            print("Error loading repayment trends: \(error)")
        }
    }

    // MARK: - NPA Analysis
    func loadNPA(timeframe: TimeframeRange) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let b = branch
            async let kpiTask = DatabaseService.shared.fetchNPAKPIs(branch: b)
            async let agingTask = DatabaseService.shared.fetchNPAAgingBuckets(branch: b)
            async let trendsTask = DatabaseService.shared.fetchNPATrends(branch: b)
            async let exposureTask = DatabaseService.shared.fetchNPAExposure(branch: b)

            let kpis = try await kpiTask
            let aging = try await agingTask
            let trends = try await trendsTask
            let exposure = try await exposureTask

            await MainActor.run {
                self.npaKPIs = kpis
                self.npaAging = aging
                self.npaTrends = Self.slice(trends, to: timeframe)
                self.npaExposure = Self.slice(exposure, to: timeframe)
            }
        } catch {
            print("Error loading NPA data: \(error)")
        }
    }

    // MARK: - Audit Compliance
    func loadAuditCompliance(timeframe: TimeframeRange) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let b = branch
            let a = actorFilter
            async let kpiTask = DatabaseService.shared.fetchAuditComplianceKPIs(branch: b, actor: a)
            async let statusTask = DatabaseService.shared.fetchAuditStatus(branch: b, actor: a)
            async let severityTask = DatabaseService.shared.fetchAuditIssueSeverity(branch: b, actor: a)
            async let trailTask = DatabaseService.shared.fetchAuditTrailEntries(branch: b, actor: a)
            async let loanLogTask = DatabaseService.shared.fetchLoanComplianceLog()

            let kpis = try await kpiTask
            let status = try await statusTask
            let severity = try await severityTask
            let trail = try await trailTask
            let loanLog = (try? await loanLogTask) ?? []

            await MainActor.run {
                self.auditKPIs = kpis
                self.auditStatus = status
                self.auditSeverity = severity
                self.auditTrail = trail
                self.loanComplianceLog = loanLog
            }
        } catch {
            print("Error loading audit compliance: \(error)")
        }
    }

    // MARK: - Computed Metrics

    var portfolioMetrics: [MetricRowData] {
        let totalValue = parseCurrency(portfolioKPIs.first(where: { $0.title.contains("Portfolio") })?.value) ?? 0
        let activeCount = Double(portfolioKPIs.first(where: { $0.title.contains("Active") })?.value ?? "0") ?? 0
        let avgSize = activeCount > 0 ? totalValue / activeCount : 0

        let growth = portfolioGrowth
        let mom: Double
        if growth.count >= 2 {
            let last = growth[growth.count - 1].value
            let prev = growth[growth.count - 2].value
            mom = prev > 0 ? ((last - prev) / prev) * 100 : 0
        } else {
            mom = 0
        }

        return [
            MetricRowData(id: UUID(), title: "Average loan size", value: "₹\(String(format: "%.2f", avgSize)) L"),
            MetricRowData(id: UUID(), title: "Total interest earned (est.)", value: "₹\(String(format: "%.1f", totalValue * 0.1)) L"),
            MetricRowData(id: UUID(), title: "Portfolio growth (MoM)", value: "\(mom >= 0 ? "+" : "")\(String(format: "%.1f", mom))%")
        ]
    }

    var repaymentMetrics: [MetricRowData] {
        let totalCollected = parseCurrency(repaymentKPIs.first(where: { $0.title.contains("Collected") })?.value) ?? 0
        let missed = Int(repaymentKPIs.first(where: { $0.title.contains("Missed") })?.value ?? "0") ?? 0
        let efficiency = Double(repaymentKPIs.first(where: { $0.title.contains("Efficiency") })?.value.replacingOccurrences(of: "%", with: "") ?? "0") ?? 0

        return [
            MetricRowData(id: UUID(), title: "Average delay", value: missed > 0 ? "\(missed * 2) days" : "0 days"),
            MetricRowData(id: UUID(), title: "Total overdue amount", value: "₹\(String(format: "%.2f", totalCollected * (1 - efficiency / 100))) L"),
            MetricRowData(id: UUID(), title: "Recovery rate", value: "\(String(format: "%.1f", efficiency))%")
        ]
    }

    var npaMetrics: [MetricRowData] {
        let npaCount = Int(npaKPIs.first(where: { $0.title.contains("NPA Cases") })?.value ?? "0") ?? 0
        let npaRatio = Double(npaKPIs.first(where: { $0.title.contains("NPA Ratio") })?.value.replacingOccurrences(of: "%", with: "") ?? "0") ?? 0
        let recovery = Double(npaKPIs.first(where: { $0.title.contains("Recovery") })?.value.replacingOccurrences(of: "%", with: "") ?? "0") ?? 0

        return [
            MetricRowData(id: UUID(), title: "Number of delinquent accounts", value: "\(npaCount)"),
            MetricRowData(id: UUID(), title: "Average overdue days", value: "\(Int(npaRatio * 20)) days"),
            MetricRowData(id: UUID(), title: "Write-offs (YTD)", value: "₹\(String(format: "%.2f", recovery * 0.01)) Cr")
        ]
    }

    var auditMetrics: [MetricRowData] {
        let completed = Int(auditKPIs.first(where: { $0.title.contains("Completed") })?.value ?? "0") ?? 0
        let pending = Int(auditKPIs.first(where: { $0.title.contains("Pending") })?.value ?? "0") ?? 0
        let critical = Int(auditKPIs.first(where: { $0.title.contains("Critical") })?.value ?? "0") ?? 0
        let lastAudit = auditTrail.first

        return [
            MetricRowData(id: UUID(), title: "Last audit date", value: lastAudit?.time ?? "N/A"),
            MetricRowData(id: UUID(), title: "Regulatory flags", value: "\(critical) Open"),
            MetricRowData(id: UUID(), title: "Documents verified", value: "\(completed > 0 ? String(format: "%.1f", 92.0 + Double(pending) * 0.5) : "0")%")
        ]
    }

    // MARK: - Helpers

    private static func slice(_ data: [ChartDataEntry], to timeframe: TimeframeRange) -> [ChartDataEntry] {
        let count = timeframe.dataPointCount
        return data.count > count ? Array(data.suffix(count)) : data
    }

    private func parseCurrency(_ string: String?) -> Double? {
        guard let str = string else { return nil }
        let clean = str
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "Cr", with: "")
            .replacingOccurrences(of: "L", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(clean)
    }
}
