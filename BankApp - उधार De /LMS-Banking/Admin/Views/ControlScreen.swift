import SwiftUI

struct ControlScreen: View {
    let metrics: DashboardLayoutMetrics
    @Bindable var controller: AdminDashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Loan Products Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("LOAN PRODUCTS", systemImage: "briefcase.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.secondary.opacity(0.8))
                            .kerning(1.2)
                        
                        Spacer()
                        
                        NavigationLink {
                            LoanProductDetailView(
                                controller: controller,
                                product: LoanProduct(
                                    id: UUID(),
                                    name: "",
                                    baseRate: 8.0,
                                    maxRate: 12.0,
                                    processingFee: 1.0,
                                    minTenureMonths: 12,
                                    maxTenureMonths: 60,
                                    minAmount: 10000,
                                    maxAmount: 1000000,
                                    eligibilityRules: "",
                                    requiredDocuments: []
                                ),
                                isNew: true
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("New Product")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.appGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appGreen.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }

                    VStack(spacing: 0) {
                        if controller.loanProducts.isEmpty {
                            emptyStateRow(title: "No products configured", icon: "tray")
                        } else {
                            ForEach(Array(controller.loanProducts.enumerated()), id: \.element.id) { index, product in
                                NavigationLink {
                                    LoanProductDetailView(controller: controller, product: product, isNew: false)
                                } label: {
                                    modernChevronRow(
                                        title: product.name,
                                        subtitle: "\(product.baseRate)% - \(product.maxRate)% · \(product.minTenureMonths)-\(product.maxTenureMonths) mo",
                                        icon: "doc.text.fill",
                                        iconColor: .appGreen
                                    )
                                }
                                .buttonStyle(.plain)

                                if index < controller.loanProducts.count - 1 {
                                    Divider().padding(.leading, 56).opacity(0.5)
                                }
                            }
                        }
                    }
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                }

                // Notifications Section
                VStack(alignment: .leading, spacing: 16) {
                    Label("COMMUNICATIONS", systemImage: "bell.badge.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary.opacity(0.8))
                        .kerning(1.2)

                    // Notification toggles card
                    VStack(spacing: 0) {
                        let srsSettings = [
                            ("Due Date Reminders", "calendar.badge.clock"),
                            ("Approval Updates", "checkmark.seal.fill"),
                            ("Disbursement Confirmations", "indianrupeesign.circle.fill"),
                            ("Overdue Reminders", "exclamationmark.bubble.fill"),
                            ("In-App Messaging", "message.fill")
                        ]

                        ForEach(0..<srsSettings.count, id: \.self) { index in
                            let item = srsSettings[index]
                            modernToggleRow(
                                title: item.0,
                                icon: item.1,
                                iconColor: .appGreen,
                                isOn: Binding(
                                    get: {
                                        controller.notificationSettings.first(where: { $0.title == item.0 })?.isEnabled ?? false
                                    },
                                    set: { newValue in
                                        if let existing = controller.notificationSettings.first(where: { $0.title == item.0 }) {
                                            var updated = existing
                                            updated.isEnabled = newValue
                                            controller.saveNotificationSetting(updated)
                                        } else {
                                            let newSetting = NotificationSetting(title: item.0, isEnabled: newValue)
                                            controller.saveNotificationSetting(newSetting)
                                        }
                                    }
                                )
                            )

                            if index < srsSettings.count - 1 {
                                Divider().padding(.leading, 56).opacity(0.5)
                            }
                        }
                    }
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)

                    // Message templates card
                    Label("MESSAGE TEMPLATES", systemImage: "text.quote")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary.opacity(0.8))
                        .kerning(1.2)

                    VStack(spacing: 0) {
                        if controller.notificationTemplates.isEmpty {
                            emptyStateRow(title: "No templates configured", icon: "tray")
                        } else {
                            ForEach(Array(controller.notificationTemplates.enumerated()), id: \.element.id) { index, template in
                                NavigationLink {
                                    NotificationTemplateEditorView(controller: controller, template: template)
                                } label: {
                                    modernChevronRow(
                                        title: template.title,
                                        subtitle: template.subject.isEmpty ? "No subject set" : template.subject,
                                        icon: "text.quote",
                                        iconColor: .appGreen
                                    )
                                }
                                .buttonStyle(.plain)

                                if index < controller.notificationTemplates.count - 1 {
                                    Divider().padding(.leading, 56).opacity(0.5)
                                }
                            }
                        }
                    }
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                }

