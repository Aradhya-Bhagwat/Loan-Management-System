import SwiftUI

@Observable
class AppRouter {
    static let shared = AppRouter()

    var selectedTab: Int = 0
    var loansSegment: LoanSegment = .loanProduct

    private init() {}

    func navigateToLoansRisk() {
        loansSegment = .risk
        selectedTab = 1
    }
}