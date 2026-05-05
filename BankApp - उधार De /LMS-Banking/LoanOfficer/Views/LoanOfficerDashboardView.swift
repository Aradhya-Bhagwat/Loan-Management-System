//
//  LoanOfficerDashboardView.swift
//  LoanOfficer
//
//  Created by Shivani Dinesh on 16/04/26.
//

import SwiftUI

struct LoanOfficerDashboardView: View {
    
    let officerId: UUID
    @StateObject private var controller: LoanOfficerDashboardViewModel
    @State private var selectedLoan: LoanCase?
    @State private var showNotifications = false
    @State private var notificationService = NotificationService.shared
    @Environment(\.horizontalSizeClass) var sizeClass
    
    init(officerId: UUID) {
        self.officerId = officerId
        self._controller = StateObject(wrappedValue: LoanOfficerDashboardViewModel(officerId: officerId))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if controller.isLoading && controller.allLoans.isEmpty {
                    ProgressView("Loading applications…")
                        .tint(.appGreen)
                } else if let error = controller.errorMessage, controller.allLoans.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.appOrange)
                        Text(error)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await controller.loadLoans() }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.appGreen)
                    }
                    .padding(40)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            stats
                            
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .lastTextBaseline) {
                                    AppSectionHeader(title: "Loan Applications")
                                    Spacer()
                                    NavigationLink(destination: AllApplicationsScreen(controller: controller)) {
                                        Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.appGreen)
                                    }
                                }
                                
                                assignedApplicationsCard
                            }
                        }
                        .padding(.horizontal, sizeClass == .regular ? 32 : 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Overview")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: sizeClass == .regular ? 18 : 12) {
                        Button {
                            showNotifications = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: sizeClass == .regular ? 22 : 18, weight: .medium))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                                
                                // Notification Badge with count
                                if notificationService.unreadCount > 0 {
                                    Text("\(min(notificationService.unreadCount, 99))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .frame(minWidth: 16)
                                        .background(Capsule().fill(.appGreen))
                                        .offset(x: 6, y: -4)
                                }
                            }
                            .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            LoanOfficerProfileView()
                        } label: {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: sizeClass == .regular ? 26 : 22, weight: .semibold))
                                .foregroundColor(.appGreen)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 44)
                    .padding(.vertical, 4)
                }
            }
            .navigationDestination(item: $selectedLoan) { loan in
                LoanDetailScreen(loan: loan, controller: controller)
            }
            .task {
                notificationService.configure(officerId: officerId)
                await controller.loadLoans()
            }
            .sheet(isPresented: $showNotifications) {
                LoanOfficerNotificationsView { notification in
                    // Deep-link: find the loan matching the notification's applicationId
                    if let appId = notification.applicationId,
                       let matchingLoan = controller.allLoans.first(where: { $0.application.id == appId }) {
                        selectedLoan = matchingLoan
                    } else if let fallback = controller.allLoans.first {
                        selectedLoan = fallback
                    }
                }
            }
        }
    }
    
    private var stats: some View {
        DashboardGrid {
            MetricCard(title: "Assigned", value: "\(controller.allLoans.count)", icon: "tray.full.fill", iconTint: .appGreen, showChevron: false)
            MetricCard(title: "In Review", value: "\(controller.pendingCount)", icon: "clock.badge.checkmark.fill", iconTint: .appGreen, showChevron: false)
            MetricCard(title: "Recommended", value: "\(controller.recommendedCount)", icon: "checkmark.circle.fill", iconTint: .appGreen, showChevron: false)
            MetricCard(title: "Total Volume", value: CurrencyFormatter.indian(controller.totalLoanAmount), icon: "indianrupeesign", iconTint: .appGreen, showChevron: false)
        }
    }
    
    private var assignedApplicationsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ApplicationsFilterBar(
                searchText: Binding(
                    get: { controller.searchText },
                    set: { controller.searchText = $0 }
                ),
                selectedStatus: $controller.selectedStatus,
                startDate: $controller.startDate,
                endDate: $controller.endDate,
                isCompact: sizeClass != .regular
            )
            .padding(.bottom, 20)

            if controller.filteredLoans.isEmpty {
                EmptyStateCard()
                    .padding(.vertical, 40)
            } else {
                let topLoans = Array(controller.filteredLoans.prefix(10))

                if sizeClass == .regular {
                    VStack(spacing: 0) {
                        ApplicationHeaderRow()
                        Divider()

                        LazyVStack(spacing: 0) {
                            ForEach(topLoans) { loan in
                                ApplicationRow(loan: loan, onOpen: { selectedLoan = loan })

                                if loan.id != topLoans.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(topLoans) { loan in
                            CompactApplicationRow(loan: loan, onOpen: { selectedLoan = loan })
                        }
                    }
                }
            }
        }
        .appCard()
    }
    // MARK: - All Applications Screen
    
    private struct AllApplicationsScreen: View {
        let controller: LoanOfficerDashboardViewModel
        
        @State private var searchText = ""
        @State private var selectedStatus: StatusFilter = .all
        @State private var startDate: Date? = nil
        @State private var endDate: Date? = nil
        @State private var selectedLoan: LoanCase?
        @Environment(\.horizontalSizeClass) private var sizeClass
        
        @State private var rowsPerPage: Int = 10
        @State private var currentPage: Int = 1
        
        private var filteredLoans: [LoanCase] {
            controller.allLoans.filter { loan in
                let matchesStatus: Bool
                switch selectedStatus {
                case .all: matchesStatus = true
                case .pending: matchesStatus = (loan.application.status == .underReview || loan.application.status == .submitted)
                case .approved: matchesStatus = (loan.application.status == .approved)
                case .rejected: matchesStatus = (loan.application.status == .rejected)
                case .recommended: matchesStatus = (loan.application.status == .recommended)
                case .returned: matchesStatus = (loan.application.status == .returnedForCorrection)
                }

                let matchesSearch = searchText.isEmpty ||
                ApplicationIDGenerator.generate(from: loan.application.id).localizedCaseInsensitiveContains(searchText) ||
                loan.borrower.displayName.localizedCaseInsensitiveContains(searchText) ||
                (loan.application.purpose ?? "").localizedCaseInsensitiveContains(searchText)

                let matchesDate: Bool
                if let start = startDate, let end = endDate {
                    if let date = loan.application.createdDate {
                        let calendar = Calendar.current
                        let startOfDay = calendar.startOfDay(for: start)
                        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
                        matchesDate = date >= startOfDay && date <= endOfDay
                    } else {
                        matchesDate = false
                    }
                } else {
                    matchesDate = true
                }

                return matchesStatus && matchesSearch && matchesDate
            }
        }
        
        private var paginatedLoans: [LoanCase] {
            let start = (currentPage - 1) * rowsPerPage
            return Array(filteredLoans.dropFirst(start).prefix(rowsPerPage))
        }
        
        var body: some View {
            ZStack {
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ApplicationsFilterBar(
                            searchText: $searchText,
                            selectedStatus: $selectedStatus,
                            startDate: $startDate,
                            endDate: $endDate,
                            isCompact: sizeClass != .regular
                        )
                        .padding(.bottom, 20)
                        
                        if filteredLoans.isEmpty {
                            EmptyStateCard()
                                .padding(.vertical, 40)
                        } else {
                            if sizeClass == .regular {
                                VStack(alignment: .leading, spacing: 0) {
                                    ApplicationHeaderRow()
                                    Divider()
                                    
                                    LazyVStack(spacing: 0) {
                                        ForEach(paginatedLoans) { loan in
                                            ApplicationRow(loan: loan, onOpen: { selectedLoan = loan })
                                            
                                            if loan.id != paginatedLoans.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(paginatedLoans) { loan in
                                        CompactApplicationRow(loan: loan, onOpen: { selectedLoan = loan })
                                    }
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 16)
                            
                            paginationControls
                        }
                    }
                    .appCard()
                    .padding(20)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("All Applications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedLoan) { loan in
                LoanDetailScreen(loan: loan, controller: controller)
            }
            .onChange(of: searchText) { _ in currentPage = 1 }
            .onChange(of: selectedStatus) { _ in currentPage = 1 }
            .onChange(of: startDate) { _ in currentPage = 1 }
            .onChange(of: endDate) { _ in currentPage = 1 }
            .onChange(of: rowsPerPage) { _ in currentPage = 1 }
        }
        
        private var paginationControls: some View {
            HStack {
                Text("Show rows:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Picker("Rows", selection: $rowsPerPage) {
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("50").tag(50)
                }
                .pickerStyle(.menu)
                .tint(.primary)
                
                Spacer()
                
                let total = filteredLoans.count
                let start = total == 0 ? 0 : (currentPage - 1) * rowsPerPage + 1
                let end = min(currentPage * rowsPerPage, total)
                
                Text("\(start) - \(end) of \(total)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                
                HStack(spacing: 16) {
                    Button(action: {
                        if currentPage > 1 { currentPage -= 1 }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(currentPage > 1 ? Color.primary : Color.secondary.opacity(0.3))
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .disabled(currentPage <= 1)
                    
                    Button(action: {
                        if end < total { currentPage += 1 }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(end < total ? Color.primary : Color.secondary.opacity(0.3))
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .disabled(end >= total)
                }
            }
        }
    }
    
    // MARK: - Loan Detail Screen
    
    private struct LoanDetailScreen: View {
        let loan: LoanCase
        @ObservedObject var controller: LoanOfficerDashboardViewModel
        @State private var showDocuments = false
        @State private var showConfirmation = false
        @State private var pendingAction: LoanApplicationStatus?


        @State private var showSanctionLetter = false
        @State private var showChat = false

        @Environment(\.dismiss) private var dismiss
        @Environment(AuthViewModel.self) private var authController
        
        private var currentLoan: LoanCase {
            controller.allLoans.first(where: { $0.application.id == loan.application.id }) ?? loan
        }
        
        var body: some View {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    BorrowerHeaderCard(loan: currentLoan, showChat: $showChat)
                    
                    if currentLoan.application.status == .returnedForCorrection,
                       let comment = currentLoan.application.managerComment,
                       !comment.isEmpty {
                        sectionLabel("Manager Feedback")
                        ManagerCommentCard(comment: comment)
                    }

                    sectionLabel("Employment Details")
                    EmploymentDetailsCard(
                        employment: currentLoan.employment,
                        income: currentLoan.application.monthlyIncome
                    )

                    sectionLabel("Loan Details")
                    LoanInfoCard(loan: currentLoan)

                     sectionLabel("Financial Overview")
                     FinancialOverviewCard(
                         financials: currentLoan.financials,
                         monthlyIncome: currentLoan.application.monthlyIncome
                     )


                    sectionLabel("Risk Analysis")
                    RiskAnalysisCard(loan: currentLoan)

                    //AIInsightsCard(loan: currentLoan)

                    sectionLabel("Loan History")
                    BorrowerLoanHistoryCard(loan: currentLoan)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Documents")
                            .font(.title3.bold())
                            .foregroundStyle(OfficerTheme.textSecondary)
                        Spacer()
                        Button(action: { showDocuments = true }) {
                            HStack(spacing: 4) {
                                Text("\(currentLoan.documentSummary.verifiedCount)/\(currentLoan.documentSummary.totalCount) verified")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    NewDocumentsCard(loan: currentLoan)

                    LoanCommentsCard(
                        loanId: currentLoan.application.id,
                        officerId: controller.officerId,
                        controller: controller
                    )

                    VStack(spacing: 12) {
                        let status = currentLoan.application.status
                        let canTakeAction =
                            status == .underReview ||
                            status == .submitted ||
                            status == .returnedForCorrection
                        let allDocumentsVerified =
                            currentLoan.documentSummary.totalCount > 0 &&
                            currentLoan.documentSummary.verifiedCount == currentLoan.documentSummary.totalCount

                        if canTakeAction {
                            HStack(spacing: 14) {
                                Button {
                                    pendingAction = .rejected
                                    showConfirmation = true
                                } label: {
                                    Text("Reject")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(OfficerTheme.reject)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(WideSecondaryButtonStyle())

                                Button {
                                    guard allDocumentsVerified else { return }
                                    pendingAction = .recommended
                                    showConfirmation = true
                                } label: {
                                    Text("Recommend")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                        .background(
                                            RoundedRectangle(
                                                cornerRadius: 16,
                                                style: .continuous
                                            )
                                            .fill(allDocumentsVerified ? OfficerTheme.accentBlue : OfficerTheme.accentBlue.opacity(0.45))
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(!allDocumentsVerified)
                                .opacity(allDocumentsVerified ? 1 : 0.8)
                            }
                            
                            if !allDocumentsVerified {
                                Text("Verify all required documents to enable recommendation.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                        } else {
                            Text(status.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(status.color)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .fill(status.color.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                    .stroke(status.color.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }

            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Application Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)

            .navigationDestination(isPresented: $showDocuments) {
                DocumentsReviewScreen(
                    loan: currentLoan,
                    applicationId: currentLoan.application.id,
                    officerId: controller.officerId,
                    onDocumentsUpdated: {
                        Task { await controller.loadLoans() }
                    }
                )
            }

            .navigationDestination(isPresented: $showChat) {
                ChatView(loan: loan, officerId: controller.officerId)
            }
            .alert("Confirm Action", isPresented: $showConfirmation) {
                if let action = pendingAction {
                    Button(action.actionTitle) {
                        Task {
                            if action == .recommended {
                                let summary = currentLoan.documentSummary
                                guard summary.totalCount > 0,
                                      summary.verifiedCount == summary.totalCount else {
                                    pendingAction = nil
                                    return
                                }
                            }
                            await controller.updateStatus(currentLoan.id, to: action)
                        }
                    }
                    Button("Cancel", role: .cancel) { pendingAction = nil }
                }
            } message: {
                if let action = pendingAction {
                    Text("Are you sure you want to mark this application as \"\(action.title)\"?")
                }
            }

        }
        
        private func sectionLabel(_ title: String) -> some View {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(OfficerTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Manager Comment Card
    
    private struct ManagerCommentCard: View {
        let comment: String
        
        var body: some View {
            WhiteCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(comment)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(OfficerTheme.textPrimary)
                        .lineSpacing(4)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OfficerTheme.iconRed.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(OfficerTheme.iconRed.opacity(0.15), lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Info Field
    
    private struct InfoField: View {
        let label: String
        let value: String
        var valueColor: Color = OfficerTheme.textPrimary
        var isTag: Bool = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OfficerTheme.textSecondary)
                if isTag {
                    Tag(text: value, foreground: valueColor, background: valueColor.opacity(0.12))
                } else {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(valueColor)
                }
            }
        }
    }
    
    // MARK: - Borrower Header Card
    
    private struct BorrowerHeaderCard: View {
        let loan: LoanCase
        @Binding var showChat: Bool
        
        var body: some View {
            WhiteCard {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Circle()
                            .fill(OfficerTheme.iconGreen.opacity(0.15))
                            .frame(width: 58, height: 58)
                            .overlay(Image(systemName: "person").foregroundStyle(OfficerTheme.iconGreen).font(.system(size: 24)))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                Text(loan.borrower.displayName)
                                    .font(.system(size: 22, weight: .bold))
                                
                                Text(ApplicationIDGenerator.generate(from: loan.application.id))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(OfficerTheme.filterBackground)
                                    .clipShape(Capsule())
                                
                                Button {
                                    showChat = true
                                } label: {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(OfficerTheme.accentGreen)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            Text(loan.application.purpose ?? "Loan Application")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("CIBIL")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(OfficerTheme.textSecondary)
                            Text("\(loan.creditScore)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(loan.riskLevel == .low ? OfficerTheme.iconGreen : loan.riskLevel == .medium ? OfficerTheme.iconAmber : OfficerTheme.iconRed)
                        }
                    }
                    
                    Divider().overlay(OfficerTheme.softLine)
                    
                    HStack(alignment: .top) {
                        InfoField(label: "Mobile", value: loan.borrower.mobile ?? "—")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        InfoField(label: "Email", value: loan.borrower.email ?? "—")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
    
    // MARK: - Employment Details Card
    
    private struct EmploymentDetailsCard: View {
        let employment: DBEmployment?
        let income: Double?
        
        var body: some View {
            WhiteCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 0) {
//                        DetailRow(label: "Type", value: employment?.employmentType?.capitalized ?? "—")
                        DetailRow(label: "Company", value: employment?.companyName ?? "—")
                        DetailRow(label: "Industry", value: employment?.industryType ?? "—")
                        DetailRow(label: "Role", value: employment?.jobRole ?? "—")
                        DetailRow(label: "Experience", value: employment?.yearsExperience != nil ? "\(employment!.yearsExperience!) years" : "—")
                        
                        HStack {
                            Text("Monthly Income")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary)
                            Spacer()
                            Text(income != nil ? CurrencyFormatter.indian(income!) : (employment?.monthlyIncome != nil ? CurrencyFormatter.indian(employment!.monthlyIncome!) : "—"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(OfficerTheme.iconGreen)
                        }
                        .padding(.vertical, 14)
                        Divider().overlay(OfficerTheme.softLine)
                        
                        HStack {
                            Text("Employer Type")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary)
                            Spacer()
                            Tag(text: employment?.employmentType?.capitalized ?? "—", foreground: OfficerTheme.accentBlue, background: OfficerTheme.accentBlue.opacity(0.12))
                        }
                        .padding(.top, 14)
                    }
                }
            }
        }
    }
    
    // MARK: - Icon Badge
    
    private struct IconBadge: View {
        let icon: String
        let color: Color
        var body: some View {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(Circle())
        }
    }
    
    // MARK: - Loan Info Card
    
    private struct LoanInfoCard: View {
        let loan: LoanCase
        
        var body: some View {
            WhiteCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        IconBadge(icon: "indianrupeesign", color: OfficerTheme.iconGreen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Amount").font(.system(size: 13, weight: .medium)).foregroundStyle(OfficerTheme.textSecondary)
                            Text(CurrencyFormatter.indian(loan.application.loanAmount)).font(.system(size: 17, weight: .bold))
                        }
                    }
                    
                    HStack(spacing: 16) {
                        IconBadge(icon: "calendar", color: OfficerTheme.accentBlue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tenure").font(.system(size: 13, weight: .medium)).foregroundStyle(OfficerTheme.textSecondary)
                            Text("\(loan.application.tenureMonths) months").font(.system(size: 17, weight: .bold))
                        }
                    }
                    
                    HStack(spacing: 16) {
                        IconBadge(icon: "chart.line.uptrend.xyaxis", color: OfficerTheme.iconAmber)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Interest Rate").font(.system(size: 13, weight: .medium)).foregroundStyle(OfficerTheme.textSecondary)
                            Text(loan.application.interestRate != nil ? String(format: "%.1f%% p.a.", loan.application.interestRate!) : "—").font(.system(size: 17, weight: .bold))
                        }
                    }
                    
                    Divider().overlay(OfficerTheme.softLine).padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Purpose").font(.system(size: 13, weight: .medium)).foregroundStyle(OfficerTheme.textSecondary)
                        Text(loan.application.purpose ?? "—")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(OfficerTheme.textPrimary)
                    }
                    
                    Divider().overlay(OfficerTheme.softLine)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Submitted Date").font(.system(size: 13, weight: .medium)).foregroundStyle(OfficerTheme.textSecondary)
                        Text({
                            guard let raw = loan.application.createdAt else { return "—" }
                            let iso = ISO8601DateFormatter()
                            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            guard let date = iso.date(from: raw) else { return raw }
                            let f = DateFormatter()
                            f.dateFormat = "d MMMM yyyy"
                            return f.string(from: date)
                        }()).font(.system(size: 15, weight: .medium)).foregroundStyle(OfficerTheme.textPrimary)
                    }
                }
            }
        }
    }
    
    // MARK: - Financial Overview Card
    
    private struct FinancialOverviewCard: View {
        let financials: DBFinancials?
        let monthlyIncome: Double?
        
        private var debtToIncome: String {
            guard let emi = financials?.totalEmi, let income = monthlyIncome, income > 0 else { return "—" }
            return String(format: "%.1f%%", (emi / income) * 100)
        }
        
        var body: some View {
            WhiteCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 0) {
                        DetailRow(label: "Existing Loans", value: financials?.existingLoansCount != nil ? "\(financials!.existingLoansCount!)" : "—")
                        DetailRow(label: "Total EMI", value: financials?.totalEmi != nil ? CurrencyFormatter.indian(financials!.totalEmi!) : "—")
                        DetailRow(label: "Credit Card Usage", value: financials?.creditCardUsage != nil ? String(format: "%.0f%%", financials!.creditCardUsage!) : "—")
                        
                        HStack {
                            Text("Savings Balance").font(.system(size: 15, weight: .medium)).foregroundStyle(OfficerTheme.textSecondary)
                            Spacer()
                            Text(financials?.savingsBalance != nil ? CurrencyFormatter.indian(financials!.savingsBalance!) : "—")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(OfficerTheme.iconGreen)
                        }.padding(.vertical, 14)
                        Divider().overlay(OfficerTheme.softLine)
                        
                        HStack {
                            Text("Debt-to-Income Ratio").font(.system(size: 15, weight: .medium)).foregroundStyle(OfficerTheme.textSecondary)
                            Spacer()
                            Text(debtToIncome).font(.system(size: 15, weight: .bold)).foregroundStyle(OfficerTheme.iconGreen)
                        }.padding(.top, 14)
                    }
                }
            }
        }
    }
    
    
    // MARK: - Risk Analysis Card

    private struct RiskAnalysisCard: View {
        let loan: LoanCase
        @StateObject private var viewModel: LoanScoringViewModel

        init(loan: LoanCase) {
            self.loan = loan
            let profile = LoanApplicantProfile(
                income: loan.application.monthlyIncome ?? loan.employment?.monthlyIncome ?? 0,
                creditScore: Double(loan.creditScore),
                employmentYears: Double(loan.employment?.yearsExperience ?? 0),
                existingDebt: loan.financials?.totalEmi ?? 0,
                savingsBalance: loan.financials?.savingsBalance ?? 0,
                creditUtilization: loan.creditProfile?.creditUtilization ?? 0,
                loanAmount: loan.application.loanAmount,
                tenure: loan.application.tenureMonths
            )
            self._viewModel = StateObject(wrappedValue: LoanScoringViewModel(profile: profile))
        }

        var body: some View {
            WhiteCard {
                VStack(alignment: .leading, spacing: 0) {
                    // ── 2-LINE SUMMARY ──
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OfficerTheme.iconGreen)
                            Text(viewModel.insightLine1)
                                .font(.system(size: 15))
                                .foregroundStyle(OfficerTheme.textPrimary)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(OfficerTheme.iconAmber)
                            Text(viewModel.insightLine2)
                                .font(.system(size: 15))
                                .foregroundStyle(OfficerTheme.textPrimary)
                        }
                    }
                    .padding(.bottom, 16)
                    
                    Divider().overlay(OfficerTheme.softLine)
                    
                    // ── FACTOR SCORES ──
                    if viewModel.normalizedInputs.count == viewModel.criteriaNames.count {
                        ForEach(0..<viewModel.criteriaNames.count, id: \.self) { index in
                            let name = viewModel.criteriaNames[index]
                            let value = viewModel.normalizedInputs[index]
                            let barColor = factorColor(value)
                            let label = factorLabel(value)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(OfficerTheme.textPrimary)
                                    Spacer()
                                    Text(label)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(barColor)
                                }
                                
                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(OfficerTheme.filterBackground)
                                            .frame(height: 8)
                                        Capsule()
                                            .fill(barColor)
                                            .frame(width: max(proxy.size.width * value, 8), height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding(.vertical, 16)
                            
                            if index < viewModel.criteriaNames.count - 1 {
                                Divider().overlay(OfficerTheme.softLine)
                            }
                        }
                    }
                }
            }
        }

        private func factorColor(_ value: Double) -> Color {
            if value >= 0.7 { return OfficerTheme.iconGreen }
            if value >= 0.4 { return OfficerTheme.iconAmber }
            return OfficerTheme.iconRed
        }

        private func factorLabel(_ value: Double) -> String {
            if value >= 0.7 { return "Strong" }
            if value >= 0.4 { return "Fair" }
            return "Weak"
        }
    }
    
    // MARK: - Document Listing Row
    
    private struct DocumentListingRow: View {
        let title: String
        let subtitle: String
        let verificationStatus: String

        private var statusIcon: String {
            switch verificationStatus {
            case "Verified", "Uploaded":
                return "checkmark.circle.fill"
            case "Rejected":
                return "xmark.circle.fill"
            case "Pending":
                return "clock.fill"
            default:
                return "minus.circle"
            }
        }

        private var statusColor: Color {
            switch verificationStatus {
            case "Verified", "Uploaded":
                return OfficerTheme.iconGreen
            case "Rejected":
                return OfficerTheme.iconRed
            case "Pending":
                return OfficerTheme.iconAmber
            default:
                return OfficerTheme.textSecondary
            }
        }

        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: verificationStatus == "Uploaded" ? "checkmark.circle.fill" : "doc.text")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        verificationStatus == "Uploaded"
                        ? OfficerTheme.iconGreen
                        : OfficerTheme.textSecondary
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        verificationStatus == "Uploaded"
                        ? OfficerTheme.iconGreen.opacity(0.1)
                        : OfficerTheme.softLine.opacity(0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OfficerTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(statusColor)

                    Text(verificationStatus)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(statusColor)
                }
            }
            .padding(12)
            .background(OfficerTheme.filterBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - New Documents Card

    private struct NewDocumentsCard: View {
        let loan: LoanCase

        private var summary: DocumentSummary { loan.documentSummary }

        var body: some View {
            WhiteCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 12) {
                        ForEach(summary.items) { item in
                            DocumentListingRow(
                                title: item.title,
                                subtitle: item.verificationStatus,
                                verificationStatus: item.verificationStatus
                            )
                        }
                    }

                }
            }
        }
    }
    
    // MARK: - Table Header & Rows
    
    private struct ApplicationHeaderRow: View {
        var body: some View {
            HStack(spacing: 0) {
                Text("App ID").officerTableHeaderStyle().frame(width: 100, alignment: .leading)
                Text("Borrower").officerTableHeaderStyle().frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                Text("Amount").officerTableHeaderStyle().frame(width: 100, alignment: .leading)
                Text("Purpose").officerTableHeaderStyle().frame(minWidth: 110, maxWidth: .infinity, alignment: .leading)
                Text("Credit").officerTableHeaderStyle().frame(width: 70, alignment: .leading)
                Text("Status").officerTableHeaderStyle().frame(width: 130, alignment: .leading)
                Color.clear.frame(width: 40, height: 1)
            }
            .padding(.vertical, 14)
            .foregroundStyle(OfficerTheme.textSecondary)
        }
    }
    
    private struct ApplicationRow: View {
        let loan: LoanCase
        let onOpen: () -> Void
        @State private var isHovered = false
        
        var body: some View {
            Button(action: onOpen) {
                HStack(spacing: 0) {
                    Text(ApplicationIDGenerator.generate(from: loan.application.id))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(OfficerTheme.textSecondary)
                        .frame(width: 100, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(loan.borrower.displayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                    
                    Text(CurrencyFormatter.indian(loan.application.loanAmount))
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .frame(width: 100, alignment: .leading)
                    
                    Text(loan.application.purpose ?? "—")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(minWidth: 110, maxWidth: .infinity, alignment: .leading)
                    
                    CreditBadge(score: loan.creditScore)
                        .frame(width: 70, alignment: .leading)
                    
                    OfficerStatusBadge(status: loan.application.status)
                        .frame(width: 130, alignment: .leading)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OfficerTheme.textSecondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 14)
                .background(isHovered ? OfficerTheme.filterBackground : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHovered = hovering }
        }
    }

    private struct CompactApplicationRow: View {
        let loan: LoanCase
        let onOpen: () -> Void

        var body: some View {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loan.borrower.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(OfficerTheme.textPrimary)

                            Text(ApplicationIDGenerator.generate(from: loan.application.id))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OfficerTheme.textSecondary)
                    }

                    Text(loan.application.purpose ?? "—")
                        .font(.system(size: 14))
                        .foregroundStyle(OfficerTheme.textSecondary)
                        .lineLimit(2)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Amount")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary)
                            Text(CurrencyFormatter.indian(loan.application.loanAmount))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(OfficerTheme.textPrimary)
                        }

                        Spacer()

                        CreditBadge(score: loan.creditScore)
                    }

                    HStack {
                        Spacer()
                        OfficerStatusBadge(status: loan.application.status)
                    }
                }
                .padding(16)
                .background(OfficerTheme.filterBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Empty State
    
    private struct EmptyStateCard: View {
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(OfficerTheme.textSecondary)
                
                Text("No assigned applications are available.")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(OfficerTheme.textPrimary)
                
                Text("When loans are assigned to your account, they will appear here.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OfficerTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 42)
            .background(OfficerTheme.filterBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
    
    // MARK: - Search Field
    private struct SearchField: View {
        @Binding var text: String
        
        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(OfficerTheme.textSecondary)
                
                TextField("Search borrower...", text: $text)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(OfficerTheme.filterBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .frame(maxWidth: 340)
        }
    }

    private struct ApplicationsFilterBar: View {
        @Binding var searchText: String
        @Binding var selectedStatus: StatusFilter
        @Binding var startDate: Date?
        @Binding var endDate: Date?
        let isCompact: Bool

        var body: some View {
            Group {
                if isCompact {
                    VStack(alignment: .leading, spacing: 12) {
                        SearchField(text: $searchText)
                        HStack(spacing: 12) {
                            DateFilterButton(startDate: $startDate, endDate: $endDate)
                            ApplicationsFilterMenu(
                                selectedStatus: $selectedStatus
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    HStack(spacing: 12) {
                        SearchField(text: $searchText)
                            .frame(maxWidth: 300)

                        DateFilterButton(startDate: $startDate, endDate: $endDate)

                        ApplicationsFilterMenu(
                            selectedStatus: $selectedStatus
                        )

                        Spacer()
                    }
                }
            }
        }
    }

    private struct DateFilterButton: View {
        @Binding var startDate: Date?
        @Binding var endDate: Date?
        @State private var showSheet = false
        @State private var tempStart: Date = Date()
        @State private var tempEnd: Date = Date()

        private var hasFilter: Bool { startDate != nil && endDate != nil }

        private var labelText: String {
            guard let start = startDate, let end = endDate else { return "Date" }
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return "\(f.string(from: start)) - \(f.string(from: end))"
        }

        var body: some View {
            Button {
                tempStart = startDate ?? Date()
                tempEnd = endDate ?? Date()
                showSheet = true
            } label: {
                HStack(spacing: 8) {
                    Text(labelText)
                        .font(.system(size: 14, weight: .medium))

                    Image(systemName: hasFilter ? "calendar.badge.clock" : "calendar")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(hasFilter ? OfficerTheme.accentGreen : OfficerTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(OfficerTheme.filterBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSheet) {
                NavigationStack {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SELECT RANGE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(OfficerTheme.textSecondary)
                                .padding(.leading, 4)

                            VStack(spacing: 0) {
                                DatePicker("Start Date", selection: $tempStart, displayedComponents: .date)
                                    .padding(.vertical, 12)
                                Divider()
                                DatePicker("End Date", selection: $tempEnd, in: tempStart..., displayedComponents: .date)
                                    .padding(.vertical, 12)
                            }
                            .padding(.horizontal, 16)
                            .background(OfficerTheme.filterBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.top, 24)

                        Spacer()

                        VStack(spacing: 12) {
                            Button {
                                startDate = tempStart
                                endDate = tempEnd
                                showSheet = false
                            } label: {
                                Text("Apply Filter")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(OfficerTheme.accentGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button {
                                startDate = nil
                                endDate = nil
                                showSheet = false
                            } label: {
                                Text("Clear Filter")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(OfficerTheme.iconRed)
                                    .padding(.vertical, 8)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 24)
                    .navigationTitle("Date Filter")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        // Removed Done button as per request
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private struct ApplicationsFilterMenu: View {
        @Binding var selectedStatus: StatusFilter

        private var hasActiveFilters: Bool {
            selectedStatus != .all
        }

        private var labelText: String {
            selectedStatus == .all ? "Status" : selectedStatus.title
        }

        var body: some View {
            Menu {
                ForEach(StatusFilter.allCases) { option in
                    Button {
                        selectedStatus = option
                    } label: {
                        if selectedStatus == option {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
                
                if hasActiveFilters {
                    Divider()
                    Button(role: .destructive) {
                        selectedStatus = .all
                    } label: {
                        Label("Clear Status", systemImage: "xmark.circle")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(labelText)
                        .font(.system(size: 14, weight: .medium))

                    Image(systemName: hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(hasActiveFilters ? OfficerTheme.accentGreen : OfficerTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(OfficerTheme.filterBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private struct ApplicationsFilterMenuRow: View {
        let title: String
        let value: String

        var body: some View {
            HStack(spacing: 12) {
                Text(title)

                Spacer()

                Text(value)
                    .foregroundStyle(OfficerTheme.textSecondary)
            }
        }
    }
    
    // MARK: - Filter Chip
    
    private struct OfficerFilterChip: View {
        let title: String
        let isSelected: Bool
        var color: Color = OfficerTheme.accentGreen
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: true)
                    .foregroundStyle(isSelected ? .white : OfficerTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(isSelected ? color : OfficerTheme.filterBackground)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Badges
    
    
    private struct OfficerStatusBadge: View {
        let status: LoanApplicationStatus
        
        var body: some View {
            Text(status.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(status.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
    
    private struct CreditBadge: View {
        let score: Int
        
        private var color: Color {
            if score >= 750 { return OfficerTheme.iconGreen }
            if score >= 680 { return OfficerTheme.iconAmber }
            return OfficerTheme.iconRed
        }
        
        var body: some View {
            Text("\(score)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
    
    // MARK: - Detail Row
    
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
    
    // MARK: - Section Header
    
    private struct OfficerSectionHeader: View {
        let title: String
        var subtitle: String? = nil
        
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Text Extension
    
//    private extension Text {
//        func officerTableHeaderStyle() -> some View {
//            self
//                .font(.system(size: 12, weight: .medium))
//                .foregroundStyle(.secondary)
//        }
//    }
    
    // MARK: - Button Styles
    
    private struct WidePrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(OfficerTheme.accentGreen.opacity(configuration.isPressed ? 0.8 : 1))
                )
        }
    }
    
    private struct WideSecondaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(OfficerTheme.reject.opacity(configuration.isPressed ? 0.14 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(OfficerTheme.reject.opacity(0.16), lineWidth: 1)
                )
        }
    }
}
extension Text {
    func officerTableHeaderStyle() -> some View {
        self
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }
}
