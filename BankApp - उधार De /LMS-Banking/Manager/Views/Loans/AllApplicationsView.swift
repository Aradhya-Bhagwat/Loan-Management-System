import SwiftUI

struct AllApplicationsView: View {
    @Bindable var controller: DashboardViewModel
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LoanTableView(
                    loans: controller.loans,
                    searchText: $controller.searchText,
                    statusFilter: $controller.statusFilter,
                    selectedLoan: $controller.selectedLoan,
                    mode: .all,
                    startDate: $controller.startDate,
                    endDate: $controller.endDate,
                    onApprove: { loan in Task { await controller.approveLoan(loan) } },
                    onReject: { loan in Task { await controller.rejectLoan(loan) } },
                    onReturn: { loan, comment in Task { await controller.returnLoan(loan, comment: comment) } }
                )
            }
            .padding(.horizontal, sizeClass == .regular ? 32 : 16)
            .padding(.vertical, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Loan Approvals")
        .navigationBarTitleDisplayMode(.inline)
    }
}
