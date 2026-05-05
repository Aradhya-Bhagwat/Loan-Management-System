import SwiftUI
import Supabase

// MARK: - UI Models
struct UpcomingEMI: Identifiable {
    let id = UUID()
    let loanName: String
    let date: String
    let amount: String
}

struct PredictiveAlert: Identifiable {
    let id = UUID()
    let message: String
    let isWarning: Bool
}

// MARK: - HomeView
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showNotifications = false
    @State private var showPredictiveForm = false

    @State private var selectedEMI: EMISchedule?
    @State private var isProcessingPayment = false
    @State private var showPaymentSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    if viewModel.isNPA {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .font(.title2)
                                .foregroundStyle(.white)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("ACCOUNT MARKED AS NPA")
                                    .font(.caption.bold())
                                    .tracking(0.5)
                                Text("Your loan is overdue. Please pay immediately to avoid legal action.")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding()
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    // MARK: Dashboard Card
                    DashboardCard(
                        totalLoan: viewModel.totalLoanAmount,
                        outstanding: viewModel.outstandingBalance,
                        repaid: viewModel.repaidAmount,
                        tenureLeft: viewModel.tenureLeft
                    )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .redacted(reason: viewModel.isLoading ? .placeholder : [])

                    // MARK: Upcoming EMIs
                    SectionHeader(title: "Upcoming EMIs") {
                        NavigationLink(destination: EMIScheduleView()) {
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(Color.theme.primaryAccent)
                        }
                        .padding(.trailing, 8)
                    }

                    CardView {
                        VStack(spacing: 0) {
                            if viewModel.isLoading && viewModel.upcomingEMIs.isEmpty {
                                SkeletonRow().padding()
                            } else if viewModel.upcomingEMIs.isEmpty {
                                VStack(spacing: 8) {
                                    Text(viewModel.hasActiveLoans ? "No EMIs due this month" : "No active loans found")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.theme.textPrimary)
                                    Text(viewModel.hasActiveLoans ? "You're all caught up!" : "Your approved loans will appear here.")
                                        .font(.caption)
                                        .foregroundStyle(Color.theme.textSecondary)
                                }
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                            } else {
                                ForEach(Array(viewModel.upcomingEMIs.enumerated()), id: \.element.id) { i, emi in
                                    EMIRowView(emi: emi) {
                                        startPayment(for: emi)
                                    }
                                    if i < viewModel.upcomingEMIs.count - 1 {
                                        Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Credit Score
                    SectionHeader(title: "Credit Score")
                    CardView { 
                        CreditScoreRow(score: viewModel.creditScore)
                            .redacted(reason: viewModel.isLoading ? .placeholder : [])
                    }

                    // MARK: - Predictive Alerts
                    SectionHeader(title: "Predictive Alerts")
                    VStack(spacing: 12) {
                        if viewModel.isLoading && viewModel.alerts.isEmpty {
                            SkeletonRow().cardStyle().padding(.horizontal, 20)
                        } else if viewModel.alerts.isEmpty {
                            Button {
                                showPredictiveForm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                    Text("Start getting predictive alerts")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(Color.theme.primaryAccent)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .cardStyle()
                                .padding(.horizontal, 20)
                            }
                        } else {
                            ForEach(viewModel.alerts) { alert in
                                AlertRowView(alert: alert)
                                    .cardStyle(background: alert.insightType == "Warning" ? Color.theme.warningBackground : Color.theme.infoBackground)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }

                    Spacer(minLength: 32)
                }
            }
            .background(Color.theme.appBackground.ignoresSafeArea())
            .dismissKeyboardOnTap()
            .navigationTitle("Home")
            .toolbar {
                BadgedBellButton(unreadCount: viewModel.unreadNotificationCount) {
                    showNotifications = true
                }

                NavigationLink(destination: ProfileView()) {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                        .foregroundColor(Color.theme.primaryAccent)
                }
            }
            .sheet(isPresented: $showNotifications, onDismiss: {
                Task { await viewModel.refreshData() }
            }) {
                NotificationView()
            }
            .sheet(isPresented: $showPredictiveForm, onDismiss: {
                Task {
                    await viewModel.refreshData()
                }
            }) {
                PredictiveAlertsFormView()
            }
            .fullScreenCover(item: $selectedEMI) { emi in
                CashfreeGatewayView(
                    amount: emi.amount,
                    onComplete: { orderId, paymentId, signature in
                        completePayment(emi: emi, orderId: orderId, paymentId: paymentId, signature: signature)
                    },
                    onCancel: {
                        selectedEMI = nil
                    }
                )
            }
            .sheet(isPresented: $showPaymentSuccess) {
                PaymentSuccessView {
                    showPaymentSuccess = false
                    showNotifications = true
                }
            }
            .refreshable { await viewModel.refreshData() }
            .task {
                await runPrediction()
                await viewModel.refreshData()
            }
        }
    }

    func runPrediction() async {
        do {
            try await SupabaseManager.shared.client
                .rpc("run_emi_prediction")
                .execute()

            print("EMI prediction executed")

        } catch {
            print("Prediction error:", error.localizedDescription)
        }
    }

    private func startPayment(for emi: EMISchedule) {
        selectedEMI = emi
    }

    private func completePayment(emi: EMISchedule, orderId: String, paymentId: String, signature: String) {
        selectedEMI = nil
        isProcessingPayment = true
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            do {
                try await SupabaseManager.shared.recordPayment(
                    emi: emi,
                    paymentId: paymentId,
                    orderId: orderId,
                    signature: signature
                )
                await viewModel.refreshData()
                showPaymentSuccess = true
            } catch {
                print("Payment recording failed: \(error)")
            }
            isProcessingPayment = false
        }
    }
}

// MARK: - Activity Row (Moved to separate file)
// MARK: - Dashboard Card
struct DashboardCard: View {
    @State private var animateRing = false

    let totalLoan: Double
    let outstanding: Double
    let repaid: Double
    let tenureLeft: Int

    var progress: CGFloat {
        totalLoan > 0 ? CGFloat(repaid / totalLoan) : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: animateRing ? progress : 0)
                    .stroke(Color.theme.primaryAccent,
                            style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.2), value: animateRing)
                    .animation(.easeInOut(duration: 0.8), value: progress)

                VStack(spacing: 4) {
                    Text("TOTAL OUTSTANDING")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.theme.textSecondary)
                        .tracking(0.8)
                    Text("₹\(Int(outstanding).formatted())")
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundStyle(Color.theme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: outstanding)
                    Text("of ₹\(Int(totalLoan).formatted()) repaid")
                        .font(.caption)
                        .foregroundStyle(Color.theme.textSecondary)
                }
            }
            .frame(width: 190, height: 190)
            .padding(.top, 28)

            Divider()
                .background(Color.gray.opacity(0.1))
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

            HStack {
                VStack(spacing: 3) {
                    Text("REPAID")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(Color.theme.textSecondary)
                        .tracking(0.8)
                    Text("₹\(Int(repaid).formatted())")
                        .font(.headline)
                        .foregroundStyle(Color.theme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: repaid)
                }
                Spacer()
                Rectangle()
                    .frame(width: 1, height: 32)
                    .foregroundStyle(Color.gray.opacity(0.2))
                Spacer()
                VStack(spacing: 3) {
                    Text("TENURE LEFT")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(Color.theme.textSecondary)
                        .tracking(0.8)
                    Text("\(tenureLeft) Months")
                        .font(.headline)
                        .foregroundStyle(Color.theme.textPrimary)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .onAppear { animateRing = true }
        .onChange(of: repaid) { _, _ in

            animateRing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { animateRing = true }
            }
        }
    }
}

