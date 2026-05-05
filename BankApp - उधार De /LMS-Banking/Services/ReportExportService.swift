import Foundation

struct ReportExportService {
    static func preparePayload(
        title: String,
        timeframe: String,
        controller: AnalyticsViewModel,
        userName: String? = nil
    ) -> ReportHTMLTemplate.Payload {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let meta = ReportHTMLTemplate.Meta(
            institutionName: "उधार De",
            corporateId: "UD65110KA2026PLC04210",
            address: "Delhi, India",
            reportTitle: title,
            reportId: "REP-\(Int.random(in: 10000...99999))",
            generatedAt: formatter.string(from: now),
            classification: "CONFIDENTIAL",
            reportingWindow: timeframe,
            reportType: "Manager Analytics Report",
            generatingAdmin: userName ?? "Authorized Signatory"
        )
        
        var kpis: [ReportHTMLTemplate.KPIItem] = []
        var tables: [ReportHTMLTemplate.Table] = []
        
        if title.lowercased().contains("portfolio") {
            kpis = controller.portfolioKPIs.map { ReportHTMLTemplate.KPIItem(title: $0.title, value: $0.value, note: "Current Period") }
            
            // Portfolio Distribution Table
            let distRows = controller.portfolioDistribution.map { [ $0.label, String(format: "%.1f%%", $0.value) ] }
            tables.append(ReportHTMLTemplate.Table(
                title: "Portfolio Distribution by Loan Type",
                columns: [ReportHTMLTemplate.TableColumn(title: "Category"), ReportHTMLTemplate.TableColumn(title: "Weightage")],
                rows: distRows,
                footnote: "Percentage based on total outstanding principal."
            ))
            
            // Growth Metrics Table
            let metricsRows = controller.portfolioMetrics.map { [ $0.title, $0.value ] }
            tables.append(ReportHTMLTemplate.Table(
                title: "Core Performance Metrics",
                columns: [ReportHTMLTemplate.TableColumn(title: "Metric"), ReportHTMLTemplate.TableColumn(title: "Current Value")],
                rows: metricsRows,
                footnote: nil
            ))
            
        } else if title.lowercased().contains("repayment") {
            kpis = controller.repaymentKPIs.map { ReportHTMLTemplate.KPIItem(title: $0.title, value: $0.value, note: "Current Period") }
            
            let metricsRows = controller.repaymentMetrics.map { [ $0.title, $0.value ] }
            tables.append(ReportHTMLTemplate.Table(
                title: "Collection Efficiency Details",
                columns: [ReportHTMLTemplate.TableColumn(title: "Metric"), ReportHTMLTemplate.TableColumn(title: "Status/Value")],
                rows: metricsRows,
                footnote: "Collection efficiency is calculated against scheduled repayments."
            ))
            
        } else if title.lowercased().contains("npa") {
            kpis = controller.npaKPIs.map { ReportHTMLTemplate.KPIItem(title: $0.title, value: $0.value, note: "Current Period") }
            
            let agingRows = controller.npaAging.map { [ $0.label, String(format: "₹%.2f Cr", $0.value) ] }
            tables.append(ReportHTMLTemplate.Table(
                title: "NPA Aging Buckets",
                columns: [ReportHTMLTemplate.TableColumn(title: "Aging Bracket"), ReportHTMLTemplate.TableColumn(title: "Total Exposure")],
                rows: agingRows,
                footnote: "Exposure includes principal and accrued interest."
            ))
            
            let metricsRows = controller.npaMetrics.map { [ $0.title, $0.value ] }
            tables.append(ReportHTMLTemplate.Table(
                title: "Delinquency Risk Metrics",
                columns: [ReportHTMLTemplate.TableColumn(title: "Metric"), ReportHTMLTemplate.TableColumn(title: "Value")],
                rows: metricsRows,
                footnote: nil
            ))
            
        } else if title.lowercased().contains("audit") {
            kpis = controller.auditKPIs.map { ReportHTMLTemplate.KPIItem(title: $0.title, value: $0.value, note: "Current Status") }
            
            let auditRows = controller.auditTrail.map { [ $0.time, $0.displayTitle, $0.displayStatus ] }
            tables.append(ReportHTMLTemplate.Table(
                title: "Recent Audit Trail",
                columns: [
                    ReportHTMLTemplate.TableColumn(title: "Date"),
                    ReportHTMLTemplate.TableColumn(title: "Activity"),
                    ReportHTMLTemplate.TableColumn(title: "Result")
                ],
                rows: auditRows,
                footnote: "Showing the latest system and manual audit actions."
            ))
            
            let metricsRows = controller.auditMetrics.map { [ $0.title, $0.value ] }
            tables.append(ReportHTMLTemplate.Table(
                title: "Compliance Health Indicators",
                columns: [ReportHTMLTemplate.TableColumn(title: "Compliance Metric"), ReportHTMLTemplate.TableColumn(title: "Finding")],
                rows: metricsRows,
                footnote: nil
            ))
        }
        
        return ReportHTMLTemplate.Payload(
            meta: meta,
            headerKpis: kpis,
            summaryRows: [], // Executive summary is handled by KPIs in the template
            tables: tables
        )
    }
}
