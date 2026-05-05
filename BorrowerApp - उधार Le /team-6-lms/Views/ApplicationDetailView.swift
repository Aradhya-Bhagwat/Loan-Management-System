import SwiftUI
import SafariServices

// MARK: - Application Detail View
struct ApplicationDetailView: View {
    let application: LoanApplication
    @Environment(\.dismiss) var dismiss

    @State private var assignedOfficer: LoanOfficer?
    @State private var isFetchingOfficer = false
    @State private var showReapplyForm = false
    @State private var activeLoan: ActiveLoan?
    @State private var showSanctionLetterPreview = false
    @State private var isDownloading = false
    @State private var showShareSheet = false
    @State private var downloadedFileURL: URL?
    @State private var chatDestination: ChatDestination? = nil

    struct ChatDestination: Identifiable {
        let id = UUID()
        let applicationId: UUID
        let borrowerId: UUID
        let officerId: UUID
        let officerName: String
    }

    var timelineSteps: [TimelineStep] {
        TimelineCalculator.calculate(for: effectiveStatus)
    }

    var effectiveStatus: ApplicationStatus {
        if (application.status == .submitted || application.status == .underReview || application.status == .recommended),
           activeLoan != nil {
            return .approved
        }
        return application.status
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                StatusHeaderCard(application: application, effectiveStatus: effectiveStatus)

                SectionHeader(title: "Application Journey")
                CardView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(timelineSteps.enumerated()), id: \.offset) { index, step in
                                NativeTimelineRow(
                                    step: step,
                                    applicationStatus: effectiveStatus,
                                    isLast: index == timelineSteps.count - 1
                                )
                        }
                    }
                    .padding(20)
                }

                SectionHeader(title: "Loan Summary")
                CardView {
                    VStack(spacing: 0) {
                        LabeledRow(label: "Purpose", value: application.purpose)
                        Divider().padding(.horizontal, 16)
                        LabeledRow(label: "Amount", value: "₹\(Int(application.loanAmount).formatted())")
                        Divider().padding(.horizontal, 16)
                        LabeledRow(label: "Tenure", value: "\(application.tenureMonths) Months")
                        Divider().padding(.horizontal, 16)
                        LabeledRow(label: "Interest Rate", value: "\(application.interestRate ?? 10.5)%")
                        Divider().padding(.horizontal, 16)

                        HStack {
                            Text("Current State")
                                .font(.subheadline)
                                .foregroundStyle(Color.theme.textSecondary)
                            Spacer()
                            Text(effectiveStatus.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(effectiveStatus.color)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(effectiveStatus.color.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }

                if (effectiveStatus == .approved || effectiveStatus == .disbursed),
                   let url = activeLoan?.sanctionLetterUrl, !url.isEmpty {
                    SectionHeader(title: "Sanction Letter")
                    CardView {
                        VStack(spacing: 16) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.theme.primaryAccent.opacity(0.1))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "doc.text.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.theme.primaryAccent)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sanction Letter")
                                        .font(.headline)
                                        .foregroundStyle(Color.theme.textPrimary)
                                    Text("Official loan approval document")
                                        .font(.caption)
                                        .foregroundStyle(Color.theme.textSecondary)
                                }
                                Spacer()

                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.theme.success)
                            }

                            HStack(spacing: 12) {
                                Button {
                                    showSanctionLetterPreview = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "eye.fill")
                                        Text("View")
                                    }
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(Color.theme.primaryAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.theme.primaryAccent.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                                Button {
                                    downloadFile(from: url)
                                } label: {
                                    HStack(spacing: 6) {
                                        if isDownloading {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "arrow.down.doc.fill")
                                            Text("Download")
                                        }
                                    }
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(Color.theme.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isDownloading ? Color.theme.primaryAccent.opacity(0.6) : Color.theme.primaryAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .disabled(isDownloading)
                            }
                        }
                        .padding(16)
                    }
                }

                if let officer = assignedOfficer {
                    SectionHeader(title: "Assigned Officer")
                    CardView {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(Color.theme.success.opacity(0.1))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(Color.theme.success)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(officer.fullName)
                                    .font(.headline)
                                    .foregroundStyle(Color.theme.textPrimary)
                                Text(officer.role)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.theme.textSecondary)
                            }
                            Spacer()

                            Button(action: {
                                if let appId = application.id,
                                   let bId = application.borrowerId,
                                   let oId = application.assignedOfficerId {
                                    chatDestination = ChatDestination(
                                        applicationId: appId,
                                        borrowerId: bId,
                                        officerId: oId,
                                        officerName: officer.fullName
                                    )
                                }
                            }) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.theme.primaryAccent)
                                    .clipShape(Circle())
                                    .shadow(color: Color.theme.primaryAccent.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                        }
                        .padding(16)
                    }
                }

                if effectiveStatus == .rejected {
                    Button(action: { showReapplyForm = true }) {
                        Text("Reapply for Loan")
                            .font(.headline)
                            .foregroundStyle(Color.theme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.theme.primaryAccent)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Text("You can reapply with updated documents after addressing the rejection reasons.")
                        .font(.caption)
                        .foregroundStyle(Color.theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                }

                Spacer(minLength: 32)
            }
        }
        .background(Color.theme.appBackground.ignoresSafeArea())
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showSanctionLetterPreview) {
            if let urlString = activeLoan?.sanctionLetterUrl, let url = URL(string: urlString) {
                SanctionLetterPreviewView(url: url)
                    .ignoresSafeArea()
            } else {

                Color.clear.onAppear { showSanctionLetterPreview = false }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedFileURL {
                ActivityView(activityItems: [url])
            }
        }
        .fullScreenCover(isPresented: $showReapplyForm) {
            LoanApplicationFormView(prefillApplication: application)
        }
        .fullScreenCover(item: $chatDestination) { dest in
            NavigationStack {
                BorrowerChatView(
                    applicationId: dest.applicationId,
                    borrowerId: dest.borrowerId,
                    officerId: dest.officerId,
                    officerName: dest.officerName
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { chatDestination = nil }
                            .foregroundStyle(Color.theme.primaryAccent)
                    }
                }
            }
        }
        .task {
            await loadData()

            if let officerId = application.assignedOfficerId {
                isFetchingOfficer = true
                do {
                    assignedOfficer = try await SupabaseManager.shared.fetchOfficer(id: officerId)
                } catch {
                    print("Error fetching officer: \(error)")
                }
                isFetchingOfficer = false
            }
        }
    }

    private func loadData() async {
        guard let appId = application.id else { return }
        do {
            let loans = try await SupabaseManager.shared.fetchActiveLoans()
            print("🔍 ApplicationDetailView: fetched \(loans.count) active loans for appId \(appId.uuidString.prefix(8))")
            for loan in loans {
                print("   active_loan.applicationId=\(loan.applicationId.uuidString.prefix(8)) match=\(loan.applicationId == appId)")
            }
            self.activeLoan = loans.first(where: { $0.applicationId == appId })
            print("🔍 activeLoan found: \(self.activeLoan != nil), effectiveStatus=\(effectiveStatus.rawValue)")
        } catch {
            print("Error fetching active loan: \(error)")
        }
    }

    private func downloadFile(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        isDownloading = true

        let loanAmount = application.loanAmount
        URLSession.shared.downloadTask(with: url) { localURL, response, error in
            DispatchQueue.main.async {
                self.isDownloading = false
            }

            if let error = error {
                print("Download error: \(error)")
                return
            }

            guard let localURL = localURL else { return }

            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let destinationURL = tempDir.appendingPathComponent("Sanction_Letter_\(Int(loanAmount)).pdf")

            try? fileManager.removeItem(at: destinationURL)

            do {
                try fileManager.moveItem(at: localURL, to: destinationURL)
                DispatchQueue.main.async {
                    self.downloadedFileURL = destinationURL
                    self.showShareSheet = true
                }
            } catch {
                print("File move error: \(error)")
            }
        }.resume()
    }
}

