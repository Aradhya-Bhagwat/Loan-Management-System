import SwiftUI
import Charts

struct RepaymentTrendsView: View {
    let timeframe: TimeframeRange
    let controller: AnalyticsViewModel

    var body: some View {
        VStack(spacing: 24) {
            AnalyticsKPIGrid(kpis: controller.repaymentKPIs)

            ChartContainerCard(title: "Monthly Repayments", subtitle: "Total funds collected") {
                Chart(controller.repaymentTrends) { item in
                    LineMark(
                        x: .value("Time", item.label),
                        y: .value("Amount", item.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.appOrange.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Time", item.label),
                        y: .value("Amount", item.value)
                    )
                    .foregroundStyle(Color.appOrange)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                ChartContainerCard(title: "Target vs Actual", subtitle: "Collection performance") {
                    Chart(controller.repaymentTargets) { item in
                        BarMark(
                            x: .value("Time", item.label),
                            y: .value("Value", item.value)
                        )
                        .position(by: .value("Category", item.category ?? ""))
                        .foregroundStyle(by: .value("Category", item.category ?? ""))
                    }
                    .chartForegroundStyleScale([
                        "Target": Color.secondary.opacity(0.3),
                        "Actual": Color.appGreen
                    ])
                    .chartLegend(position: .bottom, alignment: .center)
                }

                ChartContainerCard(title: "Cumulative Growth", subtitle: "Accumulated collections") {
                    Chart(controller.repaymentCumulative) { item in
                        AreaMark(
                            x: .value("Time", item.label),
                            y: .value("Value", item.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.5), Color.blue.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Time", item.label),
                            y: .value("Value", item.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }

            MetricListSection(title: "Additional Metrics", metrics: controller.repaymentMetrics)
        }
    }
}
