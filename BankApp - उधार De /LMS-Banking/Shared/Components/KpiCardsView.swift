import SwiftUI

struct KpiCardsView: View {
    let kpis: [KPI]
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        if kpis.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary.opacity(0.3))
                Text("No KPI data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .appCard()
        } else {
            DashboardGrid {
                ForEach(kpis) { kpi in
                    NavigationLink(destination: ReportDetailView(title: kpi.title)) {
                        MetricCard(
                            title: kpi.title,
                            value: kpi.value,
                            change: kpi.change,
                            icon: kpi.iconName,
                            iconTint: Color.themeColor(for: kpi.accent)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    KpiCardsView(kpis: [])
        .padding()
        .background(Color.appBackground)
}
