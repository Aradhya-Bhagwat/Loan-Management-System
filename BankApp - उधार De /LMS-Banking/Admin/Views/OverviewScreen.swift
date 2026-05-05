import SwiftUI

struct OverviewScreen: View {
    let metrics: DashboardLayoutMetrics
    @Bindable var controller: AdminDashboardViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                summaryGrid
                adminAnalyticsSection
                recentActivity
            }
            .frame(maxWidth: metrics.contentWidth)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, metrics.isCompact ? 16 : 26)
            .padding(.bottom, 32)
        }
        .refreshable {
            controller.fetchKPIs()
            controller.fetchAuditTrail()
            controller.fetchUsers()
        }
        .task {
            refreshData()
        }
    }
    
    private func refreshData() {
        controller.fetchKPIs()
        controller.fetchAuditTrail()
        controller.fetchUsers()
    }

    private var summaryGrid: some View {
        DashboardGrid {
            if controller.kpis.isEmpty {
                KPIButton(type: .portfolioHealth, controller: controller, title: "Portfolio Health", value: "—", change: nil, icon: "briefcase.fill", tint: .appGreen)
                KPIButton(type: .repaymentTrend, controller: controller, title: "Repayment Trends", value: "—", change: nil, icon: "chart.line.uptrend.xyaxis", tint: .appGreen)
                KPIButton(type: .npaAnalysis, controller: controller, title: "NPA Analysis", value: "—", change: nil, icon: "exclamationmark.triangle.fill", tint: .appGreen)
                KPIButton(type: .auditCompliance, controller: controller, title: "Active Loans", value: "—", change: nil, icon: "checkmark.seal.fill", tint: .appGreen)
            } else {
                ForEach(controller.kpis) { kpi in
                    KPIButton(
                        type: reportType(for: kpi.title),
                        controller: controller,
                        title: kpi.title,
                        value: kpi.value,
                        change: kpi.change,
                        icon: kpi.iconName,
                        tint: .appGreen
                    )
                }
            }
        }
    }
    
    private func reportType(for title: String) -> AdminReportType {
        if title.contains("Portfolio") { return .portfolioHealth }
        if title.contains("Repayment") { return .repaymentTrend }
        if title.contains("NPA") { return .npaAnalysis }
        if title.contains("Active") { return .auditCompliance }
        return .auditCompliance
    }
    
    private var adminAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ADMINISTRATIVE INSIGHTS")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            AdminChartsView(
                roleDistribution: controller.roleDistribution,
                staffCount: controller.staffCount
            )
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink {
                AuditTrailView(controller: controller)
            } label: {
                HStack {
                    Text("Audit Trail")
                        .font(metrics.sectionTitleFont)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appGreen)
                }
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    auditHeader
                    ForEach(controller.auditEntries.prefix(5)) { entry in
                        auditRow(entry)
                    }
                }
                .frame(minWidth: 920, alignment: .leading)
            }
            .appCard()
        }
    }

    private func auditRow(_ entry: AuditEntry) -> some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: entry.displayIcon)
                    .foregroundColor(entry.iconColor)
                    .frame(width: 32, height: 32)
                    .background(entry.iconColor.opacity(0.1))
                    .clipShape(Circle())

                Text(entry.displayTitle)
                    .font(.body.weight(.medium))
            }
            .frame(width: 250, alignment: .leading)

            Text(entry.displayActor)
                .font(.body)
                .foregroundColor(.primary)
                .frame(width: 140, alignment: .leading)

            Text(entry.displayCategory)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(entry.displayBranch)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(entry.time)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(entry.displayStatus)
                .font(.caption.bold())
                .foregroundColor(entry.statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(entry.statusColor.opacity(0.1))
                .clipShape(Capsule())
                .frame(width: 110, alignment: .leading)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.secondary.opacity(0.2))
        }
    }

    private var auditHeader: some View {
        HStack {
            auditHeaderText("Action", width: 250)
            auditHeaderText("Actor", width: 140)
            auditHeaderText("Category", width: 130)
            auditHeaderText("Branch", width: 130)
            auditHeaderText("Date", width: 130)
            auditHeaderText("Status", width: 110)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.secondary.opacity(0.2))
        }
    }

    private func auditHeaderText(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
    }
}

// MARK: - Admin Analytics Components

struct RoleDistribution: Identifiable {
    let id = UUID()
    let role: String
    let count: Int
}

struct ActivityCategory: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
}

struct BranchExposure: Identifiable {
    let id = UUID()
    let branch: String
    let count: Int
}

struct KPIButton: View {
    let type: AdminReportType
    @Bindable var controller: AdminDashboardViewModel
    let title: String
    let value: String
    let change: String?
    let icon: String
    let tint: Color

    var body: some View {
        NavigationLink {
            SingleReportDetailView(reportType: type, controller: controller)
        } label: {
            MetricCard(
                title: title,
                value: value,
                change: change,
                icon: icon,
                iconTint: tint
            )
        }
        .buttonStyle(.plain)
    }
}

import Charts

struct AdminChartsView: View {
    let roleDistribution: [RoleDistribution]
    let staffCount: Int
    @State private var selectedRole: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                AppSectionHeader(title: "Workforce", subtitle: "User count by role")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(staffCount)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.appGreen)
                    Text("Total Staff")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }

            if roleDistribution.isEmpty {
                ChartEmptyState(icon: "person.2.fill")
            } else {
                Chart(roleDistribution) { item in
                    BarMark(
                        x: .value("Role", item.role),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(Color.appGreen.gradient)
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .center) {
                        Text("\(item.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(selectedRole == item.role ? Color.appGreen : Color.secondary)
                            .padding(.bottom, 2)
                    }
                }
                .chartXSelection(value: $selectedRole)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }
}

struct ChartEmptyState: View {
    let icon: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("No data available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}