// MARK: - EMI Row
struct EMIRowView: View {
    let emi: EMISchedule
    var onPay: () -> Void
    @State private var showReceipt = false

    private var isPaid: Bool {
        emi.status.lowercased() == "paid"
    }

    private var isPayable: Bool {
        !emi.status.contains("Est.") && !isPaid
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        if let d = fmt.date(from: emi.dueDate) {
            fmt.dateStyle = .medium
            fmt.dateFormat = nil
            return fmt.string(from: d)
        }
        return emi.dueDate
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isPaid ? "EMI — Paid" : "EMI Payment")
                        .font(.body).fontWeight(.medium)
                        .foregroundStyle(Color.theme.textPrimary)

                    if isPaid {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.theme.success)
                    }

                    if emi.status.contains("Est.") {
                        Text("Projected")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.theme.warning)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.theme.warningBackground)
                            .clipShape(Capsule())
                    }
                }
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("₹\(Int(emi.amount).formatted())")
                    .font(.body).fontWeight(.semibold)
                    .foregroundStyle(isPaid ? Color.theme.success : Color.theme.primaryAccent)

                if isPaid {

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
                } else {
                    Button("Pay Now") {
                        onPay()
                    }
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.theme.primaryText)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(isPayable ? Color.theme.primaryAccent : Color.gray.opacity(0.3))
                    .clipShape(Capsule())
                    .disabled(!isPayable)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .sheet(isPresented: $showReceipt) {
            PaymentReceiptView(emi: emi)
        }
    }
}

