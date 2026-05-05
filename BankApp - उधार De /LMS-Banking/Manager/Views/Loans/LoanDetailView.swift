import SwiftUI

// MARK: - Loan Detail View

struct LoanDetailView: View {
    //let loan: Loan
    @State var loan: Loan
    @State private var showSanctionLetter = false
    @State private var sanctionLetterExists = false
    let onApprove: (Loan) -> Void
    let onReject: (Loan) -> Void
    let onReturn: (Loan, String) -> Void
    @State private var showRepaymentHistory = false
    @State private var showApproveAlert = false
    @State private var showRejectAlert = false
    @State private var showReturnView = false
    @State private var returnComment = ""
    @State private var showDocuments = false
    @State private var officerRemarks: [LoanComment] = []

    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass

    var isPad: Bool { sizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                    // MARK: Borrower Header
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color.appGreen.opacity(0.15))
                            .frame(width: isPad ? 60 : 48, height: isPad ? 60 : 48)
                            .overlay(
                                Text(loan.borrowerName.prefix(1))
                                    .font(.system(size: isPad ? 26 : 20, weight: .semibold))
                                    .foregroundStyle(Color.appGreen)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loan.borrowerName)
                                .font(.system(size: isPad ? 22 : 18, weight: .bold))
                                .foregroundStyle(.primary)
                            HStack {
                                Text(ApplicationIDGenerator.generate(from: loan.id))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                StatusBadge(status: loan.status)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, isPad ? 18 : 14)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // MARK: Detail Rows
                    VStack(spacing: 0) {
                        DetailRowView(label: "Amount",           value: CurrencyFormatter.indian(loan.amountValue))
                        Divider().padding(.leading, 16)
                        DetailRowView(label: "Purpose",          value: loan.purpose)
                        Divider().padding(.leading, 16)
                        DetailRowView(label: "Tenure",           value: loan.tenure)
                        Divider().padding(.leading, 16)
                        DetailRowView(label: "Credit Score",     value: "\(loan.creditScore)")
                        Divider().padding(.leading, 16)
                        DetailRowView(label: "Monthly Income",   value: loan.income.replacingOccurrences(of: "$", with: "₹"))
                        Divider().padding(.leading, 16)
                        DetailRowView(label: "Assigned Officer", value: loan.officer)
                    }
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                // MARK: Officer Remarks
                if !officerRemarks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        
                        Text("Officer Remarks")
                            .font(.system(size: isPad ? 18 : 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        VStack(spacing: 10) {
                            ForEach(officerRemarks, id: \.id) { comment in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(comment.text)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary)

                                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                    // MARK: Action Buttons
                    VStack(spacing: 12) {
                        
                        if loan.status == .approved {
                            Button {
                                showRepaymentHistory = true
                            } label: {
                                Label("Repayment History", systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.appGreen)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.appGreen.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                showSanctionLetter = true
                            } label: {
                                Label(
                                    sanctionLetterExists ? "View Sanction Letter" : "Generate Sanction Letter",
                                    systemImage: sanctionLetterExists ? "doc.text" : "doc.badge.plus"
                                )
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.appGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.appGreen.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // View Documents + Send Back side by side
                        HStack(spacing: 12) {
                            Button {
                                showDocuments = true
                            } label: {
                                Label("View Documents", systemImage: "doc.text.viewfinder")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.appGreen)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.appGreen.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            if loan.status == .recommended {
                                Button {
                                    showReturnView = true
                                } label: {
                                    Label("Send Back", systemImage: "arrow.uturn.backward.circle.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.appGreen)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(Color.appGreen.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
//                                        .overlay(
//                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
//                                                .stroke(Color.appGreen.opacity(0.3), lineWidth: 1)
//                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if loan.status == .recommended {
                            approveButton
                            rejectButton
                        }
                    }
                }
                .padding(.horizontal, isPad ? 28 : 20)
                .padding(.vertical, isPad ? 28 : 20)
        }
        .task {
            if loan.status == .approved {
                let url = try? await DatabaseService.shared.fetchSanctionLetterUrl(loanId: loan.id)
                await MainActor.run {
                    sanctionLetterExists = url != nil
                }
            }
            //if loan.status == .recommended {
                if let comments = try? await DatabaseService.shared.fetchLoanComments(loanId: loan.id) {
                    await MainActor.run {
                        officerRemarks = comments
                    }
                }
            //}
        }
            .background(Color.appBackground)
            .navigationTitle("Loan Application")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Confirm Approval", isPresented: $showApproveAlert) {
                Button("Approve") { onApprove(loan); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to approve this loan?")
            }
            .alert("Confirm Rejection", isPresented: $showRejectAlert) {
                Button("Reject", role: .destructive) { onReject(loan); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to reject this loan?")
            }
            .navigationDestination(isPresented: $showDocuments) {
                LoanDocumentsView(loan: loan)
            }
            .navigationDestination(isPresented: $showRepaymentHistory) {
                RepaymentHistoryView(loan: loan)
            }
            .navigationDestination(isPresented: $showSanctionLetter) {
                SanctionLetterView(loan: loan)
            }
            .onChange(of: showSanctionLetter) { _, isShowing in
                if !isShowing {
                    Task {
                        let url = try? await DatabaseService.shared.fetchSanctionLetterUrl(loanId: loan.id)
                        await MainActor.run {
                            sanctionLetterExists = url != nil
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showReturnView) {
                ReturnForCorrectionView(
                    loan: loan,
                    comment: $returnComment,
                    onConfirm: {
                        onReturn(loan, returnComment)
                        loan = Loan(
                            id: loan.id,
                            borrowerId: loan.borrowerId,
                            borrowerName: loan.borrowerName,
                            amount: loan.amount,
                            amountValue: loan.amountValue,
                            risk: loan.risk,
                            officer: loan.officer,
                            status: .returnedForCorrection,
                            purpose: loan.purpose,
                            tenure: loan.tenure,
                            creditScore: loan.creditScore,
                            income: loan.income,
                            sanctionLetterUrl: loan.sanctionLetterUrl
                        )
                        showReturnView = false
                    }
                )
            }
    }

    // MARK: - Button Subviews

    private var approveButton: some View {
        Button {
            showApproveAlert = true
        } label: {
            Label("Approve", systemImage: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appGreen)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var rejectButton: some View {
        Button {
            showRejectAlert = true
        } label: {
            Label("Reject", systemImage: "xmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.appRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appRed.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.appRed.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Return For Correction View (pushed inside same NavigationStack)

struct ReturnForCorrectionView: View {
    @State var loan: Loan
    @Binding var comment: String
    let onConfirm: () -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass

    var isPad: Bool { sizeClass == .regular }
    var isCommentEmpty: Bool { comment.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: Context Banner
                HStack(spacing: 14) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: isPad ? 36 : 28))
                        .foregroundStyle(Color.appGreen)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Send Back for Correction")
                            .font(.system(size: isPad ? 18 : 16, weight: .bold))
                        Text("This loan will be returned to \(loan.officer) for corrections.")
                            .font(.system(size: isPad ? 14 : 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(isPad ? 20 : 16)
                .background(Color.appGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.appGreen.opacity(0.2), lineWidth: 1)
                )

                // MARK: Loan Summary (compact)
                VStack(spacing: 0) {
                    DetailRowView(label: "Borrower", value: loan.borrowerName)
                    Divider().padding(.leading, 16)
                    DetailRowView(label: "Amount",   value: CurrencyFormatter.indian(loan.amountValue))
                    Divider().padding(.leading, 16)
                    DetailRowView(label: "Purpose",  value: loan.purpose)
                }
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // MARK: Comment Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comments for Officer")
                        .font(.system(size: isPad ? 15 : 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $comment)
                        .frame(minHeight: isPad ? 180 : 140)
                        .padding(12)
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(
                                    isCommentEmpty ? Color.appGreen.opacity(0.4) : Color.secondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )

                    if isCommentEmpty {
                        Label("A comment is required before sending back.", systemImage: "exclamationmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.red)
                    }
                }

                // MARK: Confirm Button
                Button {
                    onConfirm()
                } label: {
                    Label("Send Back to Officer", systemImage: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isCommentEmpty ? Color.appGreen.opacity(0.4) : Color.appGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isCommentEmpty)
            }
            .padding(.horizontal, isPad ? 28 : 20)
            .padding(.vertical, isPad ? 28 : 20)
        }
        .background(Color.appBackground)
        .navigationTitle("Return for Correction")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Detail Row

struct DetailRowView: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}
