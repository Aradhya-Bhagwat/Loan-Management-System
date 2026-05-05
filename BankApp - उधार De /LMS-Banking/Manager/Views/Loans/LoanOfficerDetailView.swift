import SwiftUI

struct LoanOfficerDetailView: View {
    let officer: LoanOfficer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var userSession: UserSession?
    @State private var isLoading = true

    private var isPad: Bool { sizeClass == .regular }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else {
                    contentView
                }
            }
            .navigationTitle(officer.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color.appGreen)
                }
            }
            .background(Color.appBackground)
        }
        .task { await loadOfficerDetails() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(Color.appGreen)
            Text("Loading officer details…")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    // MARK: - Content

    private var contentView: some View {
        List {
            // ── Header ───────────────────────────────────────────
            Section {
                headerCell
            }
            .listRowBackground(Color.appCard)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

            // ── Personal Details (first priority) ────────────────
            Section("Personal Details") {
                DetailRowView(
                    label: "Phone",
                    value: nonEmpty(userSession?.phone) ?? "—"
                )
                DetailRowView(
                    label: "Email",
                    value: nonEmpty(userSession?.email) ?? "—"
                )
                DetailRowView(
                    label: "Branch",
                    value: nonEmpty(userSession?.branch) ?? "—"
                )
                if let joined = userSession?.joinedAt {
                    DetailRowView(
                        label: "Joined",
                        value: joined.formatted(.dateTime.day().month(.abbreviated).year())
                    )
                }
            }
            .listRowBackground(Color.appCard)
            //.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

            // ── Performance Stats ─────────────────────────────────
            Section("Performance") {
                if isPad {
                    statGrid
                        .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                } else {
                    statStack
                        //.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .listRowBackground(Color.appCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Header Cell

    private var headerCell: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.appGreen.opacity(0.12))
                .frame(width: isPad ? 68 : 56, height: isPad ? 68 : 56)
                .overlay(
                    Text(officer.initials)
                        .font(.system(size: isPad ? 28 : 22, weight: .semibold))
                        .foregroundStyle(Color.appGreen)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(officer.name)
                    .font(.system(size: isPad ? 22 : 18, weight: .bold))
                    .foregroundStyle(.primary)
                Text(officer.role)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, isPad ? 20 : 16)
    }

    // MARK: - Stat Layouts

    /// Vertical rows — iPhone
    private var statStack: some View {
        VStack(spacing: 0) {
            OfficerStatRow(
                label: "Applications Handled",
                value: "\(officer.loansHandled)",
                icon: "doc.text.fill",
                tint: .appGreen
            )
            Divider().padding(.leading, 52)
            OfficerStatRow(
                label: "Active Loans",
                value: "\(officer.activeLoans)",
                icon: "checkmark.seal.fill",
                tint: .blue
            )
            Divider().padding(.leading, 52)
            OfficerStatRow(
                label: "Approval Rate",
                value: String(format: "%.1f%%", officer.approvalRate),
                icon: "chart.line.uptrend.xyaxis",
                tint: .appGreen
            )
            Divider().padding(.leading, 52)
            OfficerStatRow(
                label: "Default Rate",
                value: String(format: "%.1f%%", officer.defaultRate),
                icon: "chart.line.downtrend.xyaxis",
                tint: .appRed
            )
        }
    }

    /// 2×2 grid — iPad
    private var statGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            OfficerStatCard(label: "Applications",  value: "\(officer.loansHandled)",                       icon: "doc.text.fill",                   tint: .appGreen)
            OfficerStatCard(label: "Active Loans",  value: "\(officer.activeLoans)",                        icon: "checkmark.seal.fill",             tint: .blue)
            OfficerStatCard(label: "Approval Rate", value: String(format: "%.1f%%", officer.approvalRate),  icon: "chart.line.uptrend.xyaxis",       tint: .appGreen)
            OfficerStatCard(label: "Default Rate",  value: String(format: "%.1f%%", officer.defaultRate),   icon: "chart.line.downtrend.xyaxis",     tint: officer.defaultRate > 5 ? .appRed : .primary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }

    private func loadOfficerDetails() async {
        defer { isLoading = false }
        userSession = try? await DatabaseService.shared.fetchOfficerUserSession(officerId: officer.id)
    }
}

// MARK: - Stat Row (iPhone)

private struct OfficerStatRow: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Stat Card (iPad grid)

private struct OfficerStatCard: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