// MARK: - Preview View (Safari Wrapper)
struct SanctionLetterPreviewView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = UIColor(Color.theme.primaryAccent)
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Status Header Component
struct StatusHeaderCard: View {
    let application: LoanApplication
    let effectiveStatus: ApplicationStatus

    var body: some View {
        if effectiveStatus == .approved || effectiveStatus == .disbursed {
            VStack(alignment: .leading, spacing: 12) {
                Text("CURRENT STATUS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme.textSecondary)

                Text(effectiveStatus == .approved ? "APPROVED" : "DISBURSED")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(Color.theme.textPrimary)

                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.textSecondary)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color.theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
            .padding(.horizontal, 20)
            .padding(.top, 16)
        } else {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(effectiveStatus.color.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: statusIcon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(effectiveStatus.color)
                }
                .padding(.top, 10)

                Text(effectiveStatus.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(effectiveStatus.color)

                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color.theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var statusIcon: String {
        switch effectiveStatus {
        case .submitted: return "paperplane.fill"
        case .underReview: return "magnifyingglass"
        case .recommended: return "hand.thumbsup.fill"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.circle.fill"
        case .disbursed: return "indianrupeesign.circle.fill"
        }
    }

    private var statusDescription: String {
        switch effectiveStatus {
        case .submitted: return "Your application has been received and is waiting for initial verification."
        case .underReview: return "Our credit team is currently verifying your documents and credit profile."
        case .recommended: return "Your application has been recommended for approval by the credit officer."
        case .approved: return "Congratulations! Your loan has been approved and will be disbursed shortly."
        case .rejected: return "Unfortunately, your application could not be approved at this time."
        case .disbursed: return "The loan amount has been successfully transferred to your registered bank account."
        }
    }
}

// MARK: - Reusable UI Helpers

struct NativeTimelineRow: View {
    let step: TimelineStep
    let applicationStatus: ApplicationStatus
    let isLast: Bool

    var iconName: String {
        if step.title == "Rejected" { return "xmark.circle.fill" }
        switch step.state {
        case .completed: return "checkmark.circle.fill"
        case .active:    return "circle.fill"
        case .pending:   return "circle"
        }
    }

    var iconColor: Color {
        if step.title == "Rejected" { return Color.theme.danger }
        switch step.state {
        case .completed: return Color.theme.primaryAccent
        case .active:    return Color.theme.primaryAccent
        case .pending:   return Color.gray.opacity(0.3)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)
                if !isLast {
                    Rectangle()
                        .fill(step.state == .completed
                              ? Color.theme.primaryAccent
                              : Color.gray.opacity(0.15))
                        .frame(width: 2)
                        .frame(minHeight: 40)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.body)
                    .fontWeight(step.state == .active && step.title != "Rejected" ? .semibold : .regular)
                    .foregroundStyle(step.state == .pending ? Color.theme.textSecondary.opacity(0.7) : Color.theme.textPrimary)

                Text(step.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if step.state == .active && applicationStatus != .approved && applicationStatus != .disbursed && applicationStatus != .rejected {
                    Label("Processing", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.theme.primaryAccent)
                        .clipShape(Capsule())
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
    }
}

// MARK: - Timeline Helpers
struct TimelineStep: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let state: TimelineState
}

enum TimelineState {
    case completed, active, pending
}

struct TimelineCalculator {
    static func calculate(for status: ApplicationStatus) -> [TimelineStep] {
        var steps: [TimelineStep] = []

        steps.append(TimelineStep(
            title: "Application Submitted",
            subtitle: "Received and queued for review.",
            state: .completed
        ))

        steps.append(TimelineStep(
            title: "Under Review",
            subtitle: "Verification of documents in progress.",
            state: status == .submitted ? .pending :
                   (status == .underReview || status == .recommended) ? .active : .completed
        ))

        if status == .rejected {
            steps.append(TimelineStep(
                title: "Rejected",
                subtitle: "Application could not be approved at this time.",
                state: .active
            ))
        } else {

            steps.append(TimelineStep(
                title: "Approved",
                subtitle: status == .approved ? "Loan approved. Awaiting disbursement." : "Finalizing disbursement details.",
                state: (status == .submitted || status == .underReview || status == .recommended) ? .pending :
                       status == .approved ? .completed : .completed
            ))

            if status == .disbursed {
                steps.append(TimelineStep(
                    title: "Disbursed",
                    subtitle: "Funds transferred to your account.",
                    state: .completed
                ))
            }
        }

        return steps
    }
}