                // Governance Section
                VStack(alignment: .leading, spacing: 16) {
                    Label("GOVERNANCE & SYSTEM", systemImage: "shield.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary.opacity(0.8))
                        .kerning(1.2)

                    VStack(spacing: 0) {
                        NavigationLink {
                            PrivacySettingsView(controller: controller)
                        } label: {
                            modernChevronRow(
                                title: "Data Retention & Compliance",
                                subtitle: "GDPR Lifecycle: \(controller.privacySettings.retentionPeriodYears) years",
                                icon: "lock.shield.fill",
                                iconColor: .appGreen
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 56).opacity(0.5)

                        NavigationLink {
                            SystemSettingsView(controller: controller)
                        } label: {
                            modernChevronRow(
                                title: "Bank Configuration",
                                subtitle: "Support, Currency, and HQ Info",
                                icon: "building.columns.fill",
                                iconColor: .appGreen
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Divider().padding(.leading, 56).opacity(0.5)
                        
                        NavigationLink {
                            LoanActivityListView(controller: controller)
                        } label: {
                            modernChevronRow(
                                title: "Master Audit Trail",
                                subtitle: "Filterable loan modification logs",
                                icon: "list.bullet.rectangle.portrait.fill",
                                iconColor: .appGreen
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, 24)
            .padding(.bottom, 60)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .refreshable {
            controller.fetchLoanProducts()
            controller.fetchCompetitiveRates()
            controller.fetchNotificationSettings()
            controller.fetchNotificationTemplates()
            controller.fetchSystemConfig()
        }
    }

    private func modernChevronRow(title: String, subtitle: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(16)
    }

    private func modernToggleRow(title: String, icon: String, iconColor: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.appGreen)
        }
        .padding(16)
    }

    private func emptyStateRow(title: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }
}

struct NotificationTemplatesView: View {
    @Bindable var controller: AdminDashboardViewModel

    var body: some View {
        List {
            ForEach(controller.notificationTemplates) { template in
                NavigationLink {
                    NotificationTemplateEditorView(controller: controller, template: template)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appGreen)
                            .frame(width: 36, height: 36)
                            .background(Color.appGreen.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(template.title)
                                .font(.body.weight(.semibold))
                            Text(template.subject.isEmpty ? "No subject set" : template.subject)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Message Templates")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct LoanProductDetailView: View {
    let controller: AdminDashboardViewModel
    @State private var product: LoanProduct
    @State private var newDocumentName = ""
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var isNew: Bool = false

    init(controller: AdminDashboardViewModel, product: LoanProduct, isNew: Bool = false) {
        self.controller = controller
        self._product = State(initialValue: product)
        self.isNew = isNew
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Product Name", text: $product.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                    Text(isNew ? "Create a new loan offering" : "Modify existing product parameters")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 14) {
                    Label("INTEREST RATE", systemImage: "percent")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary.opacity(0.8))
                        .kerning(1.2)

                    sliderSetting(
                        title: "Base Rate",
                        value: $product.baseRate,
                        range: 1...max(1, product.maxRate),
                        step: 0.1,
                        suffix: "% p.a."
                    )

                    Divider().padding(.vertical, 8).opacity(0.5)

                    sliderSetting(
                        title: "Maximum Rate",
                        value: $product.maxRate,
                        range: 1...30,
                        step: 0.1,
                        suffix: "% p.a."
                    )
                }
                .padding(20)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 14) {
                    Label("TENURE LIMITS", systemImage: "calendar")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary.opacity(0.8))
                        .kerning(1.2)

                    sliderSetting(
                        title: "Minimum Tenure",
                        value: Binding(get: { Double(product.minTenureMonths) }, set: { product.minTenureMonths = Int($0.rounded()) }),
                        range: 1...max(1, Double(product.maxTenureMonths)),
                        step: 1,
                        suffix: "months"
                    )

                    Divider().padding(.vertical, 8).opacity(0.5)

                    sliderSetting(
                        title: "Maximum Tenure",
                        value: Binding(get: { Double(product.maxTenureMonths) }, set: { product.maxTenureMonths = Int($0.rounded()) }),
                        range: 1...360,
                        step: 1,
                        suffix: "months"
                    )
                }
                .padding(20)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 14) {
                    Label("COMPLIANCE DOCUMENTS", systemImage: "doc.badge.gearshape.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary.opacity(0.8))
                        .kerning(1.2)

                    if product.requiredDocuments.isEmpty {
                        Text("No documents added yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }

                    ForEach($product.requiredDocuments) { $document in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.appGreen.opacity(0.6))

                            Text(document.name)
                                .font(.body.weight(.medium))

                            Spacer()

                            Toggle("", isOn: $document.isRequired)
                                .labelsHidden()
                                .tint(.appGreen)

                            Button(role: .destructive) {
                                product.requiredDocuments.removeAll { $0.id == document.id }
                            } label: {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.appRed)
                                    .padding(8)
                                    .background(Color.appRed.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    HStack(spacing: 10) {
                        TextField("Add document (e.g. PAN Card)", text: $newDocumentName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            addComplianceDocument()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.appGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(newDocumentName.isEmpty)
                    }
                }
                .padding(20)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)

                VStack(spacing: 12) {
                    Button {
                        controller.saveLoanProduct(product)
                        dismiss()
                    } label: {
                        Text(isNew ? "Create Product" : "Save Product Configuration")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.appGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.appGreen.opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(product.name.isEmpty)
                    
                    if !isNew {
                        Button {
                            showDeleteAlert = true
                        } label: {
                            Text("Delete Product")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.appRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.appRed.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert("Confirm Deletion", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                controller.deleteLoanProduct(id: product.id)
            }
        } message: {
            Text("Are you sure you want to remove '\(product.name)'? This action cannot be undone and will affect future loan applications.")
        }
        .alert("Error", isPresented: Binding(get: { controller.productDeleteError != nil }, set: { if !$0 { controller.productDeleteError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = controller.productDeleteError {
                Text(error)
            }
        }
        .onAppear {
            controller.isProductDeleted = false
            controller.productDeleteError = nil
        }
        .onChange(of: controller.isProductDeleted) { _, newValue in
            if newValue { dismiss() }
        }
    }

    private func sliderSetting(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: step < 1 ? "%.1f" : "%.0f", value.wrappedValue)) \(suffix)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.appGreen)
            }
            Slider(value: value, in: range, step: step)
                .tint(.appGreen)
        }
    }

    private func addComplianceDocument() {
        let trimmed = newDocumentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            product.requiredDocuments.append(.init(name: trimmed, isRequired: true))
            newDocumentName = ""
        }
    }
}

struct NotificationTemplateEditorView: View {
    @Bindable var controller: AdminDashboardViewModel
    @State private var template: NotificationTemplate
    @Environment(\.dismiss) private var dismiss

    init(controller: AdminDashboardViewModel, template: NotificationTemplate) {
        self.controller = controller
        if template.body.isEmpty {
            let preset = NotificationTemplatePreset.preset(for: template.title)
            var newTemplate = template
            newTemplate.subject = preset.subject
            newTemplate.body = preset.body
            _template = State(initialValue: newTemplate)
        } else {
            _template = State(initialValue: template)
        }
    }

    private var isTemplateChanged: Bool {
        guard let current = controller.notificationTemplates.first(where: { $0.id == template.id }) else { return true }
        return template.subject != current.subject || template.body != current.body
    }

    var body: some View {
        Form {
            Section("Subject Line") {
                TextField("Subject", text: $template.subject)
            }

            Section("Message Body") {
                TextEditor(text: $template.body)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 260)
            }

            Section {
                Button {
                    controller.saveNotificationTemplate(template)
                    dismiss()
                } label: {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .bold()
                }
                .disabled(!isTemplateChanged)
                .tint(.appGreen)
            }
        }
        .navigationTitle(template.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

struct ConsentTemplateEditorView: View {
    @Bindable var controller: AdminDashboardViewModel
    @State private var template: ConsentTemplate
    @Environment(\.dismiss) private var dismiss

    init(controller: AdminDashboardViewModel, template: ConsentTemplate) {
        self.controller = controller
        _template = State(initialValue: template)
    }
    
    private var isTemplateChanged: Bool {
        let current = controller.consentTemplates.first(where: { $0.id == template.id }) ?? controller.consentTemplates.first ?? controller.consentTemplates.first!
        return template.title != current.title ||
               template.version != current.version ||
               template.content != current.content ||
               template.isActive != current.isActive
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Template Title", text: $template.title)
                        .font(.system(size: 32, weight: .bold))
                    HStack {
                        Text("Version:")
                        TextField("1.0", text: $template.version)
                            .frame(width: 60)
                            .padding(.horizontal, 8)
                            .background(Color.appSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("CONSENT CONTENT")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)

                    TextEditor(text: $template.content)
                        .font(.body)
                        .frame(minHeight: 300)
                        .padding(12)
                        .background(Color.appSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .appCard()

                HStack {
                    Text("Active Policy")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $template.isActive)
                        .tint(.appGreen)
                }
                .appCard()

                Button {
                    controller.saveConsentTemplate(template)
                    dismiss()
                } label: {
                    Text("Save Template Version")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(isTemplateChanged ? Color.appGreen : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!isTemplateChanged)
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

struct NotificationTemplatePreset {
    let subject: String
    let body: String
    static func preset(for title: String) -> NotificationTemplatePreset {
        switch title {
        case "Approval Email": return .init(subject: "Loan Approved", body: "Dear {{name}}, your loan is approved.")
        case "EMI Reminder SMS": return .init(subject: "EMI Due", body: "Hi {{name}}, your EMI is due on {{date}}.")
        default: return .init(subject: "Notification", body: "Hello {{name}}, this is a system message.")
        }
    }
}

struct PrivacySettingsView: View {
    @Bindable var controller: AdminDashboardViewModel
    @State private var settings: PrivacySettings
    @Environment(\.dismiss) private var dismiss
    
    init(controller: AdminDashboardViewModel) {
        self.controller = controller
        _settings = State(initialValue: controller.privacySettings)
    }
    
    private var isSettingsChanged: Bool {
        let current = controller.privacySettings
        return settings.retentionPeriodYears != current.retentionPeriodYears ||
               settings.isAutoPurgeEnabled != current.isAutoPurgeEnabled
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Data Privacy")
                    .font(.system(size: 34, weight: .bold))
                
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Retention Period")
                            .font(.body.weight(.medium))
                        Spacer()
                        Stepper("\(settings.retentionPeriodYears) Years", value: $settings.retentionPeriodYears, in: 1...30)
                    }
                    
                    Divider().opacity(0.5)
                    
                    Toggle("Auto-purge expired data", isOn: $settings.isAutoPurgeEnabled)
                        .tint(.appGreen)
                        .font(.body.weight(.medium))
                }
                .padding(20)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                Button {
                    controller.savePrivacySettings(settings)
                    dismiss()
                } label: {
                    Text("Update Privacy Policy")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(isSettingsChanged ? Color.appGreen : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!isSettingsChanged)
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

struct SystemSettingsView: View {
    @Bindable var controller: AdminDashboardViewModel
    @State private var config: SystemConfig
    @Environment(\.dismiss) private var dismiss
    
    init(controller: AdminDashboardViewModel) {
        self.controller = controller
        _config = State(initialValue: controller.systemConfig)
    }
    
    private var isConfigChanged: Bool {
        let current = controller.systemConfig
        return config.institutionName != current.institutionName ||
               config.supportEmail != current.supportEmail ||
               config.supportPhone != current.supportPhone ||
               config.headquartersCity != current.headquartersCity ||
               config.defaultCurrency != current.defaultCurrency
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Settings")
                        .font(.system(size: 34, weight: .bold))
                    Text("Global institutional configuration and support")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INSTITUTION NAME")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.secondary)
                            .kerning(1.0)
                        TextField("Name", text: $config.institutionName)
                            .padding(14)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SUPPORT CONTACT")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.secondary)
                            .kerning(1.0)
                        
                        TextField("Email", text: $config.supportEmail)
                            .padding(14)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        
                        TextField("Phone", text: $config.supportPhone)
                            .padding(14)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .keyboardType(.phonePad)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("LOCALIZATION")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.secondary)
                            .kerning(1.0)
                        
                        TextField("Headquarters City", text: $config.headquartersCity)
                            .padding(14)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        TextField("Default Currency (e.g. INR)", text: $config.defaultCurrency)
                            .padding(14)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                Button {
                    controller.saveSystemConfig(config)
                    dismiss()
                } label: {
                    Text("Save Settings")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(isConfigChanged ? Color.appGreen : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!isConfigChanged)
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LoanActivityListView: View {
    @Bindable var controller: AdminDashboardViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Loan Logs")
                    .font(.system(size: 34, weight: .bold))
                
                VStack(spacing: 12) {
                    ForEach(controller.loanActivityEntries) { entry in
                        AuditTableRow(entry: entry)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}
