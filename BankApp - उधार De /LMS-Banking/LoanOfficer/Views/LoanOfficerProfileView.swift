import SwiftUI
import UIKit

struct LoanOfficerProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authController

    @State private var editableName: String = ""
    @State private var editablePhone: String = ""
    @State private var editableEmail: String = ""

    @State private var isSaving: Bool = false
    @State private var showNameEditor = false
    @State private var showPhoneEditor = false
    @State private var showEmailEditor = false

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showLogoutAlert = false

    private var officerName: String { authController.currentUser?.name ?? "Loan Officer" }
    private var officerRole: String { authController.currentUser?.role.title ?? "Loan Officer" }

    private var employeeId: String {
        guard let id = authController.currentUser?.id.uuidString.prefix(8) else { return "LO-000001" }
        return "LO-\(id.uppercased())"
    }

    private var departmentText: String {
        authController.currentUser?.department ?? "Loan Processing"
    }

    private var branchText: String {
        authController.currentUser?.branch ?? "Main Branch"
    }

    private var phoneDisplayValue: String {
        editablePhone.isEmpty ? "Not set" : editablePhone
    }

    var body: some View {
        Form {
            Section {
                ProfileAvatarHeader(
                    name: authController.currentUser?.name ?? "Loan Officer",
                    subtitle: "Loan Officer"
                )
                .padding(.top, 10)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section("Profile Information") {
                SettingsEditableRow(title: "Name", value: editableName) {
                    showNameEditor = true
                }

                SettingsEditableRow(title: "Phone", value: phoneDisplayValue) {
                    showPhoneEditor = true
                }

                SettingsReadOnlyRow(title: "Email", value: authController.currentUser?.email ?? "")
            }

            Section("Security") {
                Toggle(
                    "Biometric Login",
                    isOn: Binding(
                        get: { authController.isBiometricsEnabled },
                        set: { newValue in
                            authController.isBiometricsEnabled = newValue
                            if newValue {
                                authController.verifyBiometricsNowAndStoreSession()
                            } else {
                                authController.clearBiometricSession()
                            }
                        }
                    )
                )
                .tint(.appGreen)
                
                SettingsReadOnlyRow(title: "Branch", value: branchText)
                SettingsReadOnlyRow(title: "Role", value: officerRole)
            }

            Section {
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    Text("Logout")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                authController.logout()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showNameEditor) {
            LOProfileTextEditSheet(
                title: "Name",
                placeholder: "Full Name",
                value: editableName,
                keyboardType: .default,
                isSaving: isSaving
            ) { newName in
                saveProfile(name: newName, email: editableEmail, phone: editablePhone)
            }
        }
        .sheet(isPresented: $showPhoneEditor) {
            LOProfileTextEditSheet(
                title: "Phone",
                placeholder: "10-digit phone number",
                value: editablePhone,
                keyboardType: .numberPad,
                isSaving: isSaving
            ) { newPhone in
                saveProfile(name: editableName, email: editableEmail, phone: newPhone)
            }
        }
        .sheet(isPresented: $showEmailEditor) {
            LOProfileTextEditSheet(
                title: "Email",
                placeholder: "name@example.com",
                value: editableEmail,
                keyboardType: .emailAddress,
                isSaving: isSaving
            ) { newEmail in
                saveProfile(name: editableName, email: newEmail, phone: editablePhone)
            }
        }
        .onAppear {
            syncEditableFields()
        }
        .onChange(of: authController.currentUser?.id) { _, _ in
            syncEditableFields()
        }
    }

    private func settingsEditableRow(title: String, value: String, onEdit: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Button("Edit") {
                onEdit()
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private func settingsReadOnlyRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func syncEditableFields() {
        guard let user = authController.currentUser else { return }

        editableName = user.name
        editableEmail = user.email
        editablePhone = user.phone ?? ""
    }

    private func saveProfile(name: String, email: String, phone: String) {
        guard let user = authController.currentUser else { return }

        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digitsOnlyPhone = phone.filter(\.isNumber)

        guard !cleanedName.isEmpty else {
            showErrorAlert(message: "Name cannot be empty.")
            return
        }

        guard digitsOnlyPhone.count == 10 else {
            showErrorAlert(message: "Phone must be 10 digits.")
            return
        }

        guard isValidEmail(cleanedEmail) else {
            showErrorAlert(message: "Please enter a valid email address.")
            return
        }

        isSaving = true

        Task {
            do {
                try await DatabaseService.shared.updateCurrentUserProfile(
                    id: user.id,
                    fullName: cleanedName,
                    email: cleanedEmail,
                    phone: digitsOnlyPhone,
                    branch: user.branch ?? "Main Branch"
                )

                guard let refreshedSession = try await DatabaseService.shared.getCurrentSession() else {
                    throw NSError(
                        domain: "LOProfileView",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to refresh current session."]
                    )
                }

                await MainActor.run {
                    authController.currentUser = refreshedSession
                    editableName = refreshedSession.name
                    editableEmail = refreshedSession.email
                    editablePhone = refreshedSession.phone ?? ""
                    isSaving = false
                    showSuccessAlert(message: "Your profile has been updated successfully.")
                }

            } catch {
                await MainActor.run {
                    isSaving = false
                    showErrorAlert(message: "Failed to update profile: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showSuccessAlert(message: String) {
        alertTitle = "Success"
        alertMessage = message
        showAlert = true
    }

    private func showErrorAlert(message: String) {
        alertTitle = "Error"
        alertMessage = message
        showAlert = true
    }

    private func isValidEmail(_ email: String) -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: email)
    }
}

private struct LOProfileTextEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let placeholder: String
    let value: String
    let keyboardType: UIKeyboardType
    let isSaving: Bool
    let onSave: (String) -> Void
    @State private var draft: String

    init(
        title: String,
        placeholder: String,
        value: String,
        keyboardType: UIKeyboardType,
        isSaving: Bool,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.value = value
        self.keyboardType = keyboardType
        self.isSaving = isSaving
        self.onSave = onSave
        _draft = State(initialValue: value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(placeholder, text: $draft)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(keyboardType == .default ? .words : .never)
                        .autocorrectionDisabled(keyboardType != .default)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onSave(draft)
                        dismiss()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .tint(.appGreen)
        }
    }
}
