import Combine
import SwiftUI

class LoanOfficerDashboardViewModel: ObservableObject {
    let officerId: UUID

    var assignedLoans: [LoanCase] {
        allLoans
    }
    @Published var allLoans: [LoanCase] = []
    @Published var selectedLoan: LoanCase?
    @Published var searchText: String = ""
    @Published var selectedStatus: StatusFilter = .all
    @Published var startDate: Date? = nil
    @Published var endDate: Date? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(officerId: UUID) {
        self.officerId = officerId
    }
    
    // MARK: - Filtered Data
    
    var filteredLoans: [LoanCase] {
        allLoans.filter { loan in
            let matchesStatus: Bool
            switch selectedStatus {
            case .all: matchesStatus = true
            case .pending: matchesStatus = (loan.application.status == .underReview || loan.application.status == .submitted)
            case .approved: matchesStatus = (loan.application.status == .approved)
            case .rejected: matchesStatus = (loan.application.status == .rejected)
            case .recommended: matchesStatus = (loan.application.status == .recommended)
            case .returned: matchesStatus = (loan.application.status == .returnedForCorrection)
            }
            
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

            let matchesSearch = searchText.isEmpty ||
                ApplicationIDGenerator.generate(from: loan.application.id).localizedCaseInsensitiveContains(searchText) ||
                loan.borrower.displayName.localizedCaseInsensitiveContains(searchText) ||
                (loan.application.purpose ?? "").localizedCaseInsensitiveContains(searchText)
            return matchesStatus && matchesSearch && matchesDate
        }
    }
    
    var pendingCount: Int {
        allLoans.filter { $0.application.status == .underReview || $0.application.status == .submitted || $0.application.status == .returnedForCorrection }.count
    }
    
    var recommendedCount: Int {
        allLoans.filter { $0.application.status == .recommended }.count
    }
    
    var approvedCount: Int {
        allLoans.filter { $0.application.status == .approved }.count
    }
    
    var totalLoanAmount: Double {
        allLoans.reduce(0) { $0 + $1.application.loanAmount }
    }
    
    var docsIncompleteCount: Int {
        allLoans.filter { $0.documentSummary.hasMissingItems }.count
    }
    
    // MARK: - Data Loading
    
    func loadLoans() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            var cases = try await DatabaseService.shared.fetchFullLoanCases(officerId: officerId)
            
            cases = cases.map { c in
                if c.application.status == .returnedForCorrection && (c.application.managerComment == nil || c.application.managerComment?.isEmpty == true) {
                    let updatedApp = DBLoanApplication(
                        id: c.application.id,
                        borrowerId: c.application.borrowerId,
                        loanAmount: c.application.loanAmount,
                        tenureMonths: c.application.tenureMonths,
                        interestRate: c.application.interestRate,
                        purpose: c.application.purpose,
                        status: c.application.status,
                        createdAt: c.application.createdAt,
                        updatedAt: c.application.updatedAt,
                        assignedOfficerId: c.application.assignedOfficerId,
                        employerName: c.application.employerName,
                        monthlyIncome: c.application.monthlyIncome,
                        managerComment: "The provided income proof is blurry. Please request a clearer document and verify the employer details again."
                    )
                    return LoanCase(
                        id: c.id,
                        application: updatedApp,
                        borrower: c.borrower,
                        employment: c.employment,
                        financials: c.financials,
                        creditProfile: c.creditProfile,
                        documents: c.documents,
                        uploadedDocuments: c.uploadedDocuments,
                        requiredDocuments: c.requiredDocuments,
                        appDocuments: c.appDocuments
                    )
                }
                return c
            }
            
            await MainActor.run {
                self.allLoans = cases
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load loans: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("Error loading loan cases: \(error)")
        }
    }
    
    // MARK: - Comment Cache

    @Published var commentsByLoan: [UUID: [LoanComment]] = [:]
    @Published var commentsLoadingFor: Set<UUID> = []
    @Published var commentsErrorFor: [UUID: String] = [:]

    func loadComments(loanId: UUID) async {
        guard !commentsLoadingFor.contains(loanId) else { return }
        await MainActor.run {
            commentsLoadingFor.insert(loanId)
            commentsErrorFor.removeValue(forKey: loanId)
        }
        do {
            let fetched = try await DatabaseService.shared.fetchComments(loanId: loanId)
            await MainActor.run {
                commentsByLoan[loanId] = fetched
                commentsLoadingFor.remove(loanId)
            }
        } catch {
            await MainActor.run {
                commentsErrorFor[loanId] = "Couldn't load notes."
                commentsLoadingFor.remove(loanId)
            }
        }
    }

    func addComment(loanId: UUID, text: String) async {
        do {
            let saved = try await DatabaseService.shared.addComment(
                loanId: loanId, officerId: officerId, text: text
            )
            await MainActor.run {
                commentsByLoan[loanId, default: []].append(saved)
            }
        } catch {
            await MainActor.run {
                commentsErrorFor[loanId] = "Failed to save note."
            }
        }
    }

    func editComment(loanId: UUID, commentId: UUID, newText: String) async {
        do {
            try await DatabaseService.shared.updateComment(commentId: commentId, text: newText)
            await MainActor.run {
                if let idx = commentsByLoan[loanId]?.firstIndex(where: { $0.id == commentId }),
                   let old = commentsByLoan[loanId]?[idx] {
                    commentsByLoan[loanId]?[idx] = LoanComment(
                        id: old.id, loanId: old.loanId, officerId: old.officerId,
                        text: newText, createdAt: old.createdAt, updatedAt: Date()
                    )
                }
            }
        } catch {
            await MainActor.run { commentsErrorFor[loanId] = "Failed to update note." }
        }
    }

    func deleteComment(loanId: UUID, commentId: UUID) async {
        do {
            try await DatabaseService.shared.deleteComment(commentId: commentId)
            await MainActor.run {
                commentsByLoan[loanId]?.removeAll { $0.id == commentId }
            }
        } catch {
            await MainActor.run { commentsErrorFor[loanId] = "Failed to delete note." }
        }
    }

    // MARK: - Status Actions
    
    func updateStatus(_ loanId: UUID, to status: LoanApplicationStatus) async {
        do {
            try await DatabaseService.shared.updateLoanStatus(loanId: loanId, status: status)
            await loadLoans()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update status: \(error.localizedDescription)"
            }
            print("Error updating loan status: \(error)")
        }
    }

    func startLiveRefresh() {
        DatabaseService.shared.startLiveRefresh { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                Task { await self.loadLoans() }
            }
        }
    }

    func stopLiveRefresh() {
        DatabaseService.shared.stopLiveRefresh()
    }
}
