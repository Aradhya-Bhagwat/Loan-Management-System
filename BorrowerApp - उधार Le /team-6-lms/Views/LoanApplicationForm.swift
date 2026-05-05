import SwiftUI
import UniformTypeIdentifiers
import VisionKit
import PDFKit

struct LoanApplicationFormView: View {
    @Environment(\.dismiss) var dismiss
    var prefillApplication: LoanApplication? = nil

    @State private var loanAmount: Double = 0
    @State private var tenure: Int = 12
    @State private var selectedType = "Personal"
    @State private var fieldErrorMessage: String? = nil
    @FocusState private var focusedField: FormField?

    enum FormField: Hashable {
        case loanAmount, monthlyIncome, companyName, jobRole, industryType
    }

    @State private var uploadedDocs: [String: String] = [:]

    @State private var products: [LoanProduct] = []
    @State private var selectedProduct: LoanProduct?

    @State private var employmentType: EmploymentType = .salaried
    @State private var companyName: String = ""
    @State private var industryType: String = ""
    @State private var jobRole: String = ""
    @State private var yearsExperience: Int = 2
    @State private var monthlyIncome: Double = 0

    let tenureOptions = [6, 12, 24, 36, 48, 60]

    private var isFormValid: Bool {
        guard let product = selectedProduct else { return false }

        let coreValid = loanAmount >= calculatedMinLimit && loanAmount <= calculatedMaxLimit

        let requiredEmpFields = product.requiredEmploymentFields ?? ["company_name", "job_role", "monthly_income"]
        let professionalValid = requiredEmpFields.allSatisfy { field in
            switch field {
            case "company_name": return !companyName.isEmpty
            case "job_role": return !jobRole.isEmpty
            case "industry_type": return !industryType.isEmpty
            case "monthly_income": return monthlyIncome > 0
            default: return true
            }
        }

        let requiredDocs = product.requiredDocuments
        let allDocsUploaded = requiredDocs.allSatisfy { uploadedDocs[mapDocTitleToType($0.name)] != nil }

        return coreValid && professionalValid && allDocsUploaded
    }

    private var eligibilityFailureReason: String? {
        guard !isFormValid else { return nil }
        guard let product = selectedProduct else {
            return "Please select a loan type to continue."
        }

        if monthlyIncome == 0 {
            return "Enter your monthly income so we can calculate your loan eligibility."
        }
        let incomeMax = monthlyIncome * 50
        if incomeMax < (product.minAmount ?? 10_000) {
            return "Your monthly salary of ₹\(Int(monthlyIncome).formatted()) is too low to qualify for this loan type. Maximum eligible amount based on your income is ₹\(Int(incomeMax).formatted())."
        }

        if loanAmount < calculatedMinLimit {
            return "Loan amount ₹\(Int(loanAmount).formatted()) is below the minimum of ₹\(Int(calculatedMinLimit).formatted()) for this product."
        }
        if loanAmount > calculatedMaxLimit {
            if monthlyIncome > 0 && (monthlyIncome * 50) < (product.maxAmount ?? .infinity) {
                return "Loan amount exceeds the maximum of ₹\(Int(calculatedMaxLimit).formatted()) allowed based on 50× your monthly salary."
            }
            return "Loan amount ₹\(Int(loanAmount).formatted()) exceeds the maximum limit of ₹\(Int(calculatedMaxLimit).formatted()) for this product."
        }

        let requiredEmpFields = product.requiredEmploymentFields ?? ["company_name", "job_role", "monthly_income"]
        for field in requiredEmpFields {
            switch field {
            case "company_name" where companyName.isEmpty:
                return "Please enter your company or business name."
            case "job_role" where jobRole.isEmpty:
                return "Please enter your job role."
            case "industry_type" where industryType.isEmpty:
                return "Please enter your industry type."
            default: break
            }
        }

        let missingDocs = product.requiredDocuments.filter { uploadedDocs[mapDocTitleToType($0.name)] == nil }
        if !missingDocs.isEmpty {
            let names = missingDocs.map { $0.name }.joined(separator: ", ")
            return "Please upload the required document\(missingDocs.count > 1 ? "s" : ""): \(names)."
        }

        return "Please complete all required fields."
    }

