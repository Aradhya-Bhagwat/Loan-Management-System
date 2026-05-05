import SwiftUI

struct EMIScheduleView: View {
    @State private var allEMIs: [EMISchedule] = []
    @State private var activeLoans: [UUID: ActiveLoan] = [:]
    @State private var applications: [UUID: LoanApplication] = [:]
    @State private var isLoading = true

    @State private var emiToPay: EMISchedule? = nil
    @State private var payingEMIId: UUID? = nil
    @State private var showPaymentSuccess = false
    @State private var showPaymentFailure = false
    @State private var successMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 60)
                } else if allEMIs.isEmpty {

                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.theme.textSecondary)
                        Text("No Active Loans Found")
                            .font(.headline)
                            .foregroundStyle(Color.theme.textPrimary)
                        Text("You don't have any active loans or EMI schedules at the moment.")
                            .font(.subheadline)
                            .foregroundStyle(Color.theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 80)
                    .padding(.horizontal, 32)
                } else {
                    ForEach(groupedEMIs.keys.sorted(by: { $0.uuidString < $1.uuidString }), id: \.self) { loanId in
                        LoanEMISection(
                            loanId: loanId,
                            emis: groupedEMIs[loanId] ?? [],
                            activeLoan: activeLoans[loanId],
                            application: {
                                if let loan = activeLoans[loanId] {
                                    return applications[loan.applicationId]
                                }
                                return nil
                            }(),
                            payingEMIId: payingEMIId,
                            onPay: { emi in emiToPay = emi }
                        )
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color.theme.appBackground.ignoresSafeArea())
        .navigationTitle("Active Loans Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        // MARK: - Cashfree Payment Sheet
        .fullScreenCover(item: $emiToPay) { emi in
            CashfreeGatewayView(
                amount: emi.amount,
                onComplete: { orderId, paymentId, signature in
                    Task {
                        await handlePaymentSuccess(
                            emi: emi,
                            paymentId: paymentId,
                            orderId: orderId,
                            signature: signature
                        )
                    }
                },
                onCancel: {
                    showPaymentFailure = true
                    emiToPay = nil
                }
            )
        }
            .sheet(isPresented: $showPaymentSuccess) {
                PaymentSuccessView {
                    showPaymentSuccess = false
                }
            }
            .alert("Payment Cancelled", isPresented: $showPaymentFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your payment was not completed. Please try again.")
        }
    }

    // MARK: - Grouped EMIs
    var groupedEMIs: [UUID: [EMISchedule]] {
        Dictionary(grouping: allEMIs, by: { $0.loanId })
    }

    // MARK: - Load Data
    private func loadData() async {
        isLoading = true
        do {
            let fetchedLoans = try await SupabaseManager.shared.fetchActiveLoans()
            print("📋 Active loans fetched: \(fetchedLoans.count)")

            let fetchedApps  = try await SupabaseManager.shared.fetchMyApplications()
            print("📋 Applications fetched: \(fetchedApps.count)")

            var loanDict = [UUID: ActiveLoan]()
            for loan in fetchedLoans { loanDict[loan.id] = loan }

            var appDict = [UUID: LoanApplication]()
            for app in fetchedApps {
                if let id = app.id { appDict[id] = app }
            }
            var loanToApp = [UUID: LoanApplication]()
            for loan in fetchedLoans {
                if let app = appDict[loan.applicationId] {
                    loanToApp[loan.id] = app
                }
            }

            self.activeLoans = loanDict
            self.applications = appDict

            let fetched = try await SupabaseManager.shared.fetchEMISchedule()
            print("📋 EMIs fetched: \(fetched.count)")

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            allEMIs = fetched.sorted {
                let d1 = formatter.date(from: $0.dueDate) ?? Date.distantFuture
                let d2 = formatter.date(from: $1.dueDate) ?? Date.distantFuture
                return d1 < d2
            }
        } catch {
            print("❌ EMIScheduleView: Failed to load — \(error)")
        }
        isLoading = false
    }

    // MARK: - Handle Successful Payment
    private func handlePaymentSuccess(emi: EMISchedule, paymentId: String, orderId: String, signature: String) async {
        emiToPay = nil
        payingEMIId = emi.id

        do {
            try await SupabaseManager.shared.recordPayment(
                emi: emi,
                paymentId: paymentId,
                orderId: orderId,
                signature: signature
            )

            await loadData()
            showPaymentSuccess = true
        } catch {
            print("❌ Failed to record payment: \(error)")
        }
        payingEMIId = nil
    }
}

