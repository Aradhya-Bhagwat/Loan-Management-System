import SwiftUI

// MARK: - LoansView
struct LoansView: View {
    @State private var unreadCount = 0
    @State private var showEMICalculator = false
    @State private var showNotifications = false
    @State private var showApplyForm = false
    @State private var fetchedApplications: [LoanApplication] = []
    @State private var activeLoans: [ActiveLoan] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ApplyNowBanner(showApplyForm: $showApplyForm)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // MARK: EMI Calculator Banner
                    EMICalculatorBanner(showCalculator: $showEMICalculator)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    // MARK: My Applications
                    SectionHeader(title: "My Applications")
                    CardView {
                        VStack(spacing: 0) {
                            if fetchedApplications.isEmpty {
                                Text("No applications found")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.theme.textSecondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(Array(fetchedApplications.enumerated()), id: \.element.id) { i, app in
                                    NavigationLink(destination: ApplicationDetailView(application: app)) {
                                        ApplicationRowView(application: app)
                                    }

                                    if i < fetchedApplications.count - 1 {
                                        Divider()
                                            .background(Color.gray.opacity(0.1))
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 32)
                }
            }
            .background(Color.theme.appBackground.ignoresSafeArea())
            .navigationTitle("Loans")
            .toolbar {
                BadgedBellButton(unreadCount: unreadCount) {
                    showNotifications = true
                }

                NavigationLink(destination: ProfileView()) {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                        .foregroundColor(Color.theme.primaryAccent)
                }
            }
            .sheet(isPresented: $showEMICalculator) {
                EMICalculatorView()
            }
            .sheet(isPresented: $showNotifications, onDismiss: {
                Task { unreadCount = (try? await SupabaseManager.shared.fetchUnreadNotificationCount()) ?? 0 }
            }) {
                NotificationView()
            }
            .sheet(isPresented: $showApplyForm) {
                LoanApplicationFormView()
            }
            .task {
                do {
                    async let apps = SupabaseManager.shared.fetchMyApplications()
                    async let loans = SupabaseManager.shared.fetchActiveLoans()
                    let (fetched, active) = try await (apps, loans)
                    activeLoans = active

                    fetchedApplications = fetched.map { app in
                        guard let appId = app.id else { return app }
                        if let activeLoan = active.first(where: { $0.applicationId == appId }) {

                            if app.status == .submitted || app.status == .underReview || app.status == .recommended {
                                return app.withStatus(activeLoan.outstandingBalance > 0 ? .approved : .approved)
                            }
                        }
                        return app
                    }
                    unreadCount = (try? await SupabaseManager.shared.fetchUnreadNotificationCount()) ?? 0
                } catch {
                    print("Error: \(error)")
                }
            }
            .refreshable {
                do {
                    async let apps = SupabaseManager.shared.fetchMyApplications()
                    async let loans = SupabaseManager.shared.fetchActiveLoans()
                    let (fetched, active) = try await (apps, loans)
                    activeLoans = active
                    fetchedApplications = fetched.map { app in
                        guard let appId = app.id else { return app }
                        if active.first(where: { $0.applicationId == appId }) != nil {
                            if app.status == .submitted || app.status == .underReview || app.status == .recommended {
                                return app.withStatus(.approved)
                            }
                        }
                        return app
                    }
                    unreadCount = (try? await SupabaseManager.shared.fetchUnreadNotificationCount()) ?? 0
                } catch {
                    print("Error: \(error)")
                }
            }
        }
    }
}

// MARK: - Updated Apply Now Banner
struct ApplyNowBanner: View {
    @Binding var showApplyForm: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ready to grow?")
                    .font(.footnote)
                    .foregroundStyle(Color.theme.textSecondary)
                Text("Apply for a Loan")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(Color.theme.textPrimary)

                Button {
                    showApplyForm = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Apply Now").fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline).foregroundStyle(Color.theme.primaryText)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.theme.primaryAccent).clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            Spacer()
            Image(systemName: "briefcase.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.theme.primaryAccent.opacity(0.15))
        }
        .padding(20)
        .cardStyle()
    }
}

// MARK: - EMI Calculator Banner
struct EMICalculatorBanner: View {
    @Binding var showCalculator: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.theme.primaryAccent.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "plus.forwardslash.minus")
                    .font(.title3)
                    .foregroundStyle(Color.theme.primaryAccent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Plan your future")
                    .font(.footnote)
                    .foregroundStyle(Color.theme.textSecondary)
                Text("EMI Calculator")
                    .font(.headline)
                    .foregroundStyle(Color.theme.textPrimary)
            }

            Spacer()

            Button {
                showCalculator = true
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.theme.textSecondary)
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Row View
struct ApplicationRowView: View {
    let application: LoanApplication

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(application.status.color.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: application.status.icon).font(.subheadline).foregroundStyle(application.status.color)
            }
            .fixedSize()

            VStack(alignment: .leading, spacing: 3) {
                Text(application.purpose)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.theme.textPrimary)
                    .lineLimit(1)

                Text("Recent")
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.textSecondary)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("₹\(Int(application.loanAmount).formatted())")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.theme.textPrimary)
                    .lineLimit(1)
                StatusBadge(status: application.status)
            }
            .fixedSize(horizontal: true, vertical: false)

            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.gray.opacity(0.3))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - EMI Calculator View
