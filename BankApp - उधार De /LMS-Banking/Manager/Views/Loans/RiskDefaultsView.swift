import SwiftUI

struct RiskDefaultsView: View {
    let controller: LoansViewModel

    var body: some View {
        VStack(spacing: 24) {
            DashboardGrid {
                ForEach(controller.riskSummaryItems) { item in
                    MetricCard(
                        title: item.title,
                        value: item.value,
                        change: item.change,
                        icon: item.iconName,
                        iconTint: Color.themeColor(for: item.accent),
                        showChevron: false
                    )
                }
            }

            OverdueLoansTable(controller: controller)
        }
    }
}