// MARK: - Loan EMI Section (one per active loan)
struct LoanEMISection: View {
    let loanId: UUID
    let emis: [EMISchedule]
    let activeLoan: ActiveLoan?
    let application: LoanApplication?
    let payingEMIId: UUID?
    let onPay: (EMISchedule) -> Void

    private var title: String {
        if let app = application {
            return "\(app.purpose) — ₹\(Int(app.loanAmount).formatted())"
        }
        return "Loan \(String(loanId.uuidString.prefix(8)))"
    }

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: title)

            if let loan = activeLoan {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(Color.theme.primaryAccent)
                    Text("Outstanding Balance")
                        .font(.subheadline)
                        .foregroundStyle(Color.theme.textSecondary)
                    Spacer()
                    Text("₹\(Int(loan.outstandingBalance).formatted())")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(Color.theme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }

            CardView {
                VStack(spacing: 0) {
                    ForEach(Array(emis.enumerated()), id: \.element.id) { i, emi in
                        EMIPayableRow(
                            emi: emi,
                            isPaying: payingEMIId == emi.id,
                            onPay: { onPay(emi) }
                        )
                        if i < emis.count - 1 {
                            Divider()
                                .background(Color.gray.opacity(0.1))
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - EMI Payable Row (Full-featured version with payment button)
struct EMIPayableRow: View {
    let emi: EMISchedule
    let isPaying: Bool
    let onPay: () -> Void
    @State private var showReceipt = false

    var body: some View {
        HStack(spacing: 12) {

            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(emiLabel)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(Color.theme.textPrimary)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("₹\(Int(emi.amount).formatted())")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(emi.status.lowercased() == "paid" ? Color.theme.success : Color.theme.textPrimary)

                if emi.status.lowercased() == "paid" {
                    Button {
                        showReceipt = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 10))
                            Text("View Receipt")
                        }
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.theme.success)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.theme.successBackground)
                        .clipShape(Capsule())
                    }
                } else if isPayable {
                    Button(action: onPay) {
                        if isPaying {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 60, height: 24)
                        } else {
                            Label("Pay Now", systemImage: "arrow.right.circle.fill")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(Color.theme.primaryText)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.theme.primaryAccent)
                    .clipShape(Capsule())
                    .disabled(isPaying)
                } else {
                    statusBadge
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .sheet(isPresented: $showReceipt) {
            PaymentReceiptView(emi: emi)
        }
    }

    // MARK: - Helpers
    private var isPayable: Bool {
        return emi.status.lowercased() != "paid"
    }

    private var emiLabel: String {
        switch emi.status.lowercased() {
        case "paid":    return "EMI — Paid"
        case "overdue": return "EMI — Overdue"
        default:        return "EMI Payment"
        }
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        if let d = fmt.date(from: emi.dueDate) {
            fmt.dateStyle = .medium
            fmt.dateFormat = nil
            return "Due: \(fmt.string(from: d))"
        }
        return "Due: \(emi.dueDate)"
    }

    private var statusColor: Color {
        switch emi.status.lowercased() {
        case "paid":    return Color.theme.success
        case "overdue": return Color.theme.danger
        default:        return Color.theme.primaryAccent
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let s = emi.status.lowercased()
        if s == "overdue" {
            Text("Overdue")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(Color.theme.danger)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.theme.dangerBackground)
                .clipShape(Capsule())
        } else {
            Text("Upcoming")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(Color.theme.info)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.theme.infoBackground)
                .clipShape(Capsule())
        }
    }

    private func formatPaidAt(_ paidAt: String?) -> String {
        guard let paidAt = paidAt else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: paidAt) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: paidAt) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return paidAt
    }
}