struct EMICalculatorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var principal: Double = 500000
    @State private var rate: Double = 12.0
    @State private var tenure: Double = 6 
    @State private var loanType: String = "Personal"
    @State private var processingFee: Double = 1.0

    let maxPrincipal: Double = 10000000 
    let loanTypes = ["Personal", "Home", "Education", "Vehicle"]

    var computedEMI: Double {
        let p = min(principal, maxPrincipal)
        let r = (rate / 100.0) / 12.0
        let n = tenure
        if r == 0 { return p / n }
        let num = p * r * pow(1 + r, n)
        let den = pow(1 + r, n) - 1
        return num / den
    }

    var totalInterest: Double {
        let n = tenure
        return (computedEMI * n) - min(principal, maxPrincipal)
    }

    var totalPayable: Double {
        return computedEMI * tenure
    }

    var processingFeeAmount: Double {
        return (min(principal, maxPrincipal) * processingFee) / 100.0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    VStack(spacing: 8) {
                        Text("Estimated Monthly EMI")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.theme.textSecondary)
                        Text("₹\(Int(computedEMI).formatted())")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundStyle(Color.theme.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: computedEMI)

                        Text("Estimated Monthly EMI")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.theme.textSecondary)

                        HStack(spacing: 12) {
                            SummarySmallCard(title: "Total Interest", value: "₹\(Int(totalInterest).formatted())", color: Color.theme.textPrimary)
                            SummarySmallCard(title: "Total Payable", value: "₹\(Int(totalPayable).formatted())", color: Color.theme.primaryAccent)
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Loan Details")

                        CardView {
                            VStack(spacing: 0) {

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Loan Type").font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.theme.textPrimary)
                                    HStack(spacing: 8) {
                                        ForEach(loanTypes, id: \.self) { type in
                                            Button {
                                                loanType = type
                                            } label: {
                                                Text(type)
                                                    .font(.caption).fontWeight(.bold)
                                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                                    .background(loanType == type ? Color.theme.primaryAccent : Color.gray.opacity(0.1))
                                                    .foregroundColor(loanType == type ? Color.theme.primaryText : Color.theme.textSecondary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 18)

                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                TextInputRow(label: "Loan Amount", value: $principal)
                                    .onChange(of: principal) { oldValue, newValue in
                                        if newValue > maxPrincipal {
                                            principal = maxPrincipal
                                        }
                                    }

                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Interest Rate").font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.theme.textPrimary)
                                        Spacer()
                                        Text("\(String(format: "%.1f", rate))%").font(.subheadline).fontWeight(.bold).foregroundStyle(Color.theme.primaryAccent)
                                    }

                                    HStack(spacing: 8) {
                                        ForEach([8.0, 10.0, 12.0, 15.0, 18.0], id: \.self) { preset in
                                            Button {
                                                withAnimation(.spring()) {
                                                    rate = preset
                                                }
                                            } label: {
                                                Text("\(Int(preset))%")
                                                    .font(.caption).fontWeight(.bold)
                                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                                    .background(rate == preset ? Color.theme.primaryAccent : Color.gray.opacity(0.1))
                                                    .foregroundColor(rate == preset ? Color.theme.primaryText : Color.theme.textSecondary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Slider(value: $rate, in: 6...30, step: 0.5).tint(Color.theme.primaryAccent)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 18)

                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                SliderInputRow(label: "Tenure", value: $tenure, min: 6, max: 360, step: 6, formatted: "\(Int(tenure)) Mo")

                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                SliderInputRow(label: "Processing Fee", value: $processingFee, min: 0, max: 5, step: 0.5, formatted: "\(String(format: "%.1f", processingFee))%")
                            }
                        }

                        HStack {
                            Image(systemName: "info.circle")
                            Text("Estimated Processing Fee: ₹\(Int(processingFeeAmount).formatted())")
                        }
                        .font(.caption)
                        .foregroundColor(Color.theme.textSecondary)
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color.theme.appBackground.ignoresSafeArea())
            .navigationTitle("EMI Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { 
                ToolbarItem(placement: .topBarTrailing) { 
                    Button("Done") { 
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        dismiss() 
                    }
                    .foregroundStyle(Color.theme.primaryAccent) 
                } 
            }
        }
    }
}

// MARK: - New Helper Components
struct SummarySmallCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.theme.textSecondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Helper Components
struct TextInputRow: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(label).font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.theme.textPrimary)
                Spacer()
                HStack(spacing: 2) {
                    Text("₹").font(.subheadline).fontWeight(.bold).foregroundStyle(Color.theme.primaryAccent)
                    TextField("Amount", value: $value, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.theme.primaryAccent)
                        .frame(minWidth: 50, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
    }
}

struct SliderInputRow: View {
    let label: String
    @Binding var value: Double
    let min: Double; let max: Double; let step: Double
    let formatted: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(label).font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.theme.textPrimary)
                Spacer()
                Text(formatted).font(.subheadline).fontWeight(.bold).foregroundStyle(Color.theme.primaryAccent)
            }
            Slider(value: $value, in: min...max, step: step).tint(Color.theme.primaryAccent)
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
    }
}