    private var estimatedEMI: Double {
        let p = loanAmount
        let annualRate = selectedProduct?.baseRate ?? 12.0
        let r = annualRate / 12.0 / 100.0 
        let n = Double(tenure)
        guard p > 0, n > 0 else { return 0 }
        let emi = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
        return emi
    }

    private var calculatedMaxLimit: Double {
        let productMax = selectedProduct?.managerMaxAmount ?? selectedProduct?.maxAmount ?? 1_000_000

        let incomeMax = monthlyIncome > 0 ? (monthlyIncome * 50) : productMax
        return min(productMax, incomeMax)
    }

    private var calculatedMinLimit: Double {
        let productMin = selectedProduct?.managerMinAmount ?? selectedProduct?.minAmount ?? 10_000
        return min(productMin, calculatedMaxLimit)
    }

    private var isAmountInvalid: Bool {
        loanAmount > calculatedMaxLimit || loanAmount < calculatedMinLimit
    }

    @ViewBuilder
    private var limitErrorText: some View {
        if let errorMsg = fieldErrorMessage {
            Text(errorMsg)
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(Color.theme.danger)
        } else if loanAmount < calculatedMinLimit {
            Text("Amount is below the minimum limit of ₹\(Int(calculatedMinLimit).formatted())")
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(Color.theme.danger)
        } else if loanAmount > calculatedMaxLimit {
            Text("Amount exceeds the maximum limit of ₹\(Int(calculatedMaxLimit).formatted())")
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(Color.theme.danger)
        }
    }

    // MARK: - Dynamic Fields Logic
    private var dynamicFields: [String] {
        selectedProduct?.requiredEmploymentFields ?? ["company_name", "job_role", "monthly_income", "years_experience"]
    }

