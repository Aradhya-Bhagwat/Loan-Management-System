

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import Supabase

// MARK: - Main Profile View
struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthManager.self) private var authManager

    @AppStorage("currentBorrowerId") var currentBorrowerId: String?

    @State private var currentBorrower: BorrowerProfile?
    @State private var currentDocs: BorrowerDocuments?
    @State private var currentEmployment: Employment?
    @State private var isLoading = true
    @State private var isSigningOut = false
    @State private var showEditEmployment = false
    @State private var showKYCVerification = false
    @State private var isSiriExpanded = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english.rawValue

    private let siriCommands = [
        SiriCommand(
            title: "Loan Status",
            subtitle: "Track your application",
            phrase: "Check my loan status",
            icon: "doc.text.magnifyingglass",
            color: .blue
        ),
        SiriCommand(
            title: "Next EMI",
            subtitle: "View upcoming payment",
            phrase: "When is my next EMI due?",
            icon: "calendar.badge.clock",
            color: .orange
        ),
        SiriCommand(
            title: "Total Balance",
            subtitle: "Check outstanding debt",
            phrase: "How much do I owe?",
            icon: "indianrupeesign.circle",
            color: .green
        )
    ]

    var kycStatus: (label: String, color: Color, backgroundColor: Color) {
        guard let docs = currentDocs else { return ("Action Required", Color.theme.danger, Color.theme.dangerBackground) }
        let hasPan = docs.panDocUrl != nil && !docs.panDocUrl!.isEmpty
        let hasAadhaar = docs.aadhaarDocUrl != nil && !docs.aadhaarDocUrl!.isEmpty
        let hasIncome = docs.incomeProofUrl != nil && !docs.incomeProofUrl!.isEmpty
        let hasCollateral = docs.collateralDocUrl != nil && !docs.collateralDocUrl!.isEmpty
        let hasBusiness = docs.businessProofUrl != nil && !docs.businessProofUrl!.isEmpty

        let panVerified = currentBorrower?.panVerified ?? false
        let aadhaarVerified = currentBorrower?.aadhaarVerified ?? false

        let allRequiredUploaded = hasPan && hasAadhaar && hasIncome
        let allRequiredVerified = panVerified && aadhaarVerified

        if allRequiredUploaded && allRequiredVerified {
            return ("KYC Verified", Color.theme.success, Color.theme.successBackground)
        } else if hasPan || hasAadhaar || hasIncome || hasCollateral || hasBusiness {
            return ("KYC Pending", Color.theme.warning, Color.theme.warningBackground)
        } else {
            return ("Upload Docs", Color.theme.danger, Color.theme.dangerBackground)
        }
    }

    @AppStorage("useBiometrics") private var enableFaceID = false
    @State private var enableNotifications = true

    var body: some View {

        ZStack {
            Color.theme.appBackground.ignoresSafeArea()

            if isLoading {
                ProgressView("Loading Profile...")
                    .foregroundStyle(Color.theme.textPrimary)
            } else {
                List {
                    // MARK: - Hero Section
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color.theme.primaryAccent.gradient)
                            .shadow(radius: 5)

                        HStack(spacing: 6) {
                            Text(currentBorrower?.fullName ?? "Unknown User")
                                .font(.title).fontWeight(.heavy)
                                .foregroundStyle(Color.theme.textPrimary)
                        }

                        Text(currentBorrower?.email ?? "No Email")
                            .font(.subheadline)
                            .foregroundStyle(Color.theme.textSecondary)

                        HStack(spacing: 5) {
                            Image(systemName: kycStatus.label == "KYC Verified" ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                                .font(.caption2)
                            Text(kycStatus.label == "KYC Verified" ? "KYC Complete" : "KYC Incomplete")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(kycStatus.color)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(kycStatus.backgroundColor)
                        .clipShape(Capsule())
                        .padding(.top, 4)

                        if kycStatus.label != "KYC Verified" {
                            Button {
                                showKYCVerification = true
                            } label: {
                                Label("Verify KYC", systemImage: "checkmark.shield.fill")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(Color.theme.primaryText)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(Color.theme.primaryAccent)
                                    .clipShape(Capsule())
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)

                    // MARK: - Credit & Financial Standing
                    Section {
                        VStack(spacing: 16) {
                            Text("CIBIL Score")
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundStyle(Color.theme.textSecondary)

                            ZStack {
                                Circle()
                                    .trim(from: 0, to: 0.5)
                                    .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                    .frame(width: 150, height: 150)
                                    .rotationEffect(.degrees(180))

                                Circle()
                                    .trim(from: 0, to: 0.38)
                                    .stroke(AngularGradient(gradient: Gradient(colors: [.yellow, .green]), center: .center), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                    .frame(width: 150, height: 150)
                                    .rotationEffect(.degrees(180))

                                VStack(spacing: 0) {
                                    let score = currentBorrower?.creditScore ?? 0
                                    Text("\(score)")
                                        .font(.system(size: 40, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.theme.textPrimary)

                                    let label = score >= 750 ? "Excellent" : score >= 700 ? "Very Good" : score >= 650 ? "Good" : "Fair"
                                    let color = score >= 750 ? Color.theme.success : score >= 700 ? Color.theme.primaryAccent : score >= 650 ? Color.theme.warning : Color.theme.danger

                                    Text(label)
                                        .font(.caption).fontWeight(.bold)
                                        .foregroundStyle(color)
                                }
                                .offset(y: -20)
                            }
                            .padding(.bottom, -60)

                            let score = currentBorrower?.creditScore ?? 0
                            let desc = score >= 750 ? "Excellent — You are pre-approved for premium rates." : score >= 700 ? "Very Good — You qualify for great loan offers." : score >= 650 ? "Good — You are eligible for standard rates." : "Fair — Let's work on improving your score."

                            Text(desc)
                                .font(.footnote).fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.theme.cardBackground)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.theme.cardBackground.clipShape(RoundedRectangle(cornerRadius: 16)))

                    // MARK: - Personal Details
                    Section {
                        VStack(spacing: 0) {
                            ProfileDetailRow(title: "Mobile Number", value: currentBorrower?.mobile ?? "N/A")
                            Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                            ProfileDetailRow(title: "Date of Birth", value: currentBorrower?.dob ?? "N/A")
                            Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                            ProfileDetailRow(title: "Occupation", value: currentBorrower?.employmentType ?? "N/A")
                            Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                            ProfileDetailRow(title: "Monthly Income", value: "₹" + (currentBorrower?.declaredMonthlyIncome?.formatted() ?? "0"))
                            Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                            ProfileDetailRow(title: "PAN", value: currentBorrower?.panNumber?.masked() ?? "N/A")
                            Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                            ProfileDetailRow(title: "Aadhaar", value: currentBorrower?.aadhaarNumber?.masked() ?? "N/A")
                            Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                            ProfileDetailRow(title: "Account Number", value: currentBorrower?.bankAccountNumber?.masked() ?? "N/A")
                            Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                            ProfileDetailRow(title: "IFSC Code", value: currentBorrower?.ifscCode?.masked() ?? "N/A")
                        }
                    } header: {
                        Text("Personal Information").foregroundStyle(Color.theme.textSecondary)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.theme.cardBackground)

                    // MARK: - Employment Details
                    Section {
                        VStack(spacing: 0) {
                            if let emp = currentEmployment {
                                ProfileDetailRow(title: "Company", value: emp.companyName ?? "N/A")
                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                ProfileDetailRow(title: "Role", value: emp.jobRole ?? "N/A")
                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                ProfileDetailRow(title: "Industry", value: emp.industryType ?? "N/A")
                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                ProfileDetailRow(title: "Experience", value: "\(emp.yearsExperience ?? 0) Years")
                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                ProfileDetailRow(title: "Monthly Income", value: "₹" + Int(emp.monthlyIncome).formatted())
                            } else {
                                Text("No employment details found.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.theme.textSecondary)
                                    .padding()
                            }
                        }
                    } header: {
                        HStack {
                            Text("Employment Details")
                            Spacer()
                            Button {
                                showEditEmployment = true
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.theme.primaryAccent)
                            }
                        }
                        .foregroundStyle(Color.theme.textSecondary)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.theme.cardBackground)

                    // MARK: - Document Vault
                    Section {
                        let docs = [
                            (title: "Identity Proof (PAN)", type: "PAN", url: currentDocs?.panDocUrl),
                            (title: "Address Proof", type: "Address", url: currentDocs?.aadhaarDocUrl),
                            (title: "Income / Salary Proof", type: "Income", url: currentDocs?.incomeProofUrl),
                            (title: "Collateral Papers", type: "Collateral", url: currentDocs?.collateralDocUrl),
                            (title: "Business Proof", type: "Business Proof", url: currentDocs?.businessProofUrl)
                        ]

                        if docs.isEmpty {
                            Text("No documents uploaded yet.")
                                .font(.subheadline)
                                .foregroundStyle(Color.theme.textSecondary)
                                .padding()
                        } else {
                            ForEach(docs, id: \.type) { doc in
                                CompactProfileDocRow(
                                    title: doc.title,
                                    docType: doc.type,
                                    existingURL: doc.url,
                                    isVerified: {
                                        switch doc.type {
                                        case "PAN":     return currentBorrower?.panVerified ?? false
                                        case "Address": return currentBorrower?.aadhaarVerified ?? false
                                        default:        return false  
                                        }
                                    }(),
                                    onUploaded: { url in
                                        updateLocalDoc(type: doc.type, url: url)
                                        Task { await syncKYCStatus() }
                                    }
                                )
                            }
                            .onDelete { indexSet in
                                let itemsToDelete = indexSet.map { docs[$0] }
                                for item in itemsToDelete {
                                    handleDelete(docType: item.type)
                                }
                            }
                        }
                    } header: {
                        Text("Document Vault").foregroundStyle(Color.theme.textSecondary)
                    } footer: {
                        Text("Swipe left on a document to delete it.")
                            .font(.caption2)
                            .foregroundStyle(Color.theme.textSecondary)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.theme.cardBackground)

                    // MARK: - System & Security Settings
                    Section {
                        Toggle(isOn: $enableFaceID) {
                            Label("FaceID Authentication", systemImage: "faceid")
                                .foregroundStyle(Color.theme.textPrimary)
                        }
                        .tint(Color.theme.primaryAccent)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                        Toggle(isOn: $enableNotifications) {
                            Label("Loan Updates & Alerts", systemImage: "bell.badge.fill")
                                .foregroundStyle(Color.theme.textPrimary)
                        }
                        .tint(Color.theme.primaryAccent)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                        Picker(selection: $appLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang.rawValue)
                            }
                        } label: {
                            Label("App Language", systemImage: "globe")
                                .foregroundStyle(Color.theme.textPrimary)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                        DisclosureGroup(isExpanded: $isSiriExpanded) {
                            VStack(spacing: 12) {
                                ForEach(siriCommands) { command in
                                    SiriCommandCard(command: command)
                                }
                            }
                            .padding(.vertical, 12)
                            .listRowInsets(EdgeInsets())
                        } label: {
                            Label("Siri Shortcuts", systemImage: "waveform.circle.fill")
                                .foregroundStyle(Color.theme.textPrimary)
                        }
                        .tint(Color.theme.textSecondary)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    } header: {
                        Text("System & Security").foregroundStyle(Color.theme.textSecondary)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.theme.cardBackground)

                    // MARK: - Destructive Actions
                    Section {
                        Button(role: .destructive) {
                            performSignOut()
                        } label: {
                            HStack {
                                Spacer()
                                if isSigningOut {
                                    ProgressView().tint(Color.theme.danger)
                                } else {
                                    Text("Sign Out").foregroundStyle(Color.theme.danger)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(Color.theme.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .dismissKeyboardOnTap()
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfileData()
        }
        .sheet(isPresented: $showEditEmployment) {
            EditEmploymentSheet(employment: currentEmployment) { updatedEmp in
                currentEmployment = updatedEmp
                currentBorrower?.employmentType = updatedEmp.employmentType.rawValue
                currentBorrower?.declaredMonthlyIncome = updatedEmp.monthlyIncome
            }
        }
        .sheet(isPresented: $showKYCVerification) {
            if let profile = currentBorrower {
                KYCVerificationView(profile: profile, docs: currentDocs) {
                    Task { await loadProfileData() }
                }
            }
        }
    }

    private func loadProfileData() async {
        do {
            async let fetchedProfile = SupabaseManager.shared.fetchCurrentBorrower()
            async let fetchedDocs = SupabaseManager.shared.fetchDocuments()
            async let fetchedEmployment = SupabaseManager.shared.fetchEmployment()

            currentBorrower = try await fetchedProfile
            currentDocs = try await fetchedDocs
            currentEmployment = try await fetchedEmployment
        } catch {
            print("Error fetching profile: \(error)")
        }
        isLoading = false
    }

    private func syncKYCStatus() async {
        let status = (kycStatus.label == "KYC Verified") ? "Verified" : "Pending"
        do {
            try await SupabaseManager.shared.updateUserStatus(to: status)
        } catch {
            print("❌ Failed to update user status: \(error)")
        }
    }

    private func performSignOut() {
        isSigningOut = true
        Task {
            do {
                try await SupabaseManager.shared.signOut()
                authManager.signOut()
            } catch {
                print("Sign out error: \(error.localizedDescription)")
            }
            isSigningOut = false
        }
    }

    private func updateLocalDoc(type: String, url: String) {
        if type == "PAN" { currentDocs?.panDocUrl = url }
        else if type == "Address" { currentDocs?.aadhaarDocUrl = url }
        else if type == "Income" { currentDocs?.incomeProofUrl = url }
        else if type == "Collateral" { currentDocs?.collateralDocUrl = url }
        else if type == "Business Proof" { currentDocs?.businessProofUrl = url }
    }

    private func handleDelete(docType: String) {
        Task {
            do {
                try await SupabaseManager.shared.deleteDocument(docType: docType)
                await MainActor.run {
                    withAnimation {
                        updateLocalDoc(type: docType, url: "")
                    }
                }
            } catch {
                print("Delete failed: \(error)")
            }
        }
    }
}

// MARK: - Compact Profile Rows
struct CompactProfileDocRow: View {
    let title: String
    let docType: String
    let existingURL: String?
    let isVerified: Bool        
    let onUploaded: (String) -> Void

    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var isUploading = false

    private var requiresVerification: Bool {
        docType == "PAN" || docType == "Address"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(Color.theme.textPrimary)

                    if existingURL != nil && !existingURL!.isEmpty {
                        if requiresVerification {

                            if isVerified {
                                Label("Verified", systemImage: "checkmark.seal.fill")
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundStyle(Color.theme.success)
                            } else {
                                Label("Uploaded — Verification Pending", systemImage: "clock.fill")
                                    .font(.caption2).fontWeight(.bold)
                                    .foregroundStyle(Color.theme.warning)
                            }
                        } else {
                            Label("Uploaded", systemImage: "checkmark.circle.fill")
                                .font(.caption2).fontWeight(.bold)
                                .foregroundStyle(Color.theme.success)
                        }
                    }
                }
                Spacer()

                if isUploading {
                    ProgressView().tint(Color.theme.primaryAccent)
                } else if let validUrlString = existingURL, !validUrlString.isEmpty, let url = URL(string: validUrlString) {
                    HStack(spacing: 12) {
                        Link(destination: url) {
                            Text("View")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(Color.theme.success)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.theme.successBackground)
                                .clipShape(Capsule())
                        }
                    }
                } else {
                    Button {
                        showSourcePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Upload")
                        }
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(Color.theme.primaryText)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.theme.primaryAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .alert("Upload \(title)", isPresented: $showSourcePicker) {
            Button("Camera Scan") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showCamera = true } }
            Button("Files") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showFileImporter = true } }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            DocumentScannerView { pdfData, isPDF in
                Task { await handleUpload(data: pdfData, isPDF: isPDF) }
            }.ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .jpeg, .png]) { result in
            if let url = try? result.get() {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    Task { await handleUpload(data: data, isPDF: url.pathExtension.lowercased() == "pdf") }
                }
            }
        }
    }

    private func handleUpload(data: Data, isPDF: Bool) async {
        isUploading = true
        do {
            let url = try await SupabaseManager.shared.uploadDocumentAndUpdateTable(docType: docType, data: data, isPDF: isPDF)
            await MainActor.run {
                withAnimation {
                    onUploaded(url)
                }
            }
        } catch { print("Upload failed: \(error)") }
        isUploading = false
    }
}

// MARK: - Helper Components
struct ProfileDetailRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title).foregroundStyle(Color.theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Color.theme.textPrimary).fontWeight(.medium)
        }
        .padding(16)
    }
}
struct EditEmploymentSheet: View {
    @Environment(\.dismiss) var dismiss
    let employment: Employment?
    let onSave: (Employment) -> Void

