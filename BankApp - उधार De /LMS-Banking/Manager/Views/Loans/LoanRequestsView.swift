import SwiftUI

struct LoanRequestsView: View {
    @Bindable var controller: LoansViewModel

    var body: some View {
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
        .alert("Validation Error", isPresented: $controller.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(controller.alertMessage)
        }
    }
}