    @ViewBuilder
    private var fieldsList: some View {
        ForEach(dynamicFields, id: \.self) { field in
            Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

            if field == "company_name" {
                EditableRow(title: "Company/Business", placeholder: "e.g. Google", text: $companyName, focusedField: $focusedField, field: .companyName)
            } else if field == "job_role" {
                EditableRow(title: "Job Role", placeholder: "e.g. Manager", text: $jobRole, focusedField: $focusedField, field: .jobRole)
            } else if field == "industry_type" {
                EditableRow(title: "Industry Type", placeholder: "e.g. Fintech", text: $industryType, focusedField: $focusedField, field: .industryType)
            } else if field == "monthly_income" {
                HStack {
                    Text("Monthly Income")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.theme.textPrimary)
                    Spacer()
                    TextField("Amount", value: $monthlyIncome, format: .currency(code: "INR").precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(Color.theme.primaryAccent)
                        .focused($focusedField, equals: .monthlyIncome)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            } else if field == "years_experience" {
                HStack {
                    Text("Experience")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.theme.textPrimary)
                    Spacer()
                    Stepper("\(yearsExperience) Years", value: $yearsExperience, in: 0...40)
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(Color.theme.primaryAccent)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: - Core Loan Details
                        SectionHeader(title: "CORE LOAN DETAILS")
                        CardView {
                            VStack(spacing: 0) {

                                HStack {
                                    Text("Loan Type")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.theme.textPrimary)
                                    Spacer()
                                    if products.isEmpty {
                                        ProgressView().tint(Color.theme.primaryAccent)
                                    } else {
                                        Picker("Loan Type", selection: $selectedProduct) {
                                            Text("Select Product").tag(nil as LoanProduct?)
                                            ForEach(products) { product in
                                                Text(product.name).tag(product as LoanProduct?)
                                            }
                                        }
                                        .tint(Color.theme.primaryAccent)
                                        .pickerStyle(.menu)
                                        .dismissKeyboardOnPickerTap()
                                        .onChange(of: selectedProduct) { _, newValue in
                                            focusedField = nil
                                            if let product = newValue {
                                                loanAmount = product.minAmount ?? 10000
                                                tenure = product.minTenure
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)

                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Loan Amount")
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(Color.theme.textPrimary)
                                        Spacer()
                                        TextField("Amount", value: $loanAmount, format: .currency(code: "INR").precision(.fractionLength(0)))
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.trailing)
                                            .font(.system(.subheadline, design: .rounded).bold())
                                            .foregroundStyle(Color.theme.primaryAccent)
                                            .focused($focusedField, equals: .loanAmount)
                                    }

                                    HStack {
                                        Text("Limit: ₹\(Int(calculatedMinLimit).formatted()) to ₹\(Int(calculatedMaxLimit).formatted())")
                                            .font(.caption2)
                                            .foregroundStyle(isAmountInvalid ? Color.red : Color.theme.textSecondary)
                                        Spacer()
                                    }

                                    limitErrorText

                                    if monthlyIncome > 0 && (monthlyIncome * 50) < (selectedProduct?.maxAmount ?? .infinity) {
                                        HStack {
                                            Text("(Max limit capped at 50x monthly salary)")
                                                .font(.caption2)
                                                .foregroundStyle(Color.theme.warning)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)

                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                HStack {
                                    Text("Tenure")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.theme.textPrimary)
                                    Spacer()
                                    Picker("Tenure", selection: $tenure) {
                                        if let product = selectedProduct {
                                            ForEach(product.minTenure...product.maxTenure, id: \.self) { months in
                                                Text("\(months) Months").tag(months)
                                            }
                                        } else {
                                            Text("6 Months").tag(6)
                                        }
                                    }
                                    .tint(Color.theme.primaryAccent)
                                    .pickerStyle(.menu)
                                    .dismissKeyboardOnPickerTap()
                                    .onChange(of: tenure) { _, _ in
                                        focusedField = nil
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)

                                Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)

                                HStack {
                                    Text("Estimated EMI")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.theme.textSecondary)
                                    Spacer()
                                    Text("₹\(Int(estimatedEMI).formatted()) / month")
                                        .font(.system(.subheadline, design: .rounded).bold())
                                        .foregroundStyle(Color.theme.primaryAccent)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }

                        // MARK: - Professional Details
                        SectionHeader(title: "PROFESSIONAL DETAILS")
                        CardView {
                            VStack(spacing: 0) {

                                HStack {
                                    Text("Employment")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.theme.textPrimary)
                                    Spacer()
                                    Picker("Employment Type", selection: $employmentType) {
                                        Text("Salaried").tag(EmploymentType.salaried)
                                        Text("Self-Employed").tag(EmploymentType.selfEmployed)
                                    }
                                    .tint(Color.theme.primaryAccent)
                                    .pickerStyle(.menu)
                                    .dismissKeyboardOnPickerTap()
                                    .onChange(of: employmentType) { _, _ in
                                        focusedField = nil
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)

                                fieldsList
                            }
                        }

                        SectionHeader(title: "KYC & DOCUMENT UPLOAD")
                        CardView {
                            VStack(spacing: 0) {
                                if let product = selectedProduct {
                                    ForEach(product.requiredDocuments, id: \.self) { doc in
                                        KYCDocumentRow(
                                            title: doc.name,
                                            docType: mapDocTitleToType(doc.name),
                                            existingURL: uploadedDocs[mapDocTitleToType(doc.name)],
                                            onUploaded: { url in uploadedDocs[mapDocTitleToType(doc.name)] = url }
                                        )
                                        if doc != product.requiredDocuments.last {
                                            Divider().background(Color.gray.opacity(0.1)).padding(.horizontal, 16)
                                        }
                                    }
                                } else {
                                    Text("Select a loan type to view required documents.")
                                        .font(.caption)
                                        .foregroundStyle(Color.theme.textSecondary)
                                        .padding()
                                }
                            }
                        }

                        Text("Ensure all documents are clear and legible before submission.")
                            .font(.caption)
                            .foregroundStyle(Color.theme.textSecondary)
                            .padding(.horizontal, 20).padding(.top, 16)

                        // MARK: - Submit Footer embedded in ScrollView
                        SubmitFooterView(
                            isFormValid: isFormValid,
                            eligibilityFailureReason: eligibilityFailureReason,
                            loanAmount: loanAmount,
                            tenure: tenure,
                            purpose: selectedProduct?.name ?? "",
                            productId: selectedProduct?.id,
                            uploadedDocs: uploadedDocs,
                            employment: Employment(
                                id: nil,
                                borrowerId: UUID(), 
                                employmentType: employmentType,
                                companyName: companyName,
                                industryType: industryType.isEmpty ? "Technology" : industryType,
                                jobRole: jobRole,
                                yearsExperience: yearsExperience,
                                monthlyIncome: monthlyIncome,
                                incomeStabilityScore: nil
                            ),
                            onDismiss: { dismiss() },
                            onFieldError: { errorMsg in
                                self.fieldErrorMessage = errorMsg
                            }
                        )
                        .padding(.top, 32).padding(.bottom, 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTap()
                .onChange(of: loanAmount) { _, _ in fieldErrorMessage = nil }
                .onChange(of: selectedProduct) { _, _ in fieldErrorMessage = nil }
            }
            .navigationTitle("New Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.theme.primaryAccent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .task {
                await loadInitialData()
            }
        }
    }

    private func loadInitialData() async {
        do {
            products = try await SupabaseManager.shared.fetchLoanProducts()
            if let prefill = prefillApplication {
                if let matched = products.first(where: { $0.id == prefill.productId }) {
                    selectedProduct = matched
                } else if let matchedPurpose = products.first(where: { $0.name == prefill.purpose }) {
                    selectedProduct = matchedPurpose
                } else {
                    selectedProduct = products.first
                }

                loanAmount = prefill.loanAmount
                tenure = prefill.tenureMonths
                if let empName = prefill.employerName { companyName = empName }
                if let inc = prefill.monthlyIncome { monthlyIncome = inc }
            } else if let first = products.first {
                selectedProduct = first
                tenure = first.minTenure
                loanAmount = first.minAmount ?? 10_000
            }

            if let emp = try? await SupabaseManager.shared.fetchEmployment() {
                if companyName.isEmpty { companyName = emp.companyName ?? "" }
                if industryType.isEmpty { industryType = emp.industryType ?? "" }
                if jobRole.isEmpty { jobRole = emp.jobRole ?? "" }
                if yearsExperience == 2 { yearsExperience = emp.yearsExperience ?? 2 }
                if monthlyIncome == 0 { monthlyIncome = emp.monthlyIncome }
                employmentType = emp.employmentType
            }

            await loadExistingDocuments()
        } catch {
            print("LoanForm: error loading data: \(error)")
        }
    }

    private func mapDocTitleToType(_ title: String) -> String {
        let t = title.lowercased()
        if t.contains("pan") || t.contains("identity") || t.contains("id proof") { return "PAN" }
        if t.contains("aadhaar") || t.contains("address") { return "Address" }
        if t.contains("income") || t.contains("salary") { return "Income" }
        if t.contains("collateral") { return "Collateral" }
        if t.contains("business") { return "Business Proof" }
        return title
    }
    private func loadExistingDocuments() async {
        do {
            if let docs = try await SupabaseManager.shared.fetchDocuments() {
                if let pan = docs.panDocUrl { uploadedDocs["PAN"] = pan }
                if let aadhaar = docs.aadhaarDocUrl { uploadedDocs["Address"] = aadhaar }
                if let income = docs.incomeProofUrl { uploadedDocs["Income"] = income }
            }
        } catch {
            print("LoanForm: could not fetch existing documents: \(error)")
        }
    }
}

// MARK: - Submit Footer
private struct SubmitFooterView: View {
    let isFormValid: Bool
    let eligibilityFailureReason: String?
    let loanAmount: Double
    let tenure: Int
    let purpose: String
    let productId: UUID?
    let uploadedDocs: [String: String]
    let employment: Employment
    let onDismiss: () -> Void
    let onFieldError: (String) -> Void

    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String? = nil

    @ViewBuilder
    private var eligibilityReasonView: some View {
        if let reason = eligibilityFailureReason {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.warning)
                    .padding(.top, 1)
                Text(reason)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.theme.warningBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if !isFormValid {
                eligibilityReasonView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            Button(action: submitApplication) {
                ZStack {
                    Text("Submit Application")
                        .fontWeight(.bold)
                        .foregroundStyle(isFormValid ? Color.theme.primaryText : Color.theme.textSecondary.opacity(0.8))
                        .opacity(isSubmitting ? 0 : 1)
                    if isSubmitting {
                        ProgressView().tint(Color.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.theme.primaryAccent : Color.gray.opacity(0.15))
                .clipShape(Capsule())
            }
            .disabled(!isFormValid || isSubmitting)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .alert("Application Submitted! 🎉", isPresented: $showSuccessAlert) {
            Button("Got it") { onDismiss() }
        } message: {
            Text("We've received your application. You can track the status in the Loans tab.")
        }
        .alert("Submission Failed", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private func submitApplication() {
        isSubmitting = true
        Task {
            do {
                try await SupabaseManager.shared.saveEmployment(employment)

                let appId = try await SupabaseManager.shared.submitApplicationWithAssignment(
                    loanAmount: loanAmount,
                    tenure: tenure,
                    purpose: purpose,
                    employer: employment.companyName ?? "Private Sector",
                    income: employment.monthlyIncome,
                    productId: productId
                )

                if !uploadedDocs.isEmpty {
                    try await SupabaseManager.shared.saveApplicationDocuments(applicationId: appId, documents: uploadedDocs)
                }

                showSuccessAlert = true
            } catch {
                let errorDesc = error.localizedDescription
                if errorDesc.lowercased().contains("minimum limit") || errorDesc.lowercased().contains("loan amount") {
                    onFieldError(errorDesc)
                } else {
                    errorMessage = errorDesc
                }
            }
            isSubmitting = false
        }
    }
}

// MARK: - KYC Document Row
struct KYCDocumentRow: View {
    let title: String
    let docType: String
    let existingURL: String?
    let onUploaded: (String) -> Void

    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var isUploading = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(Color.theme.textPrimary)
                Group {
                    if existingURL != nil {
                        Label("Uploaded", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color.theme.success)
                    } else {
                        Text("Not uploaded")
                            .foregroundStyle(Color.theme.textSecondary)
                    }
                }
                .font(.caption)
            }
            Spacer()

            if isUploading {
                ProgressView().tint(Color.theme.primaryAccent)
            } else if let validUrlString = existingURL, let url = URL(string: validUrlString) {
                Link(destination: url) {
                    Label("View", systemImage: "doc.text.magnifyingglass")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(Color.theme.success)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.theme.successBackground)
                        .clipShape(Capsule())
                }
            } else {
                Button {
                    showSourcePicker = true
                } label: {
                    Label("Upload", systemImage: "arrow.up.circle")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(Color.theme.primaryText)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.theme.primaryAccent)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .alert("Upload \(title)", isPresented: $showSourcePicker) {
            Button("Scan using Camera") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showCamera = true } }
            Button("Upload from Files") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showFileImporter = true } }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            DocumentScannerView { pdfData, isPDF in
                Task { await handleUpload(data: pdfData, isPDF: isPDF) }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .jpeg, .png]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    let isPDF = url.pathExtension.lowercased() == "pdf"
                    Task { await handleUpload(data: data, isPDF: isPDF) }
                }
            case .failure(let error):
                print("File import failed: \(error)")
            }
        }
    }

