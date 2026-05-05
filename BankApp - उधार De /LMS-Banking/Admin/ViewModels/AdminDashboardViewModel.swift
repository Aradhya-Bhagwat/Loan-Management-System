import SwiftUI
import Observation

@Observable
class AdminDashboardViewModel {
    var selectedTab: AdminTab = .overview
    var currentAdminName: String = "Authorized Admin"
    
    var selectedReportType: AdminReportType = .portfolioHealth
    var selectedRange: ReportRange = .monthly
    var selectedFormat: ReportFormat = .pdf
    var includeAuditTrail = true
    var includeBranchBreakdown = true
    var generatedReports: [GeneratedReport] = []
    var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var customEndDate: Date = Date()
    
    var selectedRole: UserRole = .officer
    var loanProducts: [LoanProduct] {
        DatabaseService.shared.loanProducts
    }
    
    var notificationSettings: [NotificationSetting] = []

    var notificationTemplates: [NotificationTemplate] {
        DatabaseService.shared.notificationTemplates
    }
    
    // GDPR Properties
    var privacySettings: PrivacySettings {
        DatabaseService.shared.privacySettings
    }
    
    var consentTemplates: [ConsentTemplate] {
        DatabaseService.shared.consentTemplates
    }
    
    var systemConfig: SystemConfig {
        DatabaseService.shared.systemConfig
    }
    
    var staffCount: Int = 0
    var roleDistribution: [RoleDistribution] = []
    
    var loanActivityEntries: [AuditEntry] {
        auditEntries.filter { $0.displayCategory.lowercased().contains("loan") || $0.displayCategory.lowercased().contains("application") }
    }
    
    var users: [UserItem] {
        let dbUsers = DatabaseService.shared.users
        return dbUsers.map { session in
            let initials = session.name.split(separator: " ")
                .compactMap { $0.first }
                .map { String($0) }
                .joined()

            return UserItem(
                id: session.id,
                name: session.name,
                initials: initials.isEmpty ? "U" : initials,
                role: session.role,
                status: session.status ?? .verified,
                email: session.email,
                phone: session.phone ?? "+91 00000 00000",
                joined: session.joinedAt.map {
                    "Joined \($0.formatted(date: .abbreviated, time: .omitted))"
                } ?? "Joined Jan 14, 2026",
                branch: session.branch ?? "Main"
            )
        }
    }
    
    var filteredUsers: [UserItem] {
        let all = users
        return all.filter { user in
            let matchRole = user.role == selectedRole
            let matchBranch = selectedUserBranch == "All" || user.branch == selectedUserBranch
            let matchSearch = searchText.isEmpty || 
                             user.name.localizedCaseInsensitiveContains(searchText) || 
                             user.email.localizedCaseInsensitiveContains(searchText) ||
                             user.branch.localizedCaseInsensitiveContains(searchText)
            return matchRole && matchBranch && matchSearch
        }
    }
    
    var userBranchOptions: [String] {
        let official = Branch.allCases.map(\.rawValue)
        let existing = users.map(\.branch).filter { !$0.isEmpty }
        return Array(Set(official + existing)).sorted()
    }

    var hasActiveUserFilters: Bool {
        selectedUserBranch != "All"
    }

    func clearUserFilters() {
        selectedUserBranch = "All"
    }

    var searchText: String = ""
    var selectedUserBranch: String = "All"
    var selectedBranch: String = "All"
    var selectedCategory: String = "All"
    var selectedStatus: String = "All"
    
    init() {
        loadReports()
        fetchKPIs()
        fetchUsers()
        fetchAuditTrail()
        fetchLoanProducts()
        fetchCompetitiveRates()

        fetchNotificationSettings()
        fetchNotificationTemplates()
        fetchPrivacySettings()
        fetchConsentTemplates()
        fetchSystemConfig()
    }
    
    func fetchCompetitiveRates() {
        Task {
            await DatabaseService.shared.fetchCompetitiveRates()
        }
    }
    
    // MARK: - System Settings

    func fetchSystemConfig() {
        Task {
            await DatabaseService.shared.fetchSystemConfig()
        }
    }
    
    func saveSystemConfig(_ config: SystemConfig) {
        Task {
            await DatabaseService.shared.saveSystemConfig(config)
            await DatabaseService.shared.logAudit(
                title: "System Configuration Updated",
                actor: "Admin",
                category: "System",
                status: "Success",
                icon: "gearshape.fill",
                color: "orange"
            )
            await DatabaseService.shared.fetchAuditTrail()
        }
    }
    
    // MARK: - GDPR

    func fetchPrivacySettings() {
        Task {
            await DatabaseService.shared.fetchPrivacySettings()
        }
    }
    
    func savePrivacySettings(_ settings: PrivacySettings) {
        Task {
            await DatabaseService.shared.savePrivacySettings(settings)
            await DatabaseService.shared.logAudit(
                title: "Privacy Settings Updated",
                actor: "Admin",
                category: "Compliance",
                status: "Success",
                icon: "shield.lefthalf.filled",
                color: "green"
            )
            await DatabaseService.shared.fetchAuditTrail()
        }
    }
    
    func fetchConsentTemplates() {
        Task {
            await DatabaseService.shared.fetchConsentTemplates()
        }
    }
    
    func saveConsentTemplate(_ template: ConsentTemplate) {
        Task {
            await DatabaseService.shared.saveConsentTemplate(template)
            await DatabaseService.shared.logAudit(
                title: "Consent Template Updated: \(template.title)",
                actor: "Admin",
                category: "Compliance",
                status: "Success",
                icon: "doc.text.shield",
                color: "blue"
            )
            await DatabaseService.shared.fetchAuditTrail()
        }
    }
    
    func exportUserDataDSAR(user: UserItem) {
        Task {
            let userData = """
            Data Subject Access Request (DSAR) Report
            -----------------------------------------
            User ID: \(user.id)
            Name: \(user.name)
            Email: \(user.email)
            Phone: \(user.phone)
            Role: \(user.role.rawValue)
            Joined: \(user.joined)
            
            Audit Logs for this user:
            \(auditEntries.filter { $0.displayActor == user.name }.map { "- \($0.displayTitle) (\($0.time))" }.joined(separator: "\n"))
            """
            
            let fileName = "DSAR_\(user.name.replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970)).txt"
            if let data = userData.data(using: .utf8) {
                print("Simulating DSAR export for \(user.name)")
                
                await DatabaseService.shared.logAudit(
                    title: "DSAR Exported: \(user.name)",
                    actor: "Admin",
                    category: "Compliance",
                    status: "Success",
                    icon: "square.and.arrow.up",
                    color: "orange"
                )
                await DatabaseService.shared.fetchAuditTrail()
            }
        }
    }

