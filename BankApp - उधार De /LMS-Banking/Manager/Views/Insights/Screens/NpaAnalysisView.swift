import SwiftUI
import Charts

struct NpaAnalysisView: View {
    let timeframe: TimeframeRange
    let controller: AnalyticsViewModel

    var body: some View {
        VStack(spacing: 24) {
            AnalyticsKPIGrid(kpis: controller.npaKPIs)

            ChartContainerCard(title: "Aging Buckets", subtitle: "Overdue loan distribution") {
                Chart(controller.npaAging) { item in
                    BarMark(
                        x: .value("Bucket", item.label),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(Color.appRed.gradient)
                    .cornerRadius(6)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                ChartContainerCard(title: "NPA Trend", subtitle: "Total NPA percentage") {
                    Chart(controller.npaTrends) { item in
                        LineMark(
                            x: .value("Time", item.label),
                            y: .value("NPA %", item.value)
                        )
                        .foregroundStyle(Color.appRed)
                        .lineStyle(StrokeStyle(lineWidth: 3))

                        PointMark(
                            x: .value("Time", item.label),
                            y: .value("NPA %", item.value)
                        )
                        .foregroundStyle(Color.appRed)
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let num = value.as(Double.self) {
                                    Text("\(String(format: "%.1f", num))%")
                                }
                            }
                        }
                    }
                }

                ChartContainerCard(title: "Exposure", subtitle: "Secured vs Unsecured") {
                    Chart(controller.npaExposure) { item in
                        BarMark(
                            x: .value("Time", item.label),
                            y: .value("Amount", item.value)
                        )
                        .foregroundStyle(by: .value("Type", item.category ?? ""))
                    }
                    .chartForegroundStyleScale([
                        "Secured": Color.appOrange,
                        "Unsecured": Color.appRed
                    ])
                    .chartLegend(position: .bottom, alignment: .center)
                }
            }

            MetricListSection(title: "Additional Metrics", metrics: controller.npaMetrics)
        }
    }
}