    private func handleUpload(data: Data, isPDF: Bool) async {
        isUploading = true
        do {
            let uploadedUrlString = try await SupabaseManager.shared.uploadDocumentAndUpdateTable(
                docType: docType,
                data: data,
                isPDF: isPDF
            )
            onUploaded(uploadedUrlString)
        } catch {
            print("Upload error for \(docType): \(error)")
        }
        isUploading = false
    }
}

struct EditableRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var focusedField: FocusState<LoanApplicationFormView.FormField?>.Binding?
    var field: LoanApplicationFormView.FormField?

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color.theme.textPrimary)
            Spacer()
            if let focusedField, let field {
                TextField(placeholder, text: $text)
                    .multilineTextAlignment(.trailing)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.theme.primaryAccent)
                    .focused(focusedField, equals: field)
            } else {
                TextField(placeholder, text: $text)
                    .multilineTextAlignment(.trailing)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.theme.primaryAccent)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Document Scanner
struct DocumentScannerView: UIViewControllerRepresentable {
    let onCapture: (Data, Bool) -> Void

    init(onCapture: @escaping (Data, Bool) -> Void) {
        self.onCapture = onCapture
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCapture: (Data, Bool) -> Void
        init(onCapture: @escaping (Data, Bool) -> Void) { self.onCapture = onCapture }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pdfDocument = PDFDocument()
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                if let pdfPage = PDFPage(image: image) { pdfDocument.insert(pdfPage, at: pageIndex) }
            }
            if let pdfData = pdfDocument.dataRepresentation() {
                DispatchQueue.main.async {
                    self.onCapture(pdfData, true)
                }
            }
            controller.dismiss(animated: true)
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { controller.dismiss(animated: true) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { controller.dismiss(animated: true) }
    }
}
