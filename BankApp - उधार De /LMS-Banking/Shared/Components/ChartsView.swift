import SwiftUI
import Charts

// MARK: - Currency Formatter

func formatCurrency(_ value: Double) -> String {
    if value >= 10_000_000 {
        let cr = value / 10_000_000
        return cr.truncatingRemainder(dividingBy: 1) == 0
            ? "₹\(Int(cr))Cr" : String(format: "₹%.1fCr", cr)
    } else if value >= 100_000 {
        let l = value / 100_000
        return l.truncatingRemainder(dividingBy: 1) == 0
            ? "₹\(Int(l))L" : String(format: "₹%.1fL", l)
    } else if value >= 1_000 {
        let k = value / 1_000
        return k.truncatingRemainder(dividingBy: 1) == 0
            ? "₹\(Int(k))K" : String(format: "₹%.1fK", k)
    } else {
        return "₹\(Int(value))"
    }
}

// MARK: - Charts View

struct ChartsView: View {
    let distribution: [LoanDistribution]
    let disbursements: [MonthlyDisbursement]
    let trends: [DefaultTrend]
    let sector: [SectorPerformance]
    var totalPortfolioValue: Double = 0
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        let spacing: CGFloat = sizeClass == .regular ? 24 : 16
        let columns = sizeClass == .regular
            ? [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
            : [GridItem(.flexible(), spacing: spacing)]

        LazyVGrid(columns: columns, spacing: spacing) {
            LoanDistributionChart(data: distribution, loanProducts: [], showChevron: false, totalPortfolioValue: totalPortfolioValue)
            MonthlyDisbursementChart(data: disbursements)
            DefaultTrendsChart(data: trends)
            SectorPerformanceChart(data: sector)
        }
    }
}

// MARK: - Loan Distribution Chart


struct LoanDistributionChart: View {
    let data: [LoanDistribution]
    let loanProducts: [LoanProduct]
    let showChevron: Bool
    var totalPortfolioValue: Double = 0
    var competitiveRates: [CompetitiveRate] = []
    let chartColors: [Color] = [.appGreen, .appGreenLight, .appOrange, .blue]
    @State private var showProducts = false

    // Compute amount from percentage × total
    private func amount(for item: LoanDistribution) -> Double {
        totalPortfolioValue * (item.percentage / 100.0)
    }

    private func legendLabel(for item: LoanDistribution) -> String {
        if totalPortfolioValue > 0 {
            return "\(item.type) (\(formatCurrency(amount(for: item))))"
        }
        return "\(item.type) (\(Int(item.percentage))%)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Loan Distribution", subtitle: "By loan type")
                Spacer()
                if showChevron {
                    Button {
                        showProducts = true
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color.appSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if data.isEmpty {
                emptyStateView
            } else {
                Chart(data) { item in
                    let index = data.firstIndex(where: { $0.id == item.id }) ?? 0
                    SectorMark(
                        angle: .value("Share", item.percentage),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(chartColors[index % chartColors.count])
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .frame(height: 180)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(chartColors[index % chartColors.count])
                                .frame(width: 8, height: 8)
                            Text(legendLabel(for: item))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .cardStyle()
.navigationDestination(isPresented: $showProducts) {
            ManagerLoanProductsView(
                loanProducts: loanProducts,
                distribution: data,
                totalPortfolioValue: totalPortfolioValue,
                competitiveRates: competitiveRates
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("No data available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }
}

// MARK: - Monthly Disbursement Chart

struct MonthlyDisbursementChart: View {
    let data: [MonthlyDisbursement]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Monthly Disbursement", subtitle: "Amount disbursed")

            if data.isEmpty {
                emptyStateView
            } else {
                Chart(data) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.amount * 1_000_000)
                    )
                    .foregroundStyle(Color.appGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .symbol(Circle())
                    .symbolSize(40)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.amount * 1_000_000)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appGreen.opacity(0.2), Color.appGreen.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.primary.opacity(0.12))
                        AxisValueLabel()
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(0.75))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.primary.opacity(0.12))
                        AxisValueLabel {
                            let doubleVal = value.as(Double.self) ?? Double(value.as(Int.self) ?? 0)
                            Text(formatCurrency(doubleVal))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.primary.opacity(0.75))
                        }
                    }
                }
                .frame(height: 240)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .cardStyle()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("No data available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }
}

// MARK: - Default Trends Chart

struct DefaultTrendsChart: View {
    let data: [DefaultTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "NPA Trends", subtitle: "Monthly count")

            if data.isEmpty {
                emptyStateView
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Defaults", item.count)
                    )
                    .foregroundStyle(Color.appRed.gradient)
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.primary.opacity(0.12))
                        AxisValueLabel()
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(0.75))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.primary.opacity(0.12))
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                Text("\(intVal)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.primary.opacity(0.75))
                            }
                        }
                    }
                }
                .frame(height: 240)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .cardStyle()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("No data available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }
}

