import SwiftUI

struct LoansView: View {
    @Binding var selectedSegment: LoanSegment
    @Bindable var controller: LoansViewModel
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        let totalPortfolioValue: Double = {
            guard let card = controller.portfolioSummaryCards.first(where: { $0.title.contains("Portfolio") }) else {
                return 0
            }
            let clean = card.value
                .replacingOccurrences(of: "₹", with: "")
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespaces)

            if clean.hasSuffix("Cr") {
                return (Double(clean.dropLast(2)) ?? 0) * 10_000_000
            } else if clean.hasSuffix("L") {
                return (Double(clean.dropLast(1)) ?? 0) * 100_000
            }
            return Double(clean) ?? 0
        }()
        
        VStack(spacing: 0) {
            Picker("Segment", selection: $selectedSegment) {
                ForEach(LoanSegment.allCases, id: \.self) { seg in
                    Text(seg.rawValue).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, sizeClass == .compact ? 20 : 32)
            .padding(.top, 16)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 24) {
                    switch selectedSegment {
                    case .loanProduct: ManagerLoanProductsView(
                        loanProducts: controller.loanProducts,
                        distribution: controller.loanDistribution,
                        totalPortfolioValue: totalPortfolioValue,
                        competitiveRates: controller.competitiveRates,
                        isEmbedded: true
                    )
                    case .risk:      RiskDefaultsView(controller: controller)
                    case .officers:  LoanOfficersView(controller: controller)
                    }
                }
                .padding(.horizontal, sizeClass == .compact ? 20 : 32)
                .padding(.bottom, 28)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Loans")
    }
}

#Preview {
    NavigationStack {
        LoansView(selectedSegment: .constant(.loanProduct), controller: LoansViewModel())
    }
}