    func fetchLoanProducts() {
        Task {
            await DatabaseService.shared.fetchLoanProducts()
        }
    }

    func saveLoanProduct(_ product: LoanProduct) {
        Task {
            await DatabaseService.shared.saveLoanProduct(product)
            await DatabaseService.shared.logAudit(
                title: "Loan Product Updated: \(product.name)",
                actor: "Admin",
                category: "Configuration",
                status: "Success",
                icon: "briefcase.fill",
                color: "green"
            )
            await DatabaseService.shared.fetchAuditTrail()
        }
    }

    var productDeleteError: String? = nil
    var isProductDeleted: Bool = false

    func deleteLoanProduct(id: UUID) {
        Task {
            do {
                try await DatabaseService.shared.deleteLoanProduct(id: id)
                await DatabaseService.shared.logAudit(
                    title: "Loan Product Deleted",
                    actor: "Admin",
                    category: "Configuration",
                    status: "Success",
                    icon: "briefcase.fill",
                    color: "red"
                )
                await DatabaseService.shared.fetchAuditTrail()
                await MainActor.run {
                    self.productDeleteError = nil
                    self.isProductDeleted = true
                }
            } catch {
                await MainActor.run {
                    self.productDeleteError = error.localizedDescription
                }
            }
        }
    }

    func fetchUsers() {
        Task {
            await DatabaseService.shared.fetchUsers()
            let allUsers = DatabaseService.shared.users
            let count = allUsers.filter { $0.role != .borrower }.count
            
            let roles = Dictionary(grouping: allUsers) { $0.role }
            let orderedRoles: [UserRole] = [.admin, .manager, .officer, .borrower]
            let dist = orderedRoles.map { role in
                RoleDistribution(role: role.title, count: roles[role]?.count ?? 0)
            }

            await MainActor.run {
                self.staffCount = count
                self.roleDistribution = dist
            }
        }
    }

    func fetchAuditTrail() {
        Task {
            await DatabaseService.shared.fetchAuditTrail()
        }
    }

    var auditEntries: [AuditEntry] {
        DatabaseService.shared.auditTrail
    }

    private var complianceAuditEntries: [AuditEntry] {
        auditEntries.filter { entry in
            !isLoanAuditEntry(entry)
        }
    }

    var auditBranchOptions: [String] {
        return ["Head Office"] + Branch.allCases.map(\.rawValue)
    }

    var auditCategoryOptions: [String] {
        Array(Set(complianceAuditEntries.map(\.displayCategory))).sorted()
    }

    var auditStatusOptions: [String] {
        Array(Set(complianceAuditEntries.map(\.displayStatus))).sorted()
    }

    var filteredAuditEntries: [AuditEntry] {
        return complianceAuditEntries.filter { entry in
            let matchesSearch: Bool = {
                guard !searchText.isEmpty else { return true }
                return entry.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                    entry.displayActor.localizedCaseInsensitiveContains(searchText)
            }()

            let normalizedBranch = normalizeBranchName(entry.displayBranch)
            let matchesBranch = selectedBranch == "All" || normalizedBranch == selectedBranch
            let matchesCategory = selectedCategory == "All" || entry.displayCategory == selectedCategory
            let matchesStatus = selectedStatus == "All" || entry.displayStatus == selectedStatus

            return matchesSearch && matchesBranch && matchesCategory && matchesStatus
        }
    }

    var hasActiveAuditFilters: Bool {
        selectedBranch != "All" || selectedCategory != "All" || selectedStatus != "All"
    }

    func clearAuditFilters() {
        selectedBranch = "All"
        selectedCategory = "All"
        selectedStatus = "All"
    }

    func sanitizeAuditFilterSelections() {
        if selectedBranch != "All" && !auditBranchOptions.contains(selectedBranch) {
            selectedBranch = "All"
        }
        if selectedCategory != "All" && !auditCategoryOptions.contains(selectedCategory) {
            selectedCategory = "All"
        }
        if selectedStatus != "All" && !auditStatusOptions.contains(selectedStatus) {
            selectedStatus = "All"
        }
    }

    private func isLoanAuditEntry(_ entry: AuditEntry) -> Bool {
        let searchable = "\(entry.displayTitle) \(entry.displayCategory)".lowercased()
        let blockedTerms = ["loan", "application", "disbursement", "emi", "npa", "dpd"]
        return blockedTerms.contains { searchable.contains($0) }
    }

    private func normalizeBranchName(_ raw: String) -> String? {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return nil }
        let lower = v.lowercased()

        if lower == "main" || lower == "main branch" || lower == "hq" || lower == "head office" {
            return "Head Office"
        }
        
        if lower.contains("delhi") || lower.contains("north") { return Branch.north.rawValue }
        if lower.contains("bengaluru") || lower.contains("bangalore") || lower.contains("south") { return Branch.south.rawValue }
        if lower.contains("kolkata") || lower.contains("east") { return Branch.east.rawValue }
        if lower.contains("mumbai") || lower.contains("west") { return Branch.west.rawValue }
        if lower.contains("nagpur") || lower.contains("central") { return Branch.central.rawValue }

        if let exact = Branch.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(v) == .orderedSame }) {
            return exact.rawValue
        }
        
        return nil
    }
    
    var isGeneratingReport = false
    var lastGeneratedReport: GeneratedReport?
    var reportGenerationError: String?
    var reportGenerationFix: String?
    
    var dbGeneratedReports: [GeneratedReport] {
        DatabaseService.shared.generatedReports
    }

    func fetchGeneratedReports() {
        Task {
            await DatabaseService.shared.fetchGeneratedReports()
        }
    }

    func generateProfessionalReport() {
        isGeneratingReport = true
        reportGenerationError = nil
        reportGenerationFix = nil

        let reportTitle = selectedReportType.previewTitle
        let dateStr = Date.now.formatted(date: .abbreviated, time: .shortened)
        let reportId = "REF-\(Int.random(in: 100000...999999))"
        let (windowStart, windowEnd, windowText) = reportWindow(for: selectedRange, now: .now)

        Task {
            do {
                await DatabaseService.shared.fetchSystemConfig()
                let snapshot = (try? await DatabaseService.shared.fetchPortfolioSnapshot())
                    ?? DatabaseService.PortfolioSnapshot(totalPortfolio: 0, activeLoanCount: 0, totalRecovered: 0, outstandingBalance: 0, overdueExposure: 0, npaCaseCount: 0)
                
                await DatabaseService.shared.fetchBorrowers()
                let borrowers = DatabaseService.shared.borrowers
                
                let overdue = (try? await DatabaseService.shared.fetchRealDefaultedLoans(allBorrowers: borrowers)) ?? []
                let productDist = (try? await DatabaseService.shared.fetchLoanDistribution()) ?? []
                let emiRows = (try? await DatabaseService.shared.fetchEMISchedule(from: windowStart, to: windowEnd)) ?? []
                let loanComplianceLog = (try? await DatabaseService.shared.fetchLoanComplianceLog()) ?? []

                let auditWindow = includeAuditTrail
                    ? ((try? await DatabaseService.shared.fetchAuditTrail(from: windowStart, to: windowEnd)) ?? [])
                    : []

                let payload = buildReportPayload(
                    reportTitle: reportTitle,
                    reportId: reportId,
                    generatedAt: dateStr,
                    reportingWindow: windowText,
                    snapshot: snapshot,
                    overdueLoans: overdue,
                    productDistribution: productDist,
                    emiRows: emiRows,
                    auditEntries: auditWindow,
                    loanComplianceLog: loanComplianceLog,
                    borrowers: borrowers,
                    generatingAdmin: currentAdminName
                )

                if selectedFormat == .pdf {
                    let html = ReportHTMLTemplate.generate(payload: payload)
                    print("📄 HTML generated, length: \(html.count). Starting PDF render...")
                    PDFService.shared.generatePDF(fromHTML: html) { [weak self] data in
                        guard let self = self else { return }
                        guard let pdfData = data else {
                            print("❌ PDFService returned nil data")
                            Task { @MainActor in
                                self.isGeneratingReport = false
                                self.reportGenerationError = "PDF rendering failed."
                                self.reportGenerationFix = "The HTML template could not be converted to PDF. Try switching to CSV format."
                            }
                            return
                        }
                        print("✅ PDF rendered, size: \(pdfData.count) bytes. Uploading...")
                        self.uploadAndSaveReport(                            data: pdfData,
                            fileName: "Report_\(Int(Date().timeIntervalSince1970)).pdf",
                            contentType: "application/pdf",
                            reportTitle: reportTitle,
                            dateStr: dateStr
                        )
                    }
                } else {
                    let csv = payloadToCSV(payload)
                    print("📊 CSV generated, length: \(csv.count). Uploading...")
                    if let csvData = csv.data(using: .utf8) {
                        uploadAndSaveReport(
                            data: csvData,
                            fileName: "Report_\(Int(Date().timeIntervalSince1970)).csv",
                            contentType: "text/csv",
                            reportTitle: reportTitle,
                            dateStr: dateStr
                        )
                    } else {
                        await MainActor.run {
                            self.isGeneratingReport = false
                            self.reportGenerationError = "CSV encoding failed."
                            self.reportGenerationFix = "Could not encode the report data. Try again."
                        }
                    }
                }
            } catch {
                print("Report generation failed: \(error)")
                await MainActor.run {
                    self.isGeneratingReport = false
                    if let reportError = error as? ReportDataSourceError {
                        self.reportGenerationError = reportError.errorDescription
                        self.reportGenerationFix = reportError.recoverySuggestion
                    } else {
                        self.reportGenerationError = "Report generation failed."
                        self.reportGenerationFix = "Check your network and backend access settings, then try generating the report again."
                    }
                }
            }
        }
    }

    private func payloadToCSV(_ payload: ReportHTMLTemplate.Payload) -> String {
        var lines: [String] = []
        lines.append("Report Title,\(csvEsc(payload.meta.reportTitle))")
        lines.append("Report Type,\(csvEsc(payload.meta.reportType))")
        lines.append("Generated At,\(csvEsc(payload.meta.generatedAt))")
        lines.append("Reporting Window,\(csvEsc(payload.meta.reportingWindow))")
        lines.append("")

        if !payload.headerKpis.isEmpty {
            lines.append("KPI,Value,Note")
            for kpi in payload.headerKpis {
                lines.append("\(csvEsc(kpi.title)),\(csvEsc(kpi.value)),\(csvEsc(kpi.note ?? ""))")
            }
            lines.append("")
        }

        if !payload.summaryRows.isEmpty {
            lines.append("Summary Metric,Value")
            for row in payload.summaryRows {
                lines.append("\(csvEsc(row.label)),\(csvEsc(row.value))")
            }
            lines.append("")
        }

        for table in payload.tables {
            lines.append(csvEsc(table.title))
            lines.append(table.columns.map { csvEsc($0.title) }.joined(separator: ","))
            for row in table.rows {
                lines.append(row.map(csvEsc).joined(separator: ","))
            }
            if let foot = table.footnote, !foot.isEmpty {
                lines.append("Footnote,\(csvEsc(foot))")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func csvEsc(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func fetchReportData<T>(source: String, operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            throw ReportDataSourceError(source: source, underlying: error)
        }
    }

    private struct ReportDataSourceError: LocalizedError {
        let source: String
        let underlying: Error

        var errorDescription: String? {
            "Could not load required report data for \(source)."
        }

        var recoverySuggestion: String? {
            switch source {
            case "portfolio_snapshot":
                return "Portfolio data is unavailable right now. Confirm backend data access for this account and retry."
            case "overdue_loans":
                return "Overdue data is unavailable right now. Check access permissions and retry."
            case "loan_distribution":
                return "Loan distribution data is unavailable for this date range. Try another range or check backend data."
            case "emi_schedule":
                return "EMI schedule data is unavailable. Check backend configuration and retry."
            case "audit_trail":
                return "Audit trail entries were not found for this reporting window. Try a wider date range."
            default:
                return "Backend data for \(source) is unavailable. Please check access and try again."
            }
        }
    }

    private func reportWindow(for range: ReportRange, now: Date) -> (Date, Date, String) {
        let cal = Calendar.current

        let df = DateFormatter()
        df.calendar = cal
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "dd MMM yyyy"

        let start: Date
        let end: Date

        switch range {
        case .daily:
            start = cal.startOfDay(for: now)
            end = now
        case .weekly:
            start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? cal.startOfDay(for: now)
            end = now
        case .monthly:
            let comps = cal.dateComponents([.year, .month], from: now)
            start = cal.date(from: comps) ?? cal.startOfDay(for: now)
            end = now
        case .custom:
            start = cal.startOfDay(for: customStartDate)
            end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
        }

        let windowText = "\(df.string(from: start)) – \(df.string(from: end))"
        return (start, end, windowText)
    }

    private func buildReportPayload(
        reportTitle: String,
        reportId: String,
        generatedAt: String,
        reportingWindow: String,
        snapshot: DatabaseService.PortfolioSnapshot,
        overdueLoans: [OverdueLoan],
        productDistribution: [LoanDistribution],
        emiRows: [DatabaseService.EMIScheduleRow],
        auditEntries: [AuditEntry],
        loanComplianceLog: [DatabaseService.LoanComplianceEntry],
        borrowers: [Borrower],
        generatingAdmin: String? = nil
    ) -> ReportHTMLTemplate.Payload {
        let currency = currencyFormatter()

        let totalPortfolioStr = currency.string(from: NSNumber(value: snapshot.totalPortfolio)) ?? "\(snapshot.totalPortfolio)"
        let overdueStr = currency.string(from: NSNumber(value: snapshot.overdueExposure)) ?? "\(snapshot.overdueExposure)"
        let outstandingStr = currency.string(from: NSNumber(value: snapshot.outstandingBalance)) ?? "\(snapshot.outstandingBalance)"
        let recoveredStr = currency.string(from: NSNumber(value: snapshot.totalRecovered)) ?? "\(snapshot.totalRecovered)"

        let par = snapshot.totalPortfolio > 0 ? (snapshot.overdueExposure / snapshot.totalPortfolio) : 0
        let parStr = percent(par)

        let repayment = repaymentStats(from: emiRows, range: selectedRange, snapshot: snapshot)

        let meta = ReportHTMLTemplate.Meta(
            institutionName: systemConfig.institutionName,
            corporateId: "UD65110KA2026PLC04210",
            address: systemConfig.headquartersCity,
            reportTitle: reportTitle,
            reportId: reportId,
            generatedAt: generatedAt,
            classification: "CONFIDENTIAL",
            reportingWindow: reportingWindow,
            reportType: selectedReportType.title,
            generatingAdmin: generatingAdmin
        )

        var headerKpis: [ReportHTMLTemplate.KPIItem] = [
            .init(title: "Total Portfolio Value", value: totalPortfolioStr, note: nil),
            .init(title: "Active Loan Count", value: "\(snapshot.activeLoanCount)", note: nil),
            .init(title: "NPA Cases", value: "\(snapshot.npaCaseCount)", note: nil),
            .init(title: "Portfolio at Risk (PAR)", value: overdueStr, note: "Ratio: \(parStr)")
        ]
        var summaryRows: [ReportHTMLTemplate.KeyValueRow] = []
        var tables: [ReportHTMLTemplate.Table] = []

        switch selectedReportType {
        case .portfolioHealth:
            summaryRows = [
                .init(label: "Collection efficiency (window)", value: repayment.collectionEfficiencyText),
                .init(label: "Recovered vs outstanding", value: "\(recoveredStr) vs \(outstandingStr)"),
                .init(label: "PAR (Portfolio at Risk) ratio", value: parStr)
            ]

            tables.append(productDistributionTable(productDistribution))
            if includeBranchBreakdown {
                tables.append(branchBreakdownTable(auditEntries: auditEntries, borrowers: borrowers, totalPortfolio: snapshot.totalPortfolio, currency: currency))
            }

        case .npaAnalysis:
            let bucket = dpdBuckets(overdueLoans, currency: currency)
            let npaRatio = snapshot.totalPortfolio > 0 ? (snapshot.overdueExposure / snapshot.totalPortfolio) : 0
            let hasNoDefaults = snapshot.npaCaseCount == 0
            
            summaryRows = [
                .init(label: "Report Status", value: hasNoDefaults ? "No overdue loans detected" : "Active defaults reported"),
                .init(label: "NPA ratio %", value: percent(npaRatio)),
                .init(label: "NPA Loans", value: "\(snapshot.npaCaseCount)"),
                .init(label: "Exposure basis", value: "Active NPA portfolio")
            ]
            tables.append(bucket.bucketTable)
            tables.append(bucket.topBorrowersTable)

        case .repaymentTrend:
            summaryRows = [
                .init(label: "Collection efficiency", value: repayment.collectionEfficiencyText),
                .init(label: "On-time payments", value: "\(repayment.onTimeCount)"),
                .init(label: "Late payments", value: "\(repayment.lateCount)"),
                .init(label: "Missed payments", value: "\(repayment.missedCount)"),
                .init(label: "Bounce rate", value: repayment.bounceRateText),
                .init(label: "Pre-closure rate", value: repayment.preclosureRateText)
            ]
            tables.append(repayment.timeSeriesTable)

        case .auditCompliance:
            let total = loanComplianceLog.count
            let approved = loanComplianceLog.filter { $0.status == "approved" }.count
            let rejected = loanComplianceLog.filter { $0.status == "rejected" }.count
            let pending = loanComplianceLog.filter { $0.status == "submitted" || $0.status == "under_review" }.count
            let recommended = loanComplianceLog.filter { $0.status == "recommended" }.count
            let returned = loanComplianceLog.filter { $0.status == "returned_for_correction" }.count
            let approvalRate = total > 0 ? Double(approved) / Double(total) * 100 : 0

            summaryRows = [
                .init(label: "Total loan applications", value: "\(total)"),
                .init(label: "Approved", value: "\(approved)"),
                .init(label: "Rejected", value: "\(rejected)"),
                .init(label: "Pending review", value: "\(pending)"),
                .init(label: "Recommended (awaiting approval)", value: "\(recommended)"),
                .init(label: "Returned for correction", value: "\(returned)"),
                .init(label: "Approval rate", value: String(format: "%.1f%%", approvalRate))
            ]

            // Full loan action log table
            let loanRows = loanComplianceLog.prefix(100).map { entry -> [String] in
                let amountStr = entry.loanAmount.map { currency.string(from: NSNumber(value: $0)) ?? "₹\(Int($0))" } ?? "—"
                return [entry.date, entry.displayStatus, amountStr]
            }
            tables.append(ReportHTMLTemplate.Table(
                title: "Loan Application Action Log",
                columns: [
                    .init(title: "Date"),
                    .init(title: "Status"),
                    .init(title: "Loan Amount")
                ],
                rows: Array(loanRows),
                footnote: loanComplianceLog.count > 100 ? "Showing latest 100 of \(loanComplianceLog.count) records." : nil
            ))
        }

        if includeAuditTrail, selectedReportType != .auditCompliance, !auditEntries.isEmpty {
            tables.append(auditLogTable(auditEntries))
        }

        return ReportHTMLTemplate.Payload(meta: meta, headerKpis: headerKpis, summaryRows: summaryRows, tables: tables)
    }

    private func currencyFormatter() -> NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.maximumFractionDigits = 0

        let code = systemConfig.defaultCurrency.uppercased()
        switch code {
        case "INR":
            nf.currencySymbol = "₹"
        case "USD":
            nf.currencySymbol = "$"
        default:
            nf.currencySymbol = code + " "
        }
        return nf
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.2f%%", value * 100)
    }

    private func productDistributionTable(_ dist: [LoanDistribution]) -> ReportHTMLTemplate.Table {
        let rows = dist
            .sorted { $0.percentage > $1.percentage }
            .map { [$0.type, String(format: "%.1f%%", $0.percentage)] }
        return .init(
            title: "Product-wise Distribution",
            columns: [.init(title: "Product"), .init(title: "Share")],
            rows: rows,
            footnote: "Distribution is sourced from `loan_distribution`."
        )
    }

    private func branchBreakdownTable(
        auditEntries: [AuditEntry],
        borrowers: [Borrower],
        totalPortfolio: Double,
        currency: NumberFormatter
    ) -> ReportHTMLTemplate.Table {
        let borrowerGroups = Dictionary(grouping: borrowers) { b in
            normalizeBranchName(b.address ?? "") ?? "Other"
        }
        
        let auditGroups = Dictionary(grouping: auditEntries) { entry in
            normalizeBranchName(entry.displayBranch) ?? "Head Office"
        }
        
        let officialBranches = Branch.allCases.map(\.rawValue)
        let totalBorrowerCount = max(1, borrowers.count)

        let rows: [[String]] = officialBranches.map { branchName in
            let branchBorrowers = borrowerGroups[branchName] ?? []
            let branchAudits = auditGroups[branchName] ?? []
            
            let exceptions = branchAudits.filter { isExceptionStatus($0.displayStatus) }.count
            let exceptionRate = branchAudits.isEmpty ? 0 : Double(exceptions) / Double(max(1, branchAudits.count))
            
            let estExposure = totalPortfolio * (Double(branchBorrowers.count) / Double(totalBorrowerCount))
            let exposureStr = currency.string(from: NSNumber(value: estExposure)) ?? "\(estExposure)"
            
            return [
                branchName,
                "\(branchAudits.count)",
                String(format: "%.1f%%", exceptionRate * 100),
                exposureStr,
                complianceGrade(for: exceptionRate)
            ]
        }
        .sorted { $0[0] < $1[0] }

        return .init(
            title: "Branch-wise Breakdown",
            columns: [
                .init(title: "Branch Zone"),
                .init(title: "Activity Count"),
                .init(title: "Exception Rate"),
                .init(title: "Estimated Exposure"),
                .init(title: "Compliance Grade")
            ],
            rows: rows,
            footnote: "Exposure distribution is derived from borrower geographic concentration."
        )
    }

    private func auditLogTable(_ audit: [AuditEntry]) -> ReportHTMLTemplate.Table {
        let rows = audit.prefix(50).map { entry in
            [entry.time, entry.displayActor, entry.displayCategory, entry.displayTitle, entry.displayStatus]
        }
        return .init(
            title: "Audit Log (Window)",
            columns: [
                .init(title: "Timestamp"),
                .init(title: "Actor"),
                .init(title: "Category"),
                .init(title: "Action"),
                .init(title: "Result")
            ],
            rows: rows,
            footnote: audit.count > 50 ? "Showing first 50 events." : nil
        )
    }

    private struct RepaymentStats {
        let collectionEfficiencyText: String
        let onTimeCount: Int
        let lateCount: Int
        let missedCount: Int
        let bounceRateText: String
        let preclosureRateText: String
        let timeSeriesTable: ReportHTMLTemplate.Table
    }

    private func repaymentStats(from rows: [DatabaseService.EMIScheduleRow], range: ReportRange, snapshot: DatabaseService.PortfolioSnapshot) -> RepaymentStats {
        let cal = Calendar.current
        let day = DateFormatter()
        day.calendar = cal
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = .current
        day.dateFormat = "yyyy-MM-dd"

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var dueTotal: Double = 0
        var collectedTotal: Double = 0

        var onTime = 0
        var late = 0
        var missed = 0
        var bounced = 0
        var preclosed = 0

        if rows.isEmpty {
            missed = snapshot.npaCaseCount
            onTime = max(0, snapshot.activeLoanCount - snapshot.npaCaseCount)
        }

        struct Bucket { var due: Double = 0; var collected: Double = 0; var onTime: Int = 0; var late: Int = 0; var missed: Int = 0 }
        var buckets: [String: Bucket] = [:]

        for r in rows {
            guard let dueDate = day.date(from: r.dueDate) else { continue }
            dueTotal += r.amount

            let paidAt = r.paidAt.flatMap { iso.date(from: $0) }
            if let paidAt {
                collectedTotal += r.amount
                if paidAt <= cal.date(bySettingHour: 23, minute: 59, second: 59, of: dueDate) ?? dueDate {
                    onTime += 1
                } else {
                    late += 1
                }
            } else if dueDate < Date.now {
                missed += 1
            }

            let status = (r.status ?? "").lowercased()
            if status.contains("bounce") || status.contains("bounced") { bounced += 1 }
            if status.contains("pre") && status.contains("close") { preclosed += 1 }

            let bucketKey = repaymentBucketKey(for: dueDate, range: range)
            var b = buckets[bucketKey] ?? Bucket()
            b.due += r.amount
            if paidAt != nil { b.collected += r.amount }
            if paidAt != nil {
                if paidAt! <= (cal.date(bySettingHour: 23, minute: 59, second: 59, of: dueDate) ?? dueDate) { b.onTime += 1 } else { b.late += 1 }
            } else if dueDate < Date.now { b.missed += 1 }
            buckets[bucketKey] = b
        }

        let fallbackEfficiency = snapshot.totalPortfolio > 0 
            ? ((snapshot.totalPortfolio - snapshot.overdueExposure) / snapshot.totalPortfolio) 
            : 1.0
        
        let efficiency = dueTotal > 0 ? (collectedTotal / dueTotal) : fallbackEfficiency
        let efficiencyText = String(format: "%.1f%%", efficiency * 100)

        var seriesRows = buckets.keys.sorted().map { key -> [String] in
            let b = buckets[key] ?? Bucket()
            let eff = b.due > 0 ? (b.collected / b.due) : fallbackEfficiency
            return [
                key,
                String(format: "%.1f%%", eff * 100),
                "\(b.onTime)",
                "\(b.late)",
                "\(b.missed)"
            ]
        }
        
        if seriesRows.isEmpty {
            seriesRows.append([
                "Current Snapshot",
                efficiencyText,
                "\(onTime)",
                "\(late)",
                "\(missed)"
            ])
        }

        let seriesTable = ReportHTMLTemplate.Table(
            title: "Repayment Trend (Time Series)",
            columns: [
                .init(title: "Period"),
                .init(title: "Efficiency"),
                .init(title: "On-time"),
                .init(title: "Late"),
                .init(title: "Missed")
            ],
            rows: seriesRows,
            footnote: "Computed from `emi_schedule` due/paid timestamps when available."
        )

        let bounceRate = rows.isEmpty ? 0 : Double(bounced) / Double(rows.count)
        let preclosureRate = rows.isEmpty ? 0 : Double(preclosed) / Double(rows.count)

        return RepaymentStats(
            collectionEfficiencyText: efficiencyText,
            onTimeCount: onTime,
            lateCount: late,
            missedCount: missed,
            bounceRateText: String(format: "%.1f%%", bounceRate * 100),
            preclosureRateText: String(format: "%.1f%%", preclosureRate * 100),
            timeSeriesTable: seriesTable
        )
    }

    private func repaymentBucketKey(for date: Date, range: ReportRange) -> String {
        let cal = Calendar.current
        let df = DateFormatter()
        df.calendar = cal
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        switch range {
        case .daily:
            return "Today"
        case .weekly:
            df.dateFormat = "dd MMM yyyy"
            return df.string(from: date)
        case .monthly:
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
                .flatMap { cal.date(byAdding: .day, value: 1, to: $0) }
                ?? cal.startOfDay(for: date)
            df.dateFormat = "dd MMM yyyy"
            return "Week of \(df.string(from: weekStart))"
        case .custom:
            df.dateFormat = "dd MMM yyyy"
            return df.string(from: date)
        }
    }

    private func isExceptionStatus(_ status: String) -> Bool {
        let s = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return s.contains("error") || s.contains("failed") || s.contains("rejected")
    }

    private func complianceGrade(for exceptionRate: Double) -> String {
        switch exceptionRate {
        case ..<0.02: return "A+"
        case ..<0.05: return "A"
        case ..<0.10: return "B+"
        default: return "B"
        }
    }

    private struct DPDBucketsResult {
        let bucketTable: ReportHTMLTemplate.Table
        let topBorrowersTable: ReportHTMLTemplate.Table
    }

    private func dpdBuckets(_ overdue: [OverdueLoan], currency: NumberFormatter) -> DPDBucketsResult {
        let activeDefaults = overdue.filter { $0.status == .defaulted }

        func amt(_ s: String) -> Double {
            let clean = s
                .replacingOccurrences(of: "₹", with: "")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "Rs", with: "")
                .replacingOccurrences(of: "INR", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(clean) ?? 0
        }

        struct Bucket { let name: String; let range: String; let min: Int; let max: Int? }
        let defs: [Bucket] = [
            .init(name: "SMA-0", range: "1–30", min: 1, max: 30),
            .init(name: "SMA-1", range: "31–60", min: 31, max: 60),
            .init(name: "SMA-2", range: "61–90", min: 61, max: 90),
            .init(name: "NPA", range: "90+", min: 91, max: nil)
        ]

        let total = activeDefaults.map { amt($0.amount) }.reduce(0, +)

        let bucketRows: [[String]] = activeDefaults.isEmpty ? [["No overdue loans", "-", "-", "-"]] : defs.map { def in
            let exposure = activeDefaults.filter { loan in
                if let max = def.max { return loan.dpd >= def.min && loan.dpd <= max }
                return loan.dpd >= def.min
            }.map { amt($0.amount) }.reduce(0, +)

            let exposureStr = currency.string(from: NSNumber(value: exposure)) ?? "\(exposure)"
            let share = total > 0 ? (exposure / total) : 0
            return [def.name, def.range, exposureStr, String(format: "%.2f%%", share * 100)]
        }

        let bucketTable = ReportHTMLTemplate.Table(
            title: "DPD Buckets (Exposure)",
            columns: [
                .init(title: "Bucket"),
                .init(title: "DPD range"),
                .init(title: "Exposure"),
                .init(title: "Share")
            ],
            rows: bucketRows,
            footnote: "DPD is sourced from live active loan delinquency data."
        )

        let topRows = activeDefaults
            .sorted { a, b in
                if a.dpd != b.dpd { return a.dpd > b.dpd }
                return amt(a.amount) > amt(b.amount)
            }
            .prefix(10)
            .map { loan -> [String] in
                let exposureStr = currency.string(from: NSNumber(value: amt(loan.amount))) ?? loan.amount
                return [loan.borrowerName, "\(loan.dpd)", exposureStr, loan.status.rawValue]
            }

        let topTable = ReportHTMLTemplate.Table(
            title: "High-Risk Defaulted Borrowers",
            columns: [
                .init(title: "Borrower Name"),
                .init(title: "DPD"),
                .init(title: "Exposure"),
                .init(title: "Status")
            ],
            rows: topRows.isEmpty ? [["No overdue loans", "-", "-", "-"]] : Array(topRows),
            footnote: "Borrowers with active defaults, sorted by highest risk (DPD)."
        )

        return DPDBucketsResult(bucketTable: bucketTable, topBorrowersTable: topTable)
    }

    private struct AuditComplianceResult {
        let totalCount: Int
        let exceptionCount: Int
        let makerCheckerCount: Int
        let configChangeCount: Int
        let roleEscalationCount: Int
        let fullLogTable: ReportHTMLTemplate.Table
        let highlightsTable: ReportHTMLTemplate.Table
    }

    private func auditComplianceTables(entries: [AuditEntry]) -> AuditComplianceResult {
        let exceptions = entries.filter { isExceptionStatus($0.displayStatus) }
        let makerChecker = entries.filter { e in
            let t = e.displayTitle.lowercased()
            return t.contains("approve") || t.contains("reject") || t.contains("maker") || t.contains("checker")
        }
        let configChanges = entries.filter { e in
            let c = e.displayCategory.lowercased()
            let t = e.displayTitle.lowercased()
            return c.contains("system") || t.contains("config")
        }
        let roleEscalations = entries.filter { e in
            let t = e.displayTitle.lowercased()
            return t.contains("role") || t.contains("permission") || t.contains("ban")
        }

        let fullRows = entries.prefix(80).map { e in
            [e.time, e.displayActor, e.displayBranch, e.displayCategory, e.displayTitle, e.displayStatus]
        }
        let fullLog = ReportHTMLTemplate.Table(
            title: "Full Action Log (Window)",
            columns: [
                .init(title: "Timestamp"),
                .init(title: "Actor"),
                .init(title: "Branch"),
                .init(title: "Category"),
                .init(title: "Action"),
                .init(title: "Result")
            ],
            rows: fullRows,
            footnote: entries.count > 80 ? "Showing first 80 events for brevity." : nil
        )

        let highlightRows: [[String]] = [
            ["Maker-checker events", "\(makerChecker.count)"],
            ["Role escalations", "\(roleEscalations.count)"],
            ["Config changes", "\(configChanges.count)"],
            ["Exceptions (rejected/failed/error)", "\(exceptions.count)"]
        ]
        let highlights = ReportHTMLTemplate.Table(
            title: "Compliance Highlights",
            columns: [.init(title: "Category"), .init(title: "Count")],
            rows: highlightRows,
            footnote: "Highlights are derived from action/category keyword matching."
        )

        return AuditComplianceResult(
            totalCount: entries.count,
            exceptionCount: exceptions.count,
            makerCheckerCount: makerChecker.count,
            configChangeCount: configChanges.count,
            roleEscalationCount: roleEscalations.count,
            fullLogTable: fullLog,
            highlightsTable: highlights
        )
    }

    private func uploadAndSaveReport(data: Data, fileName: String, contentType: String, reportTitle: String, dateStr: String) {
        Task {
            do {
                let fileUrl = try await DatabaseService.shared.uploadGeneratedReport(data: data, fileName: fileName, contentType: contentType)
                
                let report = GeneratedReport(
                    name: reportTitle,
                    type: self.selectedReportType,
                    range: self.selectedRange,
                    format: self.selectedFormat,
                    generatedAt: dateStr,
                    includesAuditTrail: self.includeAuditTrail,
                    includesBranchBreakdown: self.includeBranchBreakdown,
                    fileUrl: fileUrl,
                    createdAt: Date()
                )
                
                await DatabaseService.shared.saveGeneratedReportRecord(report)
                
                await DatabaseService.shared.logAudit(
                    title: "Report Generated: \(reportTitle) (\(self.selectedFormat.rawValue))",
                    actor: "Admin",
                    category: "Reporting",
                    status: "Success",
                    icon: self.selectedFormat == .pdf ? "doc.richtext.fill" : "tablecells.fill",
                    color: "green"
                )
                
                await MainActor.run {
                    self.lastGeneratedReport = report
                    self.isGeneratingReport = false
                    print("✅ Report generated and synced: \(fileUrl)")
                }
            } catch {
                print("❌ Error uploading report: \(error)")
                await MainActor.run {
                    self.isGeneratingReport = false
                    self.reportGenerationError = "Failed to upload generated report."
                    self.reportGenerationFix = "Could not save the generated report. Check backend storage access and try again."
                }
            }
        }
    }

    func deleteReport(_ report: GeneratedReport) {
        Task {
            await DatabaseService.shared.deleteGeneratedReport(id: report.id, fileUrl: report.fileUrl ?? "")
        }
    }
    
    func loadReports() {
        fetchGeneratedReports()
    }
    
    func inviteUser(name: String, email: String, phone: String, role: UserRole, branch: String? = nil) {
        Task {
            do {
                try await DatabaseService.shared.inviteUser(name: name, email: email, phone: phone, role: role, branch: branch)
            } catch {
                print("Admin invite failed: \(error)")
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s stability delay
            await DatabaseService.shared.fetchUsers()
            await DatabaseService.shared.fetchAuditTrail()
        }
    }

    func deleteUser(id: UUID) {
        Task {
            await DatabaseService.shared.deleteUser(id: id)
            await DatabaseService.shared.logAudit(
                title: "User Deleted: \(id)",
                actor: "Admin",
                category: "Management",
                status: "Success",
                icon: "person.badge.minus",
                color: "red"
            )
            await DatabaseService.shared.fetchAuditTrail()
        }
    }

    func updateUser(id: UUID, name: String, email: String, phone: String, role: UserRole, branch: String? = nil) {
        Task {
            await DatabaseService.shared.updateUserProfile(id: id, name: name, email: email, phone: phone, role: role, branch: branch)
            await DatabaseService.shared.logAudit(
                title: "User Updated: \(name)",
                actor: "Admin",
                category: "Management",
                status: "Updated",
                icon: "pencil",
                color: "blue",
                branch: branch
            )
            await DatabaseService.shared.fetchAuditTrail()
        }
    }

    func toggleBan(id: UUID, isBanned: Bool) {
        Task {
            await DatabaseService.shared.banUser(id: id, isBanned: isBanned)
        }
    }

    func setUserBlocked(id: UUID, name: String, branch: String?, isBlocked: Bool) {
        Task {
            await DatabaseService.shared.setUserBlockedStatus(id: id, isBlocked: isBlocked)
            await DatabaseService.shared.logAudit(
                title: isBlocked ? "User Blocked: \(name)" : "User Unblocked: \(name)",
                actor: "Admin",
                category: "Management",
                status: isBlocked ? "Blocked" : "Active",
                icon: isBlocked ? "lock.fill" : "lock.open.fill",
                color: isBlocked ? "red" : "green",
                branch: branch
            )
            await DatabaseService.shared.fetchAuditTrail()
        }
    }
    
    var kpis: [KPI] {
        DatabaseService.shared.kpis
    }

    func fetchKPIs() {
        Task {
            do {
                try await DatabaseService.shared.fetchKPIs()
            } catch {
                print("AdminDashboardController.fetchKPIs failed: \(error)")
            }
        }
    }

    func fetchNotificationSettings() {
        Task {
            await DatabaseService.shared.fetchNotificationSettings()
            await MainActor.run {
                self.notificationSettings = DatabaseService.shared.notificationSettings
            }
        }
    }

    func saveNotificationSetting(_ setting: NotificationSetting) {
        if let index = notificationSettings.firstIndex(where: { $0.title == setting.title }) {
            notificationSettings[index] = setting
        } else {
            notificationSettings.append(setting)
        }
        
        Task {
            await DatabaseService.shared.saveNotificationSetting(setting)
            await MainActor.run {
                self.notificationSettings = DatabaseService.shared.notificationSettings
            }
        }
    }

    func deleteNotificationSetting(id: UUID) {
        Task {
            await DatabaseService.shared.deleteNotificationSetting(id: id)
        }
    }

    func fetchNotificationTemplates() {
        Task {
            await DatabaseService.shared.fetchNotificationTemplates()
        }
    }

    func saveNotificationTemplate(_ template: NotificationTemplate) {
        Task {
            await DatabaseService.shared.saveNotificationTemplate(template)
        }
    }

    func seedSystemData() {
        Task {
            // Seed Loan Products directly with documents
            let products = [
                LoanProduct(
                    name: "Personal Loan",
                    baseRate: 10.5,
                    maxRate: 18.0,
                    processingFee: 1.5,
                    minTenureMonths: 12,
                    maxTenureMonths: 60,
                    minAmount: 50000,
                    maxAmount: 1500000,
                    eligibilityRules: "Minimum salary ₹25,000. Age 21-60. Employment for at least 1 year.",
                    requiredDocuments: [
                        .init(name: "Aadhaar Card", isRequired: true),
                        .init(name: "PAN Card", isRequired: true),
                        .init(name: "Bank Statement (6 Months)", isRequired: true),
                        .init(name: "Salary Slips (3 Months)", isRequired: true),
                        .init(name: "Passport Size Photograph", isRequired: true)
                    ]
                ),
                LoanProduct(
                    name: "Home Loan",
                    baseRate: 8.25,
                    maxRate: 12.0,
                    processingFee: 0.5,
                    minTenureMonths: 60,
                    maxTenureMonths: 360,
                    minAmount: 1000000,
                    maxAmount: 50000000,
                    eligibilityRules: "Stable income proof. Co-applicant recommended for higher eligibility.",
                    requiredDocuments: [
                        .init(name: "Aadhaar Card", isRequired: true),
                        .init(name: "PAN Card", isRequired: true),
                        .init(name: "Property Title Deed", isRequired: true),
                        .init(name: "Approved Building Plan", isRequired: true),
                        .init(name: "ITR (2 Years)", isRequired: true),
                        .init(name: "Address Proof (Utility Bill)", isRequired: true)
                    ]
                ),
                LoanProduct(
                    name: "Vehicle Loan",
                    baseRate: 9.0,
                    maxRate: 14.0,
                    processingFee: 1.0,
                    minTenureMonths: 12,
                    maxTenureMonths: 84,
                    minAmount: 100000,
                    maxAmount: 5000000,
                    eligibilityRules: "Proforma Invoice required from authorized dealer.",
                    requiredDocuments: [
                        .init(name: "Aadhaar Card", isRequired: true),
                        .init(name: "PAN Card", isRequired: true),
                        .init(name: "Driving License", isRequired: true),
                        .init(name: "Vehicle Quotation", isRequired: true),
                        .init(name: "Bank Statement (6 Months)", isRequired: true)
                    ]
                ),
                LoanProduct(
                    name: "Education Loan",
                    baseRate: 7.5,
                    maxRate: 11.0,
                    processingFee: 0.0,
                    minTenureMonths: 12,
                    maxTenureMonths: 180,
                    minAmount: 50000,
                    maxAmount: 7500000,
                    eligibilityRules: "Course must be from accredited university. Admission proof required.",
                    requiredDocuments: [
                        .init(name: "Aadhaar Card", isRequired: true),
                        .init(name: "Admission Letter", isRequired: true),
                        .init(name: "Fee Schedule", isRequired: true),
                        .init(name: "Academic Marksheets", isRequired: true),
                        .init(name: "Co-borrower PAN/Income Proof", isRequired: true)
                    ]
                ),
                LoanProduct(
                    name: "Business Loan",
                    baseRate: 12.0,
                    maxRate: 22.0,
                    processingFee: 2.0,
                    minTenureMonths: 12,
                    maxTenureMonths: 120,
                    minAmount: 200000,
                    maxAmount: 20000000,
                    eligibilityRules: "Business vintage > 3 years. Profitable for last 2 years.",
                    requiredDocuments: [
                        .init(name: "GST Registration", isRequired: true),
                        .init(name: "Business ITR (3 Years)", isRequired: true),
                        .init(name: "Audited Balance Sheet", isRequired: true),
                        .init(name: "Business Bank Statement (12 Months)", isRequired: true)
                    ]
                )
            ]

            for product in products {
                await DatabaseService.shared.saveLoanProduct(product)
            }
            
            await fetchLoanProducts()
        }
    }

    func startLiveRefresh() {
        DatabaseService.shared.startLiveRefresh { [weak self] in
            Task { @MainActor in
                self?.fetchKPIs()
                self?.fetchUsers()
                self?.fetchAuditTrail()
                self?.fetchLoanProducts()
                self?.fetchGeneratedReports()
            }
        }
    }

    func stopLiveRefresh() {
        DatabaseService.shared.stopLiveRefresh()
    }
}