// MARK: - Credit Score Row
struct CreditScoreRow: View {
    @State private var animateArc = false
    let score: Int
    let maxScore = 900
    var progress: CGFloat { CGFloat(score) / CGFloat(maxScore) }
    var label: String {
        score >= 750 ? "Excellent" : score >= 700 ? "Very Good" : score >= 650 ? "Good" : "Fair"
    }

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))
                Circle()
                    .trim(from: 0.12, to: animateArc ? (0.12 + progress * 0.76) : 0.12)
                    .stroke(Color.theme.primaryAccent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .animation(.easeInOut(duration: 1.2), value: animateArc)
                Text("\(score)")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(Color.theme.textPrimary)
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.title3).fontWeight(.bold).foregroundStyle(Color.theme.primaryAccent)
                Text("out of \(maxScore)").font(.subheadline).foregroundStyle(Color.theme.textSecondary)
                Text("Updated Live").font(.caption).foregroundStyle(Color.theme.textSecondary.opacity(0.8))
            }
            Spacer()
        }
        .padding(16)
        .onAppear { animateArc = true }
        .onChange(of: score) { oldValue, newValue in animateArc = false; withAnimation { animateArc = true } }
    }
}

// MARK: - Alert Row
struct AlertRowView: View {
    let alert: FinancialInsight
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.insightType == "Warning" ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(alert.insightType == "Warning" ? Color.theme.warning : Color.theme.primaryAccent)
                .font(.body).padding(.top, 1)
            Text(alert.content)
                .font(.subheadline).foregroundStyle(Color.theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
        }
        .padding(16)
    }
}

// MARK: - Activity Row
struct ActivityRowView: View {
    let log: AuditLog

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(getIconColor().opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: log.icon)
                    .font(.subheadline)
                    .foregroundStyle(getIconColor())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(log.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.theme.textPrimary)

                Text(formatDate(log.createdAt ?? ""))
                    .font(.caption)
                    .foregroundStyle(Color.theme.textSecondary)
            }

            Spacer()

            Text(log.status)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(log.status == "Success" ? Color.theme.success : Color.theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(log.status == "Success" ? Color.theme.successBackground : Color.gray.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func getIconColor() -> Color {
        switch log.iconColor.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return Color.theme.primaryAccent
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else { return dateString }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - Skeleton Helper
struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.gray.opacity(0.1)).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.1)).frame(width: 120, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.1)).frame(width: 80, height: 10)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
