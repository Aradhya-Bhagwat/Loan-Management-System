import SwiftUI

enum TableMode {
    case overview
    case all
}

struct LoanTableView: View {
    let loans: [Loan]
    @Binding var searchText: String
    @Binding var statusFilter: LoanStatus?
    @Binding var selectedLoan: Loan?
    let mode: TableMode
    var isShowingAll: Binding<Bool>? = nil
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    let onApprove: (Loan) -> Void
    let onReject: (Loan) -> Void
    let onReturn: (Loan, String) -> Void

    @State private var rowLimit = 10
    @State private var showDatePicker = false

    var isDateActive: Bool { startDate != nil && endDate != nil }

    var filtered: [Loan] {
        loans.filter { loan in
            let matchStatus = statusFilter == nil || loan.status == statusFilter
            let appId = ApplicationIDGenerator.generate(from: loan.id)
            let matchSearch = searchText.isEmpty ||
                              loan.borrowerName.localizedCaseInsensitiveContains(searchText) ||
                              appId.localizedCaseInsensitiveContains(searchText)
            let matchDate: Bool = {
                guard let start = startDate, let end = endDate, let date = loan.createdAt else { return true }
                let cal = Calendar.current
                let startOfDay = cal.startOfDay(for: start)
                let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
                return date >= startOfDay && date <= endOfDay
            }()
            return matchStatus && matchSearch && matchDate
        }
    }

    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if mode == .overview {
                HStack(alignment: .lastTextBaseline) {
                    SectionHeader(title: "Loan Approvals")
                    Spacer()
                    if let isShowingAll = isShowingAll {
                        Button {
                            isShowingAll.wrappedValue = true
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.appGreen)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            VStack(alignment: .leading, spacing: 0) {
                if mode != .overview {
                    HStack {
                        Text("\(filtered.count) loans")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 14)
                }

                adaptiveSearchAndFilter

                Divider().padding(.horizontal, 20)

                Group {
                    if sizeClass == .regular {
                        VStack(alignment: .leading, spacing: 0) {
                            LoanTableHeader()
                            Divider().padding(.horizontal, 20)

                            LazyVStack(spacing: 0) {
                                let displayedLoans = mode == .overview ? Array(filtered.prefix(10)) : Array(filtered.prefix(rowLimit))
                                ForEach(displayedLoans) { loan in
                                    LoanTableRow(loan: loan, onApprove: onApprove, onReject: onReject, onTap: { selectedLoan = loan })
                                    if loan.id != displayedLoans.last?.id {
                                        Divider().padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                    } else {
                        LazyVStack(spacing: 0) {
                            let displayedLoans = mode == .overview ? Array(filtered.prefix(10)) : Array(filtered.prefix(rowLimit))
                            ForEach(displayedLoans) { loan in
                                LoanCardRow(loan: loan, onApprove: onApprove, onReject: onReject, onTap: { selectedLoan = loan })
                                
                                if loan.id != displayedLoans.last?.id {
                                    Divider().padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
                
                if mode == .all {
                    Divider().padding(.horizontal, 20)
                    HStack {
                        Text("Show rows:")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Picker("Rows", selection: $rowLimit) {
                            Text("10").tag(10)
                            Text("20").tag(20)
                            Text("50").tag(50)
                        }
                        .tint(.primary)
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
            .appCard()
        }
        .navigationDestination(item: $selectedLoan) { loan in
            LoanDetailView(loan: loan, onApprove: onApprove, onReject: onReject, onReturn: onReturn)
        }
        .sheet(isPresented: $showDatePicker) {
            LoanDateRangePickerSheet(startDate: $startDate, endDate: $endDate)
        }
    }

    private var adaptiveSearchAndFilter: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 12) {
                    searchBar
                        .frame(maxWidth: 300)
                    dateFilterPill
                    statusFilterPill
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    searchBar
                    HStack(spacing: 10) {
                        dateFilterPill
                        statusFilterPill
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var dateFilterPill: some View {
        Button {
            showDatePicker = true
        } label: {
            HStack(spacing: 8) {
                if isDateActive, let start = startDate, let end = endDate {
                    Text("\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                } else {
                    Text("Date")
                        .font(.system(size: 14, weight: .medium))
                }
                Image(systemName: isDateActive ? "calendar.badge.checkmark" : "calendar")
                    .font(.system(size: 15, weight: .semibold))
                if isDateActive {
                    Button {
                        startDate = nil
                        endDate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appGreen)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(isDateActive ? Color.appGreen : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var statusFilterPill: some View {
        let isActive = statusFilter != nil
        let label: String
        switch statusFilter {
        case .submitted:             label = "Submitted"
        case .underReview:           label = "Under Review"
        case .recommended:           label = "Recommended"
        case .approved:              label = "Approved"
        case .rejected:              label = "Rejected"
        case .returnedForCorrection: label = "Returned"
        case nil:                    label = "Status"
        }
        return Menu {
            Button { statusFilter = nil } label: {
                if statusFilter == nil { Label("All Statuses", systemImage: "checkmark") }
                else { Text("All Statuses") }
            }
            Button { statusFilter = .submitted } label: {
                if statusFilter == .submitted { Label("Submitted", systemImage: "checkmark") }
                else { Text("Submitted") }
            }
            Button { statusFilter = .recommended } label: {
                if statusFilter == .recommended { Label("Recommended", systemImage: "checkmark") }
                else { Text("Recommended") }
            }
            Button { statusFilter = .approved } label: {
                if statusFilter == .approved { Label("Approved", systemImage: "checkmark") }
                else { Text("Approved") }
            }
            Button { statusFilter = .rejected } label: {
                if statusFilter == .rejected { Label("Rejected", systemImage: "checkmark") }
                else { Text("Rejected") }
            }
            Button { statusFilter = .returnedForCorrection } label: {
                if statusFilter == .returnedForCorrection { Label("Returned", systemImage: "checkmark") }
                else { Text("Returned") }
            }
            if isActive {
                Divider()
                Button(role: .destructive) { statusFilter = nil } label: {
                    Label("Clear Status", systemImage: "xmark.circle")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: isActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(isActive ? Color.appGreen : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField("Search borrower…", text: $searchText)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.appSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }


}

struct LoanCardRow: View {
    let loan: Loan
    let onApprove: (Loan) -> Void
    let onReject: (Loan) -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ApplicationIDGenerator.generate(from: loan.id))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(loan.borrowerName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(loan.purpose)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Amount")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.indian(loan.amountValue))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Officer")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(loan.officer)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                    }
                }

                HStack {
                    StatusBadge(status: loan.status)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

struct LoanTableHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("App ID").tableHeaderStyle().frame(width: 120, alignment: .leading)
            Text("Borrower").tableHeaderStyle().frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
            Text("Amount").tableHeaderStyle().frame(width: 100, alignment: .leading)
            Text("Purpose").tableHeaderStyle().frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
            Text("Officer").tableHeaderStyle().frame(width: 100, alignment: .leading)
            Text("Status").tableHeaderStyle().frame(width: 110, alignment: .leading)
            Spacer().frame(width: 24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

extension Text {
    func tableHeaderStyle() -> some View {
        self
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }
}

struct LoanTableRow: View {
    let loan: Loan
    let onApprove: (Loan) -> Void
    let onReject: (Loan) -> Void
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
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

                Text(CurrencyFormatter.indian(loan.amountValue))
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 100, alignment: .leading)

                Text(loan.purpose)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

                Text(loan.officer)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 100, alignment: .leading)

                StatusBadge(status: loan.status)
                    .frame(width: 110, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(isHovered ? Color.appSecondary : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Date Range Picker Sheet

struct LoanDateRangePickerSheet: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Environment(\.dismiss) private var dismiss

    @State private var tempStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var tempEnd: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("From", selection: $tempStart, in: ...tempEnd, displayedComponents: .date)
                        .tint(.appGreen)
                    DatePicker("To", selection: $tempEnd, in: tempStart...Date(), displayedComponents: .date)
                        .tint(.appGreen)
                } footer: {
                    Text("Showing loans submitted between \(tempStart.formatted(date: .long, time: .omitted)) and \(tempEnd.formatted(date: .long, time: .omitted)).")
                        .font(.footnote)
                }
            }
            .navigationTitle("Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        startDate = tempStart
                        endDate = tempEnd
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(.appGreen)
                }
            }
        }
    }
}
