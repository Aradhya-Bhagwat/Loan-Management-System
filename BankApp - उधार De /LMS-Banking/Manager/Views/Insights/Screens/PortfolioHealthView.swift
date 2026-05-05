import SwiftUI
import Charts

struct PortfolioHealthView: View {
    let timeframe: TimeframeRange
    let controller: AnalyticsViewModel

    var body: some View {
        VStack(spacing: 24) {
            AnalyticsKPIGrid(kpis: controller.portfolioKPIs)

            ChartContainerCard(title: "Portfolio Growth", subtitle: "Total value over time") {
                Chart(controller.portfolioGrowth) { item in
                    LineMark(
                        x: .value("Time", item.label),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(Color.appGreen.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    AreaMark(
                        x: .value("Time", item.label),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appGreen.opacity(0.3), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.primary.opacity(0.12))
                        AxisValueLabel {
                            // Data values are already in Crores (divided by 10_000_000 at source)
                            if let v = value.as(Double.self) {
                                let label: String = {
                                    if v == 0 { return "₹0" }
                                    if v >= 1000 { return String(format: "₹%.0fCr", v) }
                                    if v >= 1    { return String(format: v.truncatingRemainder(dividingBy: 1) == 0 ? "₹%.0fCr" : "₹%.1fCr", v) }
                                    let lakh = v * 100
                                    return String(format: lakh.truncatingRemainder(dividingBy: 1) == 0 ? "₹%.0fL" : "₹%.1fL", lakh)
                                }()
                                Text(label)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.primary.opacity(0.75))
                            }
                        }
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                ChartContainerCard(title: "Distribution", subtitle: "By loan type") {
                    Chart(controller.portfolioDistribution) { item in
                        SectorMark(
                            angle: .value("Value", item.value),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("Type", item.category ?? ""))
                    }
                    .chartLegend(position: .bottom, alignment: .center)
                }

                ChartContainerCard(title: "Statuses", subtitle: "Active vs Closed") {
                    Chart(controller.portfolioStatus) { item in
                        BarMark(
                            x: .value("Category", item.label),
                            y: .value("Value", item.value)
                        )
                        .cornerRadius(6)
                        .foregroundStyle(by: .value("Status", item.label))
                    }
                    .chartLegend(.hidden)
                }
            }

            MetricListSection(title: "Additional Metrics", metrics: controller.portfolioMetrics)
        }
    }
}
