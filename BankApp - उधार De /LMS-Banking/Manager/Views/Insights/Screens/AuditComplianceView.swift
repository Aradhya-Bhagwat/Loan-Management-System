import SwiftUI
import Charts

extension DatabaseService.LoanComplianceEntry {
    var statusColor: Color {
        switch status {
        case "approved":                return .appGreen
        case "rejected":                return .appRed
        case "recommended":             return .appPurple
        case "returned_for_correction": return .appOrange
        case "under_review":            return .appBlue
        default:                        return .secondary
        }
    }
}

struct AuditComplianceView: View {
    let timeframe: TimeframeRange
    let controller: AnalyticsViewModel

    // Computed stats from real loan data
    private var totalApplications: Int { controller.loanComplianceLog.count }
    private var approvedCount: Int { controller.loanComplianceLog.filter { $0.status == "approved" }.count }
    private var rejectedCount: Int { controller.loanComplianceLog.filter { $0.status == "rejected" }.count }
    private var pendingCount: Int { controller.loanComplianceLog.filter { $0.status == "submitted" || $0.status == "under_review" }.count }

    var body: some View {
        VStack(spacing: 24) {
            // Loan Action Compliance Section
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Loan Action Compliance")
                        .font(.system(size: 16, weight: .semibold))
                    Text("All loan application actions across the system")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                // Summary chips
                HStack(spacing: 12) {
                    complianceChip("Total", "\(totalApplications)", .appGreen)
                    complianceChip("Approved", "\(approvedCount)", .appGreen)
                    complianceChip("Rejected", "\(rejectedCount)", .appRed)
                    complianceChip("Pending", "\(pendingCount)", .appOrange)
                }

                if controller.loanComplianceLog.isEmpty {
                    Text("No loan data available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Date")
                                .frame(width: 90, alignment: .leading)
                            Text("Status")
                                .frame(width: 110, alignment: .leading)
                            Text("Amount")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        Divider()

                        ForEach(controller.loanComplianceLog.prefix(50)) { entry in
                            HStack {
                                Text(entry.date)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 90, alignment: .leading)

                                Text(entry.displayStatus)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(entry.statusColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(entry.statusColor.opacity(0.1))
                                    .clipShape(Capsule())
                                    .frame(width: 110, alignment: .leading)

                                Spacer()

                                if let amount = entry.loanAmount {
                                    Text("₹\(Int(amount).formatted())")
                                        .font(.system(size: 13, weight: .medium))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)

                            Divider().opacity(0.5)
                        }

                        if controller.loanComplianceLog.count > 50 {
                            Text("Showing latest 50 of \(controller.loanComplianceLog.count) records")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(12)
                        }
                    }
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .cardStyle(padding: 20)

            ChartContainerCard(title: "Audit Status", subtitle: "System audit trail breakdown") {
                if controller.auditStatus.isEmpty {
                    Text("No data available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    Chart(controller.auditStatus) { item in
                        SectorMark(
                            angle: .value("Value", item.value),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("Status", item.label))
                    }
                    .chartLegend(position: .bottom, alignment: .center)
                    .frame(minHeight: 220)
                }
            }

            MetricListSection(title: "Additional Metrics", metrics: controller.auditMetrics)
        }
    }

    private func complianceChip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
