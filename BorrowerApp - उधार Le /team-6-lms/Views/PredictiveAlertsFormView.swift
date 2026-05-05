import SwiftUI
import Supabase

struct PredictiveAlertsFormView: View {
    @Environment(\.dismiss) var dismiss

    // MARK: - User-only inputs (cannot be derived from backend)
    @State private var essentialExpenses: String = ""
    @State private var nonEssentialExpenses: String = ""
    @State private var currentBalance: String = ""
    @State private var salaryDate: Int = 1
    @State private var incomeStability: String = "Fixed"

    // MARK: - Auto-fetched from Supabase (displayed read-only)
    @State private var fetchedIncome: Double = 0
    @State private var fetchedEMIAmount: Double = 0
    @State private var fetchedEMIDueDate: Date = Date()
    @State private var fetchedEMIHistory: String = "Paid on time"
    @State private var fetchedDelayDays: Int = 0
    @State private var fetchedTotalEMI: Double = 0
    @State private var fetchedNumLoans: Int = 0
    @State private var fetchedMissedPayments: Int = 0
    @State private var fetchedCreditScore: Int = 0
    @State private var fetchedCreditTrend: String = "Stable"

    // MARK: - UI state
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil

    let stabilityOptions = ["Fixed", "Variable"]

    // MARK: - Validation
    private var canSubmit: Bool {
        !essentialExpenses.isEmpty && !nonEssentialExpenses.isEmpty && !currentBalance.isEmpty
    }