// MARK: - Sector Performance Chart

struct SectorPerformanceChart: View {
    let data: [SectorPerformance]

    // Disbursed = warm orange, Recovered = green
    private let disbursedColor = Color(red: 0.95, green: 0.45, blue: 0.15)

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("No data available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 215)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Sector Performance", subtitle: "Disbursed vs Recovered")

            if data.isEmpty {
                emptyStateView
            } else {
                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Sector", item.sector),
                            y: .value("Amount", item.disbursed * 1000),
                            width: .ratio(0.4)
                        )
                        .foregroundStyle(disbursedColor.gradient)
                        .cornerRadius(6)
                        .position(by: .value("Type", "Disbursed"))

                        BarMark(
                            x: .value("Sector", item.sector),
                            y: .value("Amount", item.recovered * 1000),
                            width: .ratio(0.4)
                        )
                        .foregroundStyle(Color.appGreen.gradient)
                        .cornerRadius(6)
                        .position(by: .value("Type", "Recovered"))
                    }
                }
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(0.75))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.primary.opacity(0.12))
                        AxisValueLabel {
                            let doubleVal = value.as(Double.self) ?? Double(value.as(Int.self) ?? 0)
                            Text(formatCurrency(doubleVal))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.primary.opacity(0.75))
                        }
                    }
                }
                .frame(height: 215)

                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(disbursedColor)
                            .frame(width: 16, height: 10)
                        Text("Disbursed")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.appGreen)
                            .frame(width: 16, height: 10)
                        Text("Recovered")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .cardStyle()
    }
}

struct PortfolioAtRiskTrendChart: View {
    let data: [ChartDataEntry]

    private func formatCompactCurrency(_ value: Double) -> String {
        if value >= 10_000_000 {
            return "₹\(String(format: "%.1f", value / 10_000_000))Cr"
        } else if value >= 100_000 {
            return "₹\(String(format: "%.1f", value / 100_000))L"
        } else if value >= 1_000 {
            return "₹\(String(format: "%.1f", value / 1_000))K"
        } else {
            return "₹\(Int(value))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Portfolio at Risk", subtitle: "₹ Overdue Exposure Over Time")

            if data.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("No data available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
            } else {
                Chart(data) { item in
                    LineMark(
                        x: .value("Period", item.label),
                        y: .value("PAR", item.value)
                    )
                    .foregroundStyle(Color.appOrange)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .symbol(Circle())
                    .symbolSize(40)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Period", item.label),
                        y: .value("PAR", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appOrange.opacity(0.25), Color.appOrange.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color(.systemGray4))
                        AxisValueLabel()
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color(.systemGray4))
                        AxisValueLabel {
                            Text(formatCompactCurrency(value.as(Double.self) ?? 0))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 240)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .cardStyle()
    }
}
#Preview {
    ChartsView(
        distribution: [],
        disbursements: [],
        trends: [],
        sector: []
    )
    .padding()
    .background(Color.appBackground)
}
