import SwiftUI
import UIKit

struct SettingsView: View {
    @State private var controller = SettingsViewModel()
    @Environment(AuthViewModel.self) private var authController

    @State private var editableName: String = ""
    @State private var editablePhone: String = ""
    @State private var isSaving: Bool = false
    @State private var showNameEditor = false
    @State private var showPhoneEditor = false

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showLogoutAlert = false

    private var managerName: String { authController.currentUser?.name ?? "Manager" }
    private var managerRole: String { authController.currentUser?.role.title ?? "Manager" }

    private var branchDisplayValue: String {
        authController.currentUser?.branch ?? controller.branch ?? "—"
    }

    private var phoneDisplayValue: String {
        editablePhone.isEmpty ? "Not set" : editablePhone
    }

    var body: some View {
        Form {
            Section {
                ProfileAvatarHeader(
                    name: managerName,
                    subtitle: "Branch Manager"
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

                SettingsReadOnlyRow(title: "Branch", value: branchDisplayValue)
                SettingsReadOnlyRow(title: "Role", value: managerRole)
            }

            Section("Permissions") {
                Toggle(isOn: $controller.approveAbove100k) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Approve loans above ₹100K")
                        Text("Requires senior manager approval")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.appGreen)
                .onChange(of: controller.approveAbove100k) { _, newValue in
                    Task { await controller.updatePermission("approveAbove100k", value: newValue) }
                }

                Toggle(isOn: $controller.accessRiskReports) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Access risk reports")
                        Text("View detailed risk analytics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.appGreen)
                .onChange(of: controller.accessRiskReports) { _, newValue in
                    Task { await controller.updatePermission("accessRiskReports", value: newValue) }
                }

                Toggle(isOn: $controller.manageLoanOfficers) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage loan officers")
                        Text("Add, remove, or reassign officers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.appGreen)
                .onChange(of: controller.manageLoanOfficers) { _, newValue in
                    Task { await controller.updatePermission("manageLoanOfficers", value: newValue) }
                }
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
            ManagerProfileTextEditSheet(
                title: "Name",
                placeholder: "Full Name",
                value: editableName,
                keyboardType: .default,
                isSaving: isSaving
            ) { newName in
                saveProfile(name: newName, phone: editablePhone)
            }
        }
        .sheet(isPresented: $showPhoneEditor) {
            ManagerProfileTextEditSheet(
                title: "Phone",
                placeholder: "10-digit phone number",
                value: editablePhone,
                keyboardType: .numberPad,
                isSaving: isSaving
            ) { newPhone in
                saveProfile(name: editableName, phone: newPhone)
            }
        }
        .onAppear {
            syncEditableFields()
        }
        .onChange(of: authController.currentUser?.id) { _, _ in
            syncEditableFields()
        }
    }

    private func syncEditableFields() {
        guard let user = authController.currentUser else { return }
        editableName = user.name
        editablePhone = user.phone ?? ""
        controller.configure(userId: user.id, fullName: user.name, userEmail: user.email, userPhone: user.phone)
        controller.branch = user.branch
        authController.refreshMFAStatus()
    }

    private func saveProfile(name: String, phone: String) {
        guard let user = authController.currentUser else { return }

        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnlyPhone = phone.filter(\.isNumber)

        guard !cleanedName.isEmpty else {
            showErrorAlert(message: "Name cannot be empty.")
            return
        }

        guard digitsOnlyPhone.count == 10 else {
            showErrorAlert(message: "Phone must be 10 digits.")
            return
        }

        isSaving = true

        Task {
            do {
                try await DatabaseService.shared.updateCurrentUserProfile(
                    id: user.id,
                    fullName: cleanedName,
                    email: user.email,
                    phone: digitsOnlyPhone,
                    branch: user.branch ?? ""
                )

                guard let refreshedSession = try await DatabaseService.shared.getCurrentSession() else {
                    throw NSError(
                        domain: "SettingsView",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to refresh current session."]
                    )
                }

                await MainActor.run {
                    authController.currentUser = refreshedSession
                    editableName = refreshedSession.name
                    editablePhone = refreshedSession.phone ?? ""
                    isSaving = false
                    showSuccessAlert(message: "Your profile has been updated successfully.")
                }

                await DatabaseService.shared.logAudit(
                    title: "Profile Updated: \(cleanedName)",
                    actor: "Manager",
                    category: "Profile",
                    status: "Completed",
                    icon: "person.fill",
                    color: "blue",
                    branch: user.branch
                )

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
}

private struct ManagerProfileTextEditSheet: View {
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
        }
    }
}

private struct ButtonRow: View {
    let label: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let iconName: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            content
        }
        .cardStyle()
    }
}

struct SettingsField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(label, text: $text)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.appSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ToggleRow: View {
    let label: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(Color.appGreen)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
