

import AppIntents

struct LMSShortcutsProvider: AppShortcutsProvider {

    static var shortcutTileColor: ShortcutTileColor { .blue }

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {

        // MARK: Intent A — Next EMI
        AppShortcut(
            intent: CheckNextEMIIntent(),
            phrases: [
                "When is my next payment due in \(.applicationName)",
                "What is my next EMI in \(.applicationName)",
                "Show upcoming EMI in \(.applicationName)",
                "Next EMI in \(.applicationName)"
            ],

            shortTitle: LocalizedStringResource("Next EMI"),
            systemImageName: "calendar.badge.clock"
        )

        // MARK: Intent B — Outstanding Balance
        AppShortcut(
            intent: CheckOutstandingBalanceIntent(),
            phrases: [
                "How much do I owe \(.applicationName)",
                "What is my loan balance in \(.applicationName)",
                "Check outstanding balance in \(.applicationName)",
                "My loan balance in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Loan Balance"),
            systemImageName: "indianrupeesign.circle"
        )

        // MARK: Intent C — Application Status
        AppShortcut(
            intent: CheckLoanStatusIntent(),
            phrases: [
                "Check my loan status in \(.applicationName)",
                "What is the status of my loan in \(.applicationName)",
                "Is my loan approved in \(.applicationName)",
                "Loan application status in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Loan Status"),
            systemImageName: "doc.text.magnifyingglass"
        )
    }
}
