//import SwiftUI
//
//struct LoanOfficersView: View {
//    let controller: LoansController
//    @Environment(\.horizontalSizeClass) var sizeClass
//
//    var body: some View {
//        VStack(spacing: 24) {
//            DashboardGrid {
//                MetricCard(title: "Total Officers", value: "\(controller.officers.count)", change: "Active staff", icon: "person.3.fill", iconTint: .appGreen)
//                MetricCard(title: "Avg Approval Rate", value: avgApprovalRate, change: "Performance", icon: "chart.line.uptrend.xyaxis", iconTint: .appGreen)
//                MetricCard(title: "Avg Default Rate", value: avgDefaultRate, change: "Portfolio risk", icon: "chart.line.downtrend.xyaxis", iconTint: .appRed)
//            }
//
//            if sizeClass == .compact {
//                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: .infinity), spacing: 16)], spacing: 16) {
//                    officerList
//                }
//            } else {
//                // Reverted to original VStack for iPad
//                VStack(spacing: 14) {
//                    officerList
//                }
//            }
//        }
//    }
//
//    private var avgApprovalRate: String {
//        guard !controller.officers.isEmpty else { return "—" }
//        let avg = controller.officers.map(\.approvalRate).reduce(0, +) / Double(controller.officers.count)
//        return String(format: "%.1f%%", avg)
//    }
//
//    private var avgDefaultRate: String {
//        guard !controller.officers.isEmpty else { return "—" }
//        let avg = controller.officers.map(\.defaultRate).reduce(0, +) / Double(controller.officers.count)
//        return String(format: "%.1f%%", avg)
//    }
//
//    @ViewBuilder
//    private var officerList: some View {
//        ForEach(controller.officers) { officer in
//            OfficerCard(officer: officer)
//        }
//    }
//    }


import SwiftUI

struct LoanOfficersView: View {
    let controller: LoansViewModel
    @Environment(\.horizontalSizeClass) var sizeClass

    @State private var selectedOfficer: LoanOfficer? = nil

    var body: some View {
        VStack(spacing: 24) {
            DashboardGrid {
                MetricCard(
                    title: "Total Officers",
                    value: "\(controller.officers.count)",
                    change: "Active staff",
                    icon: "person.3.fill",
                    iconTint: .appGreen,
                    showChevron: false
                )
                MetricCard(
                    title: "Avg Approval Rate",
                    value: avgApprovalRate,
                    change: "Performance",
                    icon: "chart.line.uptrend.xyaxis",
                    iconTint: .appGreen,
                    showChevron: false
                )
                MetricCard(
                    title: "Avg Default Rate",
                    value: avgDefaultRate,
                    change: "Portfolio risk",
                    icon: "chart.line.downtrend.xyaxis",
                    iconTint: .appRed,
                    showChevron: false
                )
            }

            if sizeClass == .compact {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320, maximum: .infinity), spacing: 16)],
                    spacing: 16
                ) {
                    officerList
                }
            } else {
                VStack(spacing: 14) {
                    officerList
                }
            }
        }
        .sheet(item: $selectedOfficer) { officer in
            LoanOfficerDetailView(officer: officer)
        }
    }

    // MARK: - Computed

    private var avgApprovalRate: String {
        guard !controller.officers.isEmpty else { return "—" }
        let avg = controller.officers.map(\.approvalRate).reduce(0, +) / Double(controller.officers.count)
        return String(format: "%.1f%%", avg)
    }

    private var avgDefaultRate: String {
        guard !controller.officers.isEmpty else { return "—" }
        let avg = controller.officers.map(\.defaultRate).reduce(0, +) / Double(controller.officers.count)
        return String(format: "%.1f%%", avg)
    }

    @ViewBuilder
    private var officerList: some View {
        ForEach(controller.officers) { officer in
            OfficerCard(officer: officer)
                .contentShape(Rectangle())
                .onTapGesture { selectedOfficer = officer }
        }
    }
}
