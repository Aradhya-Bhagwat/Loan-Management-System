import SwiftUI

struct ManagerLoanProductsView: View {
    let loanProducts: [LoanProduct]
    let distribution: [LoanDistribution]
    let totalPortfolioValue: Double
    let competitiveRates: [CompetitiveRate]
    var isEmbedded: Bool = false

    var body: some View {
        Group {
            if isEmbedded {
                content
            } else {
                ScrollView {
                    content
                }
                .background(Color.appBackground.ignoresSafeArea())
                .navigationTitle("Loan Products")
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        LazyVStack(spacing: 20) {
                ForEach(loanProducts) { product in
                    let dist = distribution.first {
                        product.name.localizedCaseInsensitiveContains($0.type)
                    }

                    LoanProductCell(
                        product: product,
                        distribution: dist,
                        totalPortfolioValue: totalPortfolioValue,
                        competitiveRates: competitiveRates
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
    }
}

#Preview {
    NavigationStack {
        ManagerLoanProductsView(
            loanProducts: [],
            distribution: [],
            totalPortfolioValue: 0,
            competitiveRates: []
        )
    }
}

// MARK: - CELL (UPDATED)

struct LoanProductCell: View {
    let product: LoanProduct
    let distribution: LoanDistribution?
    let totalPortfolioValue: Double
    let competitiveRates: [CompetitiveRate]

    private func amount() -> Double? {
        guard let pct = distribution?.percentage else { return nil }
        return totalPortfolioValue * (pct / 100.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(product.name)
                    .font(.system(size: 20, weight: .bold))
                
                Spacer()
                
                NavigationLink {
                    ManagerLoanProductEditView(
                        product: product,
                        competitiveRates: competitiveRates
                    )
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.appSecondary)
                        .foregroundStyle(Color.appGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(spacing: 12) {
                parameterRow(title: "Portfolio Share", value: portfolioShareText())
                parameterRow(title: "Interest Rate", value: "\(String(format: "%.1f", product.managerRate ?? product.baseRate))%")
                parameterRow(title: "Processing Fee", value: "\(String(format: "%.1f", product.managerProcessingFee ?? product.processingFee))%")
                parameterRow(title: "Tenure Limit", value: "\(product.managerMaxTenureMonths ?? product.maxTenureMonths) months")
                parameterRow(title: "Amount Limit", value: formatCurrency(product.managerMaxAmount ?? product.maxAmount))
            }
        }
        .cardStyle()
    }
    
    private func portfolioShareText() -> String {
        if let amt = amount() {
            return "\(formatCurrency(amt)) (\(Int(distribution?.percentage ?? 0))%)"
        }
        return "₹0 (0%)"
    }
    
    private func parameterRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
}



// MARK: - EDIT VIEW

struct ManagerLoanProductEditView: View {
    @State private var product: LoanProduct
    let competitiveRates: [CompetitiveRate]
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authController

    private var marketData: CompetitiveRate? {
        competitiveRates.first { $0.productType == product.name }
    }

    init(product: LoanProduct, competitiveRates: [CompetitiveRate]) {
        var p = product
        p.managerRate = p.managerRate ?? p.baseRate
        p.managerProcessingFee = p.managerProcessingFee ?? p.processingFee
        p.managerMinTenureMonths = p.managerMinTenureMonths ?? p.minTenureMonths
        p.managerMaxTenureMonths = p.managerMaxTenureMonths ?? p.maxTenureMonths
        p.managerMinAmount = p.managerMinAmount ?? p.minAmount
        p.managerMaxAmount = p.managerMaxAmount ?? p.maxAmount
        self._product = State(initialValue: p)
        self.competitiveRates = competitiveRates
    }

    var body: some View {
        List {
            Section("Interest Rate") {
                sliderSetting(
                    title: "Rate",
                    value: Binding(
                        get: { product.managerRate ?? product.baseRate },
                        set: { product.managerRate = $0 }
                    ),
                    range: product.baseRate...product.maxRate,
                    step: 0.1,
                    suffix: "%",
                    marketMin: marketData?.rateMin,
                    marketAvg: marketData?.rateAvg,
                    marketMax: marketData?.rateMax
                )
            }

            Section("Processing Fee") {
                sliderSetting(
                    title: "Fee",
                    value: Binding(
                        get: { product.managerProcessingFee ?? product.processingFee },
                        set: { product.managerProcessingFee = $0 }
                    ),
                    range: 0...(product.processingFee > 0 ? product.processingFee : 10),
                    step: 0.1,
                    suffix: "%",
                    marketMin: marketData?.feeMin,
                    marketAvg: marketData?.feeAvg,
                    marketMax: marketData?.feeMax
                )
            }

            Section("Tenure Limit") {
                sliderSetting(
                    title: "Max Tenure",
                    value: Binding(
                        get: { Double(product.managerMaxTenureMonths ?? product.maxTenureMonths) },
                        set: { product.managerMaxTenureMonths = Int($0) }
                    ),
                    range: Double(product.minTenureMonths)...Double(product.maxTenureMonths),
                    step: 1,
                    suffix: "months",
                    marketMin: marketData.map { Double($0.tenureMin) },
                    marketAvg: marketData.map { Double($0.tenureAvg) },
                    marketMax: marketData.map { Double($0.tenureMax) }
                )
            }

            Section("Amount Limit") {
                sliderSetting(
                    title: "Max Amount",
                    value: Binding(
                        get: { product.managerMaxAmount ?? product.maxAmount },
                        set: { product.managerMaxAmount = $0 }
                    ),
                    range: product.minAmount...product.maxAmount,
                    step: 1000,
                    suffix: "₹",
                    marketMin: marketData?.amountMin,
                    marketAvg: marketData?.amountAvg,
                    marketMax: marketData?.amountMax
                )
            }
            
            Section("Eligibility Criteria") {
                TextEditor(text: $product.eligibilityRules)
                    .frame(minHeight: 120)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Parameters")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    save()
                }

                .disabled(isSaving)
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true

        Task {
            await DatabaseService.shared.saveLoanProduct(product)
            await DatabaseService.shared.logAudit(
                title: "Loan Product Updated: \(product.name)",
                actor: "Manager",
                category: "Configuration",
                status: "Completed",
                icon: "briefcase.fill",
                color: "green",
                branch: authController.currentUser?.branch
            )
            dismiss()
        }
    }

    private func sliderSetting(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String,
        marketMin: Double? = nil,
        marketAvg: Double? = nil,
        marketMax: Double? = nil
    ) -> some View {

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                if suffix == "₹" {
                    Text("\(formatCurrency(value.wrappedValue))")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Text("\(formatted(value.wrappedValue, step: step)) \(suffix)")
                        .font(.system(size: 16, weight: .semibold))
                }
            }

            Slider(value: value, in: range, step: step).tint(.appGreen)

            HStack {
                if suffix == "₹" {
                    Text(formatCurrency(range.lowerBound))
                    Spacer()
                    Text(formatCurrency(range.upperBound))
                } else {
                    Text(formatted(range.lowerBound, step: step))
                    Spacer()
                    Text(formatted(range.upperBound, step: step))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if let mMin = marketMin, let mAvg = marketAvg, let mMax = marketMax {
                Divider().padding(.vertical, 8)
                let formattedSuffix = suffix == "%" ? suffix : (suffix == "₹" ? "" : " " + suffix)
                marketReferenceRow(
                    min: suffix == "₹" ? formatCurrency(mMin) : formatted(mMin, step: step) + formattedSuffix,
                    avg: suffix == "₹" ? formatCurrency(mAvg) : formatted(mAvg, step: step) + formattedSuffix,
                    max: suffix == "₹" ? formatCurrency(mMax) : formatted(mMax, step: step) + formattedSuffix
                )
            }
        }
        .padding(.vertical, 6)
    }
    
    private func marketReferenceRow(min: String, avg: String, max: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Market Reference")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 0) {
                marketValueColumn(label: "Min", value: min, alignment: .leading)
                Spacer()
                marketValueColumn(label: "Avg", value: avg, alignment: .center)
                Spacer()
                marketValueColumn(label: "Max", value: max, alignment: .trailing)
            }
            .padding(12)
            .background(Color.appSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 4)
    }
        
    private func marketValueColumn(label: String, value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }

    private func formatted(_ value: Double, step: Double) -> String {
        String(format: step < 1 ? "%.1f" : "%.0f", value)
    }
}