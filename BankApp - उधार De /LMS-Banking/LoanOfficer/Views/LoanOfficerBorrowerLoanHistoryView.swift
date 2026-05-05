//
//  LoanOfficerBorrowerLoanHistoryView.swift
//  LMS-Banking
//
//  Created by Shivani Dinesh on 21/04/26.
//

import SwiftUI

// MARK: - Summary Card (embeds in LoanDetailScreen)

/// Drop this card into `LoanDetailScreen`'s VStack alongside the other detail cards.
///
/// Usage in LoanDetailScreen:
///   BorrowerLoanHistoryCard(loan: loan) { showLoanHistory = true }
struct BorrowerLoanHistoryCard: View {
    let loan: LoanCase

    @State private var history: [DBLoanApplication] = []
    @State private var isLoading = true
    @State private var selectedRecord: DBLoanApplication?
    @State private var showDetailSheet = false

    var body: some View {
        WhiteCard {
            VStack(alignment: .leading, spacing: 16) {                // ── Credit history snapshot from DBCreditProfile ─────────
                if let profile = loan.creditProfile {
                    HStack(spacing: 12) {

                        HistoryMetricPill(
                            icon: "exclamationmark.triangle",
                            label: "Missed Payments",
                            value: profile.missedPayments != nil
                                ? "\(profile.missedPayments!)"
                                : "—",
                            tint: (profile.missedPayments ?? 0) > 2
                                ? OfficerTheme.iconRed
                                : OfficerTheme.iconAmber
                        )
                    }

                    Divider().overlay(OfficerTheme.softLine)
                }

                // ── Loan history rows ────────────────────────────────────
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(OfficerTheme.accentBlue)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else if history.isEmpty {
                    NoHistoryPlaceholder()
                } else {
                    VStack(spacing: 0) {
                        ForEach(history) { record in
                            LoanHistoryRow(application: record, currentLoanId: loan.id) {
                                selectedRecord = record
                                showDetailSheet = true
                            }
                            if record.id != history.last?.id {
                                Divider()
                                    .overlay(OfficerTheme.softLine)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let record = selectedRecord {
                LoanHistoryDetailSheet(application: record)
            }
        }
        .task {
            await loadHistory()
        }
    }

    private func loadHistory() async {
        guard let borrowerId = loan.application.borrowerId else {
            await MainActor.run { isLoading = false }
            return
        }
        do {
            let records = try await DatabaseService.shared.fetchBorrowerLoanHistory(borrowerId: borrowerId)
            await MainActor.run {
                self.history = records
                self.isLoading = false
            }
        } catch {
            print("Error loading loan history: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Full History Screen

/// Push this screen via NavigationLink / navigationDestination
/// when the user taps "View Full History" in BorrowerLoanHistoryCard.
struct BorrowerLoanHistoryScreen: View {
    let loan: LoanCase
    @Environment(\.dismiss) private var dismiss

    @State private var history: [DBLoanApplication] = []
    @State private var isLoading = true
    @State private var selectedRecord: DBLoanApplication?
    @State private var showDetailSheet = false

    var body: some View {
        ZStack {
            OfficerTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Borrower mini-header ─────────────────────────────
                    WhiteCard {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(OfficerTheme.accentBlue.opacity(0.12))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Text(loan.borrower.initials)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(OfficerTheme.accentBlue)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(loan.borrower.displayName)
                                    .font(.system(size: 17, weight: .bold))
                                Text("Loan Application History")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                            }

                            Spacer()

                            // CIBIL score badge
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("CIBIL")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                                Text("\(loan.creditScore)")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(loan.riskLevel == .low
                                        ? OfficerTheme.iconGreen
                                        : loan.riskLevel == .medium
                                            ? OfficerTheme.iconAmber
                                            : OfficerTheme.iconRed)
                            }
                        }
                    }

                    // ── Credit summary stats ─────────────────────────────
                    if let profile = loan.creditProfile {
                        CreditSummarySection(profile: profile)
                    }

                    // ── Loan applications list ───────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ALL APPLICATIONS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(OfficerTheme.textSecondary)
                            .padding(.top, 4)

                        if isLoading {
                            WhiteCard {
                                HStack {
                                    Spacer()
                                    ProgressView("Loading history…")
                                        .tint(OfficerTheme.accentBlue)
                                    Spacer()
                                }
                                .padding(.vertical, 30)
                            }
                        } else if history.isEmpty {
                            WhiteCard {
                                NoHistoryPlaceholder()
                            }
                        } else {
                            ForEach(history) { record in
                                ExpandedLoanHistoryCard(
                                    application: record,
                                    currentLoanId: loan.id
                                ) {
                                    selectedRecord = record
                                    showDetailSheet = true
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let record = selectedRecord {
                LoanHistoryDetailSheet(application: record)
            }
        }
        .navigationTitle("Loan History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadHistory()
        }
    }

    private func loadHistory() async {
        guard let borrowerId = loan.application.borrowerId else {
            await MainActor.run { isLoading = false }
            return
        }
        do {
            let records = try await DatabaseService.shared.fetchBorrowerLoanHistory(borrowerId: borrowerId)
            await MainActor.run {
                self.history = records
                self.isLoading = false
            }
        } catch {
            print("Error loading loan history: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Credit Summary Section

private struct CreditSummarySection: View {
    let profile: DBCreditProfile

    var body: some View {
        WhiteCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OfficerTheme.accentBlue)
                    Text("Credit Summary")
                        .font(.system(size: 16, weight: .bold))
                }

                HStack(spacing: 12) {
                    SummaryStatBox(
                        label: "Credit Score",
                        value: profile.creditScore != nil ? "\(profile.creditScore!)" : "—",
                        tint: scoreColor(profile.creditScore ?? 0)
                    )

                    SummaryStatBox(
                        label: "Missed Payments",
                        value: profile.missedPayments != nil ? "\(profile.missedPayments!)" : "—",
                        tint: (profile.missedPayments ?? 0) > 2
                            ? OfficerTheme.iconRed : OfficerTheme.iconAmber
                    )
                }

                if let utilization = profile.creditUtilization {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Credit Utilization")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary)
                            Spacer()
                            Text(String(format: "%.0f%%", utilization))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(utilizationColor(utilization))
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(OfficerTheme.filterBackground)
                                    .frame(height: 6)
                                Capsule()
                                    .fill(utilizationColor(utilization))
                                    .frame(width: proxy.size.width * min(utilization / 100, 1), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 750 { return OfficerTheme.iconGreen }
        if score >= 680 { return OfficerTheme.iconAmber }
        return OfficerTheme.iconRed
    }

    private func utilizationColor(_ pct: Double) -> Color {
        if pct <= 30 { return OfficerTheme.iconGreen }
        if pct <= 60 { return OfficerTheme.iconAmber }
        return OfficerTheme.iconRed
    }
}

// MARK: - Loan History Row (compact, for summary card preview)

private struct LoanHistoryRow: View {
    let application: DBLoanApplication
    let currentLoanId: UUID
    var onTap: () -> Void

    private var isCurrentLoan: Bool { application.id == currentLoanId }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: purposeIcon(application.purpose ?? ""))
                .font(.system(size: 16))
                .foregroundStyle(isCurrentLoan ? OfficerTheme.accentGreen : OfficerTheme.textSecondary)
                .frame(width: 38, height: 38)
                .background(isCurrentLoan ? OfficerTheme.accentGreen.opacity(0.1) : OfficerTheme.filterBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(application.purpose ?? "Loan Application")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OfficerTheme.textPrimary)
                    if isCurrentLoan {
                        Text("CURRENT")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(OfficerTheme.accentGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(OfficerTheme.accentGreen.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text("\(CurrencyFormatter.indian(application.loanAmount)) · \(application.tenureMonths) months")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OfficerTheme.textSecondary)
            }

            Spacer()

            Tag(
                text: application.status.shortTitle,
                foreground: application.status.color,
                background: application.status.color.opacity(0.12)
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Expanded Loan History Card (for full history screen)

private struct ExpandedLoanHistoryCard: View {
    let application: DBLoanApplication
    let currentLoanId: UUID
    var onTap: () -> Void
    @State private var isExpanded = false

    private var isCurrentLoan: Bool { application.id == currentLoanId }

    private var formattedDate: String {
        guard let raw = application.createdAt else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: raw) else { return String(raw.prefix(10)) }
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }

    var body: some View {
        WhiteCard {
            VStack(alignment: .leading, spacing: 0) {

                // ── Collapsed header ─────────────────────────────────────
                Button {
                    onTap()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: purposeIcon(application.purpose ?? ""))
                            .font(.system(size: 18))
                            .foregroundStyle(isCurrentLoan ? OfficerTheme.accentGreen : OfficerTheme.accentBlue)
                            .frame(width: 44, height: 44)
                            .background((isCurrentLoan ? OfficerTheme.accentGreen : OfficerTheme.accentBlue).opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(application.purpose ?? "Loan Application")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(OfficerTheme.textPrimary)
                                if isCurrentLoan {
                                    Text("CURRENT")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(OfficerTheme.accentGreen)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(OfficerTheme.accentGreen.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(CurrencyFormatter.indian(application.loanAmount))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Tag(
                                text: application.status.title,
                                foreground: application.status.color,
                                background: application.status.color.opacity(0.12)
                            )
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // ── Expanded detail ──────────────────────────────────────
                if isExpanded {
                    Divider()
                        .overlay(OfficerTheme.softLine)
                        .padding(.vertical, 12)

                    VStack(spacing: 0) {
                        DetailRow(label: "Loan Amount", value: CurrencyFormatter.indian(application.loanAmount))
                        DetailRow(label: "Tenure", value: "\(application.tenureMonths) months")
                        DetailRow(label: "Interest Rate", value: application.interestRate != nil ? String(format: "%.1f%% p.a.", application.interestRate!) : "—")
                        DetailRow(label: "Purpose", value: application.purpose ?? "—")
                        DetailRow(label: "Applied On", value: formattedDate)
                        DetailRow(label: "Status", value: application.status.title, showsDivider: false)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Subviews

private struct HistoryMetricPill: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OfficerTheme.textSecondary)
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(OfficerTheme.textPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OfficerTheme.filterBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SummaryStatBox: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(OfficerTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct NoHistoryPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(OfficerTheme.textSecondary.opacity(0.5))

            Text("No history available")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(OfficerTheme.textPrimary)

            Text("This borrower has no previous loan applications on file.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OfficerTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Helpers

/// Maps a loan purpose string to an SF Symbol.
private func purposeIcon(_ purpose: String) -> String {
    let lower = purpose.lowercased()
    if lower.contains("home") || lower.contains("house") { return "house.fill" }
    if lower.contains("vehicle") || lower.contains("car") { return "car.fill" }
    if lower.contains("education") { return "graduationcap.fill" }
    if lower.contains("business") { return "briefcase.fill" }
    if lower.contains("personal") { return "person.fill" }
    return "banknote.fill"
}

// MARK: - DetailRow helper

private struct DetailRow: View {
    let label: String
    let value: String
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(OfficerTheme.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OfficerTheme.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 14)
            if showsDivider {
                Divider().overlay(OfficerTheme.softLine)
            }
        }
    }
}

// MARK: - Loan History Detail Sheet

private struct LoanHistoryDetailSheet: View {
    let application: DBLoanApplication
    @Environment(\.dismiss) private var dismiss

    private var formattedDate: String {
        guard let raw = application.createdAt else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: raw) else { return String(raw.prefix(10)) }
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OfficerTheme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        WhiteCard {
                            HStack(spacing: 16) {
                                Image(systemName: purposeIcon(application.purpose ?? ""))
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(OfficerTheme.accentBlue)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(application.purpose ?? "Loan Application")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(OfficerTheme.textPrimary)
                                    Text("Application Details")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(OfficerTheme.textSecondary)
                                }
                                Spacer()
                                
                                Tag(
                                    text: application.status.title,
                                    foreground: application.status.color,
                                    background: application.status.color.opacity(0.12)
                                )
                            }
                        }
                        
                        // Details Table
                        WhiteCard {
                            VStack(spacing: 0) {
                                DetailRow(label: "Loan Amount", value: CurrencyFormatter.indian(application.loanAmount))
                                DetailRow(label: "Tenure", value: "\(application.tenureMonths) months")
                                DetailRow(label: "Interest Rate", value: application.interestRate != nil ? String(format: "%.1f%% p.a.", application.interestRate!) : "—")
                                DetailRow(label: "Purpose", value: application.purpose ?? "—")
                                DetailRow(label: "Applied On", value: formattedDate)
                                DetailRow(label: "Status", value: application.status.title, showsDivider: false)
                            }
                        }
                        
                        // ID / Reference
                        VStack(spacing: 6) {
                            Text("Application ID")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(OfficerTheme.textSecondary)
                            Text(application.id.uuidString.uppercased())
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Loan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OfficerTheme.accentBlue)
                }
            }
        }
    }
}