    private var totalExpenses: Double {
        (Double(essentialExpenses) ?? 0) + (Double(nonEssentialExpenses) ?? 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.appBackground.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(Color.theme.primaryAccent)
                        Text("Fetching your profile data...")
                            .font(.subheadline)
                            .foregroundStyle(Color.theme.textSecondary)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {

                            // MARK: - Info Banner
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                    .foregroundStyle(Color.theme.primaryAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Smart Pre-fill Active")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.theme.textPrimary)
                                    Text("Your loan & income data has been loaded automatically. Just fill in the 3 missing fields below.")
                                        .font(.caption)
                                        .foregroundStyle(Color.theme.textSecondary)
                                }
                            }
                            .padding(16)
                            .background(Color.theme.successBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                            // MARK: - Required Inputs
                            SectionHeader(title: "YOUR DETAILS NEEDED")
                            CardView {
                                VStack(spacing: 0) {

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Essential Spending")
                                                .font(.subheadline).fontWeight(.semibold)
                                                .foregroundStyle(Color.theme.textPrimary)
                                            Text("*")
                                                .foregroundStyle(Color.theme.danger)
                                            Spacer()
                                            TextField("e.g. 20000", text: $essentialExpenses)
                                                .keyboardType(.numberPad)
                                                .multilineTextAlignment(.trailing)
                                                .font(.system(.subheadline, design: .rounded).bold())
                                                .foregroundStyle(Color.theme.primaryAccent)
                                        }
                                        Text("Rent, groceries, utilities, transport, medicine.")
                                            .font(.caption2)
                                            .foregroundStyle(Color.theme.textSecondary)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)

                                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Non-Essential Spending")
                                                .font(.subheadline).fontWeight(.semibold)
                                                .foregroundStyle(Color.theme.textPrimary)
                                            Text("*")
                                                .foregroundStyle(Color.theme.danger)
                                            Spacer()
                                            TextField("e.g. 8000", text: $nonEssentialExpenses)
                                                .keyboardType(.numberPad)
                                                .multilineTextAlignment(.trailing)
                                                .font(.system(.subheadline, design: .rounded).bold())
                                                .foregroundStyle(Color.theme.primaryAccent)
                                        }
                                        Text("Dining out, subscriptions, shopping, entertainment.")
                                            .font(.caption2)
                                            .foregroundStyle(Color.theme.textSecondary)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)

                                    if !essentialExpenses.isEmpty || !nonEssentialExpenses.isEmpty {
                                        Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                        HStack {
                                            Text("Total Monthly Spending")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.theme.textSecondary)
                                            Spacer()
                                            Text("₹\(Int(totalExpenses).formatted())")
                                                .font(.system(.subheadline, design: .rounded).bold())
                                                .foregroundStyle(Color.theme.textPrimary)
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 12)
                                    }

                                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Current Balance")
                                                .font(.subheadline).fontWeight(.semibold)
                                                .foregroundStyle(Color.theme.textPrimary)
                                            Text("*")
                                                .foregroundStyle(Color.theme.danger)
                                            Spacer()
                                            TextField("e.g. 15000", text: $currentBalance)
                                                .keyboardType(.numberPad)
                                                .multilineTextAlignment(.trailing)
                                                .font(.system(.subheadline, design: .rounded).bold())
                                                .foregroundStyle(Color.theme.primaryAccent)
                                        }
                                        Text("Your bank account balance right now.")
                                            .font(.caption2)
                                            .foregroundStyle(Color.theme.textSecondary)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)

                                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                    HStack {
                                        Text("Salary Credit Date")
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(Color.theme.textPrimary)
                                        Spacer()
                                        Picker("Salary Date", selection: $salaryDate) {
                                            ForEach(1...31, id: \.self) { day in
                                                Text("\(day)").tag(day)
                                            }
                                        }
                                        .tint(Color.theme.primaryAccent)
                                        .pickerStyle(.menu)
                                        .dismissKeyboardOnPickerTap()
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)

                                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                    HStack {
                                        Text("Income Type")
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(Color.theme.textPrimary)
                                        Spacer()
                                        Picker("Income Stability", selection: $incomeStability) {
                                            ForEach(stabilityOptions, id: \.self) { option in
                                                Text(option).tag(option)
                                            }
                                        }
                                        .tint(Color.theme.primaryAccent)
                                        .pickerStyle(.segmented)
                                        .frame(width: 150)
                                        .dismissKeyboardOnPickerTap()
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                }
                            }

                            // MARK: - Auto-fetched preview
                            SectionHeader(title: "FETCHED FROM YOUR PROFILE")
                            CardView {
                                VStack(spacing: 0) {
                                    ReadOnlyRow(
                                        title: "Monthly Income",
                                        icon: "indianrupeesign.circle.fill",
                                        value: fetchedIncome > 0 ? "₹\(Int(fetchedIncome).formatted())" : "Not found",
                                        isFound: fetchedIncome > 0
                                    )
                                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                    ReadOnlyRow(
                                        title: "Credit Score",
                                        icon: "chart.bar.fill",
                                        value: fetchedCreditScore > 0 ? "\(fetchedCreditScore) (\(fetchedCreditTrend))" : "Not found",
                                        isFound: fetchedCreditScore > 0
                                    )
                                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                    ReadOnlyRow(
                                        title: "Next EMI",
                                        icon: "calendar.badge.clock",
                                        value: fetchedEMIAmount > 0 ? "₹\(Int(fetchedEMIAmount).formatted())" : "No active EMI",
                                        isFound: fetchedEMIAmount > 0
                                    )
                                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                    ReadOnlyRow(
                                        title: "Active Loans",
                                        icon: "creditcard.fill",
                                        value: "\(fetchedNumLoans) loan\(fetchedNumLoans == 1 ? "" : "s")",
                                        isFound: fetchedNumLoans > 0
                                    )
                                    Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                    ReadOnlyRow(
                                        title: "Payment History",
                                        icon: "checkmark.seal.fill",
                                        value: fetchedEMIHistory,
                                        isFound: fetchedEMIHistory == "Paid on time"
                                    )
                                }
                            }

                            if let err = errorMessage {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(Color.theme.danger)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                            }

                            // MARK: - Submit Button
                            Button(action: {
                                Task { await submitData() }
                            }) {
                                ZStack {
                                    Text("Run Predictive Analysis")
                                        .fontWeight(.bold)
                                        .foregroundStyle(canSubmit ? Color.theme.primaryText : Color.theme.textSecondary.opacity(0.8))
                                        .opacity(isSubmitting ? 0 : 1)
                                    if isSubmitting {
                                        ProgressView().tint(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canSubmit ? Color.theme.primaryAccent : Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                            }
                            .disabled(!canSubmit || isSubmitting)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .dismissKeyboardOnTap()
                }
            }
            .navigationTitle("Predictive Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.theme.primaryAccent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .task {
                await fetchAllData()
            }
            .alert("Analysis Started! 🎉", isPresented: $showSuccess) {
                Button("Got it") { dismiss() }
            } message: {
                Text("Your predictive alerts will update based on your financial data.")
            }
        }
    }

    // MARK: - Fetch all auto-fillable data from Supabase
    private func fetchAllData() async {
        isLoading = true
        defer { isLoading = false }

        do {

            if let emp = try? await SupabaseManager.shared.fetchEmployment() {
                fetchedIncome = emp.monthlyIncome
            }

            if let borrower = try? await SupabaseManager.shared.fetchCurrentBorrower() {
                fetchedCreditScore = borrower.creditScore
                if borrower.creditScore >= 750 {
                    fetchedCreditTrend = "Up"
                } else if borrower.creditScore >= 650 {
                    fetchedCreditTrend = "Stable"
                } else {
                    fetchedCreditTrend = "Down"
                }

                if fetchedIncome == 0, let declared = borrower.declaredMonthlyIncome {
                    fetchedIncome = declared
                }
            }

            let activeLoans = (try? await SupabaseManager.shared.fetchActiveLoans()) ?? []
            fetchedNumLoans = activeLoans.count

            let schedule = (try? await SupabaseManager.shared.fetchEMISchedule()) ?? []

            let upcomingEMIs = schedule.filter { $0.status.lowercased() == "upcoming" }
            let paidEMIs = schedule.filter { $0.status.lowercased() == "paid" }
            let missedEMIs = schedule.filter { $0.status.lowercased() == "missed" || $0.status.lowercased() == "overdue" }

            fetchedMissedPayments = missedEMIs.count

            if let nextEMI = upcomingEMIs.first {
                fetchedEMIAmount = nextEMI.amount
                fetchedTotalEMI = upcomingEMIs.reduce(0) { $0 + $1.amount }
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                if let d = fmt.date(from: nextEMI.dueDate) {
                    fetchedEMIDueDate = d
                }
            } else if !schedule.isEmpty {

                fetchedEMIAmount = schedule.first?.amount ?? 0
                fetchedTotalEMI = schedule.reduce(0) { $0 + $1.amount }
            }

            if fetchedMissedPayments > 0 {
                fetchedEMIHistory = "Missed"
                fetchedDelayDays = 0
            } else if let lastPaid = paidEMIs.last {

                fetchedEMIHistory = "Paid on time"
                _ = lastPaid 
            } else {
                fetchedEMIHistory = "Paid on time"
            }

        }
    }

    // MARK: - Submit combined data to Supabase RPC
    private func submitData() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]

            let essential = Double(essentialExpenses) ?? 0
            let nonEssential = Double(nonEssentialExpenses) ?? 0
            let expenses = essential + nonEssential
            let balance = Double(currentBalance) ?? 0

            let params: [String: AnyJSON] = [
                "p_monthly_income": .double(fetchedIncome),
                "p_salary_date": .integer(salaryDate),
                "p_income_stability": .string(incomeStability),
                "p_monthly_expenses": .double(expenses),
                "p_essential_expenses": .double(essential),
                "p_non_essential_expenses": .double(nonEssential),
                "p_current_balance": .double(balance),
                "p_avg_balance_30d": .double(balance),       
                "p_balance_before_emi": .double(balance),    
                "p_emi_amount": .double(fetchedEMIAmount),
                "p_emi_due_date": .string(formatter.string(from: fetchedEMIDueDate)),
                "p_emi_history": .string(fetchedEMIHistory),
                "p_delay_days": .integer(fetchedDelayDays),
                "p_total_emi": .double(fetchedTotalEMI),
                "p_num_loans": .integer(fetchedNumLoans),
                "p_missed_payments": .integer(fetchedMissedPayments),
                "p_credit_score_trend": .string(fetchedCreditTrend),
                "p_late_payment_freq": .integer(fetchedMissedPayments),
                "p_payment_just_before_due": .bool(false),
                "p_partial_payments": .bool(false)
            ]

            try await SupabaseManager.shared.client
                .rpc("save_and_run_prediction", params: params)
                .execute()

            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Read-Only Display Row
private struct ReadOnlyRow: View {
    let title: String
    let icon: String
    let value: String
    let isFound: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(isFound ? Color.theme.primaryAccent : Color.theme.textSecondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(isFound ? Color.theme.textPrimary : Color.theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    PredictiveAlertsFormView()
}
