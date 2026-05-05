import SwiftUI
import WebKit

// MARK: - Modern Components

struct ModernMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let secondaryValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                Spacer()
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                if let secondaryValue, !secondaryValue.isEmpty {
                    Text(secondaryValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 168, alignment: .topLeading)
    }
}

struct ModernDropdownRow<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let labelProvider: (T) -> String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Menu {
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(labelProvider(option)).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(labelProvider(selection))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appGreen)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.vertical, 4)
    }
}

struct ModernToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.appGreen)
        }
        .padding(.vertical, 8)
    }
}

struct ModernReportRow: View {
    let report: GeneratedReport
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(report.type.tint.opacity(0.12))
                    .frame(width: 52, height: 52)
                
                Image(systemName: report.format == .pdf ? "doc.fill" : "tablecells.fill")
                    .font(.system(size: 20))
                    .foregroundColor(report.type.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(report.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(report.generatedAt.split(separator: ",").first ?? "")
                    Text("•")
                    Text(report.format.rawValue)
                        .fontWeight(.bold)
                        .foregroundColor(report.type.tint)
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if let urlString = report.fileUrl, let url = URL(string: urlString) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appBlue)
                            .frame(width: 36, height: 36)
                            .background(Color.appBlue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    if report.format == .pdf {
                        NavigationLink(destination: ReportWebView(url: url, title: report.name)) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appGreen)
                                .frame(width: 36, height: 36)
                                .background(Color.appGreen.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appRed)
                        .frame(width: 36, height: 36)
                        .background(Color.appRed.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

struct ReportWebView: View {
    let url: URL
    let title: String
    
    var body: some View {
        WebView(url: url)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct UserCard: View {
    let user: UserItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                // Avatar / Initials
                Text(user.initials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appGreen)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(Color.appGreen.opacity(0.12))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.appGreen.opacity(0.2), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                // Status Badge
                Text(user.status.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(user.status.textColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(user.status.backgroundColor)
                    .clipShape(Capsule())
            }

            Divider()
                .opacity(0.6)

            HStack(spacing: 20) {
                Label {
                    Text(user.branch)
                        .font(.caption)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "building.2")
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                Label {
                    Text(user.role.title)
                        .font(.caption)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "person.text.rectangle")
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.appGreen.opacity(0.8))
                    .font(.title3)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct AddUserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedRole: UserRole = .officer
    @State private var selectedBranch: Branch = .north
    
    @State private var showAlert = false
    @State private var alertMessage = ""

    var onInvite: (String, String, String, UserRole, String) -> Void
    
    private var isFormComplete: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = phone.filter { $0.isNumber }
        return !trimmedName.isEmpty &&
            !trimmedEmail.isEmpty &&
            isValidEmail(trimmedEmail) &&
            digitsOnly.count == 10
    }

    var body: some View {
        Form {
            Section("User Details") {
                TextField("Full Name", text: $name)
                TextField("Email Address", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                TextField("Phone Number (10 digits)", text: $phone)
                    .keyboardType(.numberPad)
            }

            Section("Branch") {
                Picker("Select Branch", selection: $selectedBranch) {
                    ForEach(Branch.allCases) { branch in
                        Text(branch.title).tag(branch)
                    }
                }
            }

            Section("Role") {
                Picker("Select Role", selection: $selectedRole) {
                    Text("Manager").tag(UserRole.manager)
                    Text("Loan Officer").tag(UserRole.officer)
                }
            }

            Section {
                Button {
                    validateAndSubmit()
                } label: {
                    Text("Add User")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
                .disabled(!isFormComplete)
            }
        }
        .navigationTitle("Add New User")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Validation Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func validateAndSubmit() {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            alertMessage = "Please enter a full name."
            showAlert = true
            return
        }
        
        if !isValidEmail(email) {
            alertMessage = "Please enter a valid email address."
            showAlert = true
            return
        }
        
        let digitsOnly = phone.filter { $0.isNumber }
        if digitsOnly.count != 10 {
            alertMessage = "Phone number must be exactly 10 digits."
            showAlert = true
            return
        }
        
        onInvite(name, email, digitsOnly, selectedRole, selectedBranch.rawValue)
        dismiss()
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

struct UserDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let user: UserItem
    @Bindable var controller: AdminDashboardViewModel

    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var displayStatus: UserVerificationStatus
    @State private var showEditSheet = false
    @State private var showDeactivateConfirm = false
    @State private var showBlockConfirm = false

    init(user: UserItem, controller: AdminDashboardViewModel) {
        self.user = user
        self.controller = controller
        _name = State(initialValue: user.name)
        _email = State(initialValue: user.email)
        let digits = user.phone.filter { $0.isNumber }
        let cleanPhone = digits.count > 10 ? String(digits.suffix(10)) : digits
        _phone = State(initialValue: cleanPhone)
        _displayStatus = State(initialValue: user.status)
    }

    private var isBlocked: Bool {
        displayStatus == .blocked
    }

    var body: some View {
        List {
            // Avatar header
            Section {
                VStack(spacing: 12) {
                    Text(user.initials)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.appGreen)
                        .frame(width: 88, height: 88)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.appGreen.opacity(0.2), lineWidth: 1.5))

                    VStack(spacing: 4) {
                        Text(name)
                            .font(.title2.bold())
                        // email removed from header
                    }

                    AppStatusBadge(text: displayStatus.title, color: displayStatus.textColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section("Contact Information") {
                LabeledContent("Email", value: email)
                LabeledContent("Phone", value: phone.isEmpty ? "Not set" : phone)
            }

            Section("Account Details") {
                LabeledContent("Role", value: user.role.title)
                LabeledContent("Branch", value: user.branch)
                LabeledContent("Joined", value: user.joined)
            }

            Section {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit Profile", systemImage: "pencil")
                        .foregroundColor(.appGreen)
                }

                Button(role: isBlocked ? nil : .destructive) {
                    showBlockConfirm = true
                } label: {
                    Label(isBlocked ? "Unblock User" : "Block User", systemImage: isBlocked ? "lock.open.fill" : "lock.fill")
                        .foregroundColor(isBlocked ? .appGreen : .appRed)
                }

                Button(role: .destructive) {
                    showDeactivateConfirm = true
                } label: {
                    Label("Remove User", systemImage: "trash")
                        .foregroundColor(.appRed)
                }
            }
        }
        .navigationTitle("User Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    Section("Personal Information") {
                        TextField("Full Name", text: $name)
                        TextField("Email Address", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Phone Number", text: $phone)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("Edit User")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showEditSheet = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            let digitsOnly = phone.filter { $0.isNumber }
                            controller.updateUser(id: user.id, name: name, email: email, phone: digitsOnly, role: user.role, branch: user.branch)
                            showEditSheet = false
                        }
                        .bold()
                        .tint(.appGreen)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || phone.filter { $0.isNumber }.count != 10)
                    }
                }
            }
        }
        .alert("Remove User?", isPresented: $showDeactivateConfirm) {
            Button("Remove Permanently", role: .destructive) {
                controller.deleteUser(id: user.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \(name) from the system. This action cannot be undone.")
        }
        .alert(isBlocked ? "Unblock User?" : "Block User?", isPresented: $showBlockConfirm) {
            Button(isBlocked ? "Unblock" : "Block", role: isBlocked ? nil : .destructive) {
                let shouldBlock = !isBlocked
                displayStatus = shouldBlock ? .blocked : .verified
                controller.setUserBlocked(id: user.id, name: name, branch: user.branch, isBlocked: shouldBlock)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isBlocked ? "\(name) will be allowed to sign in again." : "\(name) will be blocked and will not be allowed to sign in.")
        }
    }
}

struct AuditTableRow: View {
    let entry: AuditEntry

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(entry.iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: entry.displayIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(entry.iconColor)
            }
            .overlay(
                Circle()
                    .stroke(entry.iconColor.opacity(0.15), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text(entry.displayActor)
                        .fontWeight(.medium)
                    Text("•")
                    Text(entry.time)
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }

            Spacer()

            Text(entry.displayStatus)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(entry.statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(entry.statusColor.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(entry.statusColor.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}


struct DemoReportView: View {
    let report: GeneratedReport

    private var reportId: String {
        "RPT-" + report.id.uuidString.prefix(8).uppercased()
    }

    private var executiveSummary: String {
        switch report.type {
        case .portfolioHealth:
            return "Portfolio health remains stable with steady disbursement quality, controlled defaults, and healthy branch-level collection momentum."
        case .repaymentTrend:
            return "Repayment trend is positive, with improving on-time payments and reduced overdue migration across recent billing cycles."
        case .npaAnalysis:
            return "NPA exposure is concentrated in a few legacy pockets; risk remains manageable with active recovery and tighter underwriting checks."
        case .auditCompliance:
            return "Audit controls show strong compliance posture with no critical exceptions and complete activity traceability enabled."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Loan Management System")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(report.name)
                        .font(.system(size: 34, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("\(report.range.title) · Generated \(report.generatedAt)")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(20)
                .background(Color.appCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 16, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Report Control")
                        .font(.title3.weight(.semibold))
                    reportLine("Report ID", reportId)
                    reportLine("Type", report.type.title)
                    reportLine("Format", report.format.title)
                    reportLine("Audit Trail", report.includesAuditTrail ? "Included" : "Excluded")
                    reportLine("Branch Breakdown", report.includesBranchBreakdown ? "Included" : "Excluded")
                }
                .padding(20)
                .background(Color.appCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 16, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Executive Summary")
                        .font(.title3.weight(.semibold))
                    Text(executiveSummary)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .minimumScaleFactor(0.92)
                }
                .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                .padding(20)
                .background(Color.appCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 16, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Portfolio Metrics")
                        .font(.title3.weight(.semibold))
                    metricRow("Total Active Loans", "1,284", "↑ 3.2%")
                    metricRow("Collection Efficiency", "93.4%", "↑ 1.1%")
                    metricRow("Average Yield", "11.8%", "Stable")
                    metricRow("NPA Ratio", "2.3%", "↓ 0.4%")
                }
                .padding(20)
                .background(Color.appCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 16, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Branch Summary")
                        .font(.title3.weight(.semibold))
                    branchRow("Main Branch", "Rs 8.4M", "97.1%")
                    branchRow("East Branch", "Rs 5.1M", "94.8%")
                    branchRow("West Branch", "Rs 3.8M", "91.6%")
                }
                .padding(20)
                .background(Color.appCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 16, x: 0, y: 10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reportLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func metricRow(_ title: String, _ value: String, _ trend: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(trend)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appGreen)
                .frame(width: 70, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
    }

    private func branchRow(_ name: String, _ exposure: String, _ efficiency: String) -> some View {
        HStack {
            Text(name)
                .font(.body.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.88)
            Spacer()
            Text(exposure)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(efficiency)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appGreen)
                .frame(width: 70, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .padding(.vertical, 4)
    }
}

struct LiquidGlassBackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color.appSecondary, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}


struct DocumentViewSheet: View {
    let url: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if url.pathExtension.lowercased() == "pdf" {
                    // PDF viewing logic
                    Text("PDF Viewer - \(url.lastPathComponent)")
                } else {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                }
            }
            .navigationTitle("Document View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