    @State private var employmentType: EmploymentType
    @State private var companyName: String
    @State private var jobRole: String
    @State private var industryType: String
    @State private var yearsExperience: Int
    @State private var monthlyIncome: Double
    @State private var isSaving = false

    init(employment: Employment?, onSave: @escaping (Employment) -> Void) {
        self.employment = employment
        self.onSave = onSave
        _employmentType = State(initialValue: employment?.employmentType ?? .salaried)
        _companyName = State(initialValue: employment?.companyName ?? "")
        _jobRole = State(initialValue: employment?.jobRole ?? "")
        _industryType = State(initialValue: employment?.industryType ?? "")
        _yearsExperience = State(initialValue: employment?.yearsExperience ?? 0)
        _monthlyIncome = State(initialValue: employment?.monthlyIncome ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(employment == nil ? "Add Details" : "Edit Details") {
                    Picker("Employment", selection: $employmentType) {
                        Text("Salaried").tag(EmploymentType.salaried)
                        Text("Self-Employed").tag(EmploymentType.selfEmployed)
                    }
                    TextField("Company Name", text: $companyName)
                    TextField("Job Role", text: $jobRole)
                    TextField("Industry", text: $industryType)
                }

                Section("Financials") {
                    Stepper("Experience: \(yearsExperience) Years", value: $yearsExperience, in: 0...40)
                    HStack {
                        Text("Monthly Income")
                        Spacer()
                        TextField("Amount", value: $monthlyIncome, format: .currency(code: "INR").precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(employment == nil ? "Add Employment" : "Edit Employment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(employment == nil ? "Add Details" : "Confirm Edit") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                    .fontWeight(.bold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true

        let updated = Employment(
            id: employment?.id,
            borrowerId: employment?.borrowerId ?? UUID(), 
            employmentType: employmentType,
            companyName: companyName,
            industryType: industryType,
            jobRole: jobRole,
            yearsExperience: yearsExperience,
            monthlyIncome: monthlyIncome,
            incomeStabilityScore: employment?.incomeStabilityScore
        )

        Task {
            do {
                try await SupabaseManager.shared.saveEmployment(updated)
                onSave(updated)
                dismiss()
            } catch {
                print("Error saving employment: \(error)")
            }
            isSaving = false
        }
    }
}

// MARK: - Siri Integration Components
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case hindi = "hi"
    case kannada = "kn"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .hindi: return "हिन्दी (Hindi)"
        case .kannada: return "ಕನ್ನಡ (Kannada)"
        }
    }
}

struct SiriCommand: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let phrase: String
    let icon: String
    let color: Color
}

struct SiriCommandCard: View {
    let command: SiriCommand

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(command.color.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: command.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(command.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(Color.theme.textPrimary)
                Text(command.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.theme.textSecondary)
            }

            Spacer()

            Text("“\(command.phrase)”")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.theme.primaryAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.theme.primaryAccent.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.theme.primaryAccent.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(12)
        .background(Color.theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
