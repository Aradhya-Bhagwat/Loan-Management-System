//import SwiftUI
//
//struct OverdueLoansTable: View {
//    let controller: LoansController
//    @Environment(\.horizontalSizeClass) var sizeClass
//    @State private var loanToAssign: OverdueLoan? = nil
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            HStack {
//                SectionHeader(title: "Overdue & Defaulted Loans")
//                Spacer()
//                Text("\(controller.overdueLoans.count) records")
//                    .font(.system(size: 13))
//                    .foregroundStyle(.secondary)
//            }
//            .padding(.horizontal, 20)
//            .padding(.vertical, 16)
//
//            Divider().padding(.horizontal, 20)
//
//            Group {
//                if sizeClass == .regular {
//                    ScrollView(.horizontal, showsIndicators: true) {
//                        VStack(alignment: .leading, spacing: 0) {
//                            HStack(spacing: 0) {
//                                Text("Borrower").tableHeaderStyle().frame(width: 200, alignment: .leading)
//                                Text("Amount").tableHeaderStyle().frame(width: 110, alignment: .leading)
//                                Text("DPD").tableHeaderStyle().frame(width: 90, alignment: .leading)
//                                Text("Risk").tableHeaderStyle().frame(width: 90, alignment: .leading)
//                                Text("Officer").tableHeaderStyle().frame(width: 110, alignment: .leading)
//                                Text("Status").tableHeaderStyle().frame(width: 110, alignment: .leading)
//                                Text("Action").tableHeaderStyle().frame(width: 160, alignment: .trailing)
//                            }
//                            .padding(.horizontal, 20)
//                            .padding(.vertical, 10)
//                            
//                            Divider().padding(.horizontal, 20)
//                            
//                            VStack(spacing: 0) {
//                                ForEach(controller.overdueLoans) { loan in
//                                    HStack(spacing: 0) {
//                                        Text(loan.borrowerName)
//                                            .font(.system(size: 15, weight: .medium))
//                                            .frame(width: 200, alignment: .leading)
//                                        Text(loan.amount.replacingOccurrences(of: "$", with: "₹"))
//                                            .font(.system(size: 15))
//                                            .frame(width: 110, alignment: .leading)
//                                        Text("\(loan.dpd) days")
//                                            .font(.system(size: 14, weight: .semibold))
//                                            .foregroundStyle(loan.dpd >= 90 ? Color.appRed : loan.dpd >= 30 ? Color.appOrange : Color.secondary)
//                                            .frame(width: 90, alignment: .leading)
//                                        RiskBadge(risk: loan.risk)
//                                            .frame(width: 90, alignment: .leading)
//                                        Text(loan.officer)
//                                            .font(.system(size: 14))
//                                            .foregroundStyle(.secondary)
//                                            .frame(width: 110, alignment: .leading)
//                                        OverdueStatusBadge(status: loan.status)
//                                            .frame(width: 110, alignment: .leading)
//                                        Button("Assign Recovery") { loanToAssign = loan }
//                                            .font(.system(size: 12, weight: .semibold))
//                                            .buttonStyle(.bordered)
//                                            .controlSize(.small)
//                                            .frame(width: 160, alignment: .trailing)
//                                    }
//                                    .padding(.horizontal, 20)
//                                    .padding(.vertical, 14)
//                                    
//                                    if loan.id != controller.overdueLoans.last?.id {
//                                        Divider().padding(.horizontal, 20)
//                                    }
//                                }
//                            }
//                        }
//                    }
//                } else {
//                    VStack(spacing: 0) {
//                        ForEach(controller.overdueLoans) { loan in
//                            OverdueLoanCardRow(loan: loan, onAssign: { loanToAssign = loan })
//
//                            if loan.id != controller.overdueLoans.last?.id {
//                                Divider().padding(.horizontal, 20)
//                            }
//                        }
//                    }
//                }
//            }
//            .padding(.bottom, 8)
//        }
//        .appCard()
//        .confirmationDialog("Assign Recovery Officer", isPresented: Binding(
//            get: { loanToAssign != nil },
//            set: { if !$0 { loanToAssign = nil } }
//        ), titleVisibility: .visible) {
//            ForEach(controller.officers) { officer in
//                Button(officer.name) {
//                    if let loan = loanToAssign {
//                        Task {
//                            await controller.assignRecovery(loan, officerId: officer.id.uuidString)
//                            loanToAssign = nil
//                        }
//                    }
//                }
//            }
//            Button("Cancel", role: .cancel) {
//                loanToAssign = nil
//            }
//        } message: {
//            if let loan = loanToAssign {
//                Text("Select an officer for \(loan.borrowerName)'s overdue loan")
//            }
//        }
//    }
//}
//
//struct OverdueLoanCardRow: View {
//    let loan: OverdueLoan
//    var onAssign: () -> Void = {}
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Text(loan.borrowerName)
//                    .font(.system(size: 16, weight: .semibold))
//                Spacer()
//                OverdueStatusBadge(status: loan.status)
//            }
//
//            HStack {
//                VStack(alignment: .leading, spacing: 2) {
//                    Text("Amount").font(.system(size: 11)).foregroundStyle(.secondary)
//                    Text(loan.amount.replacingOccurrences(of: "$", with: "₹")).font(.system(size: 15, weight: .bold))
//                }
//                Spacer()
//                VStack(alignment: .trailing, spacing: 2) {
//                    Text("DPD").font(.system(size: 11)).foregroundStyle(.secondary)
//                    Text("\(loan.dpd) days")
//                        .font(.system(size: 14, weight: .semibold))
//                        .foregroundStyle(loan.dpd >= 90 ? Color.appRed : loan.dpd >= 30 ? Color.appOrange : .primary)
//                }
//            }
//
//            HStack {
//                RiskBadge(risk: loan.risk)
//                Spacer()
//                Button("Assign Recovery") { onAssign() }
//                    .font(.system(size: 12, weight: .semibold))
//                    .buttonStyle(.bordered)
//            }
//        }
//        .padding(.horizontal, 20)
//        .padding(.vertical, 16)
//    }
//}


import SwiftUI

struct OverdueLoansTable: View {
    let controller: LoansViewModel
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var statusFilter: OverdueStatus? = nil
    @State private var searchText: String = ""

    var filtered: [OverdueLoan] {
        controller.overdueLoans.filter { loan in
            //let matchStatus = statusFilter == nil || loan.status == statusFilter
            let matchStatus = statusFilter.map { $0 == loan.status } ?? true
            let appId = ApplicationIDGenerator.generate(from: loan.id)
            let matchSearch = searchText.isEmpty ||
                loan.borrowerName.localizedCaseInsensitiveContains(searchText) ||
                appId.localizedCaseInsensitiveContains(searchText)
            return matchStatus && matchSearch
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──────────────────────────────────────────
            HStack {
                SectionHeader(title: "Overdue & Defaulted Loans")
                Spacer()
                Text("\(filtered.count) records")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().padding(.horizontal, 20)

            // ── Search + Filter ──────────────────────────────────
            HStack(spacing: 12) {
                // Search bar (mirrors LoanTableView)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("Search borrower...", text: $searchText)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.appSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: sizeClass == .regular ? 300 : .infinity)

                // Filter menu (mirrors LoanTableView style)
                Menu {
                    Button {
                        statusFilter = nil
                    } label: {
                        Label("All", systemImage: statusFilter == nil ? "checkmark" : "")
                    }
                    Button {
                        statusFilter = .overdue
                    } label: {
                        Label("Overdue", systemImage: statusFilter == .overdue ? "checkmark" : "")
                    }
                    Button {
                        statusFilter = .defaulted
                    } label: {
                        Label("Defaulted", systemImage: statusFilter == .defaulted ? "checkmark" : "")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 14))
                        Text(statusFilter != nil ? "Filtered" : "Filter")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(statusFilter != nil ? Color.black : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(statusFilter != nil ? Color.white : Color.appSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if sizeClass == .regular { Spacer() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 20)

            // ── Table ────────────────────────────────────────────
            Group {
                if sizeClass == .regular {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack(spacing: 12) {
                            Text("App ID")
                                .tableHeaderStyle()
                                .frame(width: 120, alignment: .leading)
                            Text("Borrower")
                                .tableHeaderStyle()
                                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                            Text("Amount")
                                .tableHeaderStyle()
                                .frame(width: 110, alignment: .leading)
                            Text("DPD")
                                .tableHeaderStyle()
                                .frame(width: 90, alignment: .leading)
                            Text("Officer")
                                .tableHeaderStyle()
                                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                            Text("Status")
                                .tableHeaderStyle()
                                .frame(width: 110, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)

                        Divider().padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(filtered) { loan in
                                HStack(spacing: 12) {
                                    Text(ApplicationIDGenerator.generate(from: loan.id))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(width: 120, alignment: .leading)

                                    Text(loan.borrowerName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

                                    Text(loan.amount.replacingOccurrences(of: "$", with: "₹"))
                                        .font(.system(size: 15))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .frame(width: 110, alignment: .leading)

                                    Text("\(loan.dpd) days")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(
                                            loan.dpd >= 90 ? Color.appRed :
                                            loan.dpd >= 30 ? Color.appOrange :
                                            Color.secondary
                                        )
                                        .frame(width: 90, alignment: .leading)

                                    Text(loan.officer)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

                                    OverdueStatusBadge(status: loan.status)
                                        .frame(width: 110, alignment: .leading)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)

                                if loan.id != filtered.last?.id {
                                    Divider().padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                } else {
                    // iPhone card rows (no assign button, no risk)
                    VStack(spacing: 0) {
                        ForEach(filtered) { loan in
                            OverdueLoanCardRow(loan: loan)
                            if loan.id != filtered.last?.id {
                                Divider().padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .appCard()
    }
}

// MARK: - iPhone Card Row (no assign button, no risk badge)

struct OverdueLoanCardRow: View {
    let loan: OverdueLoan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ApplicationIDGenerator.generate(from: loan.id))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(loan.borrowerName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                OverdueStatusBadge(status: loan.status)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amount")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(loan.amount.replacingOccurrences(of: "$", with: "₹"))
                        .font(.system(size: 15, weight: .bold))
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("DPD")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(loan.dpd) days")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            loan.dpd >= 90 ? Color.appRed :
                            loan.dpd >= 30 ? Color.appOrange :
                            .primary
                        )
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Officer")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(loan.officer)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
