import Foundation

@Observable
class SettingsViewModel {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""

    var approveAbove100k: Bool = true
    var accessRiskReports: Bool = true
    var manageLoanOfficers: Bool = false

    var emailNotifications: Bool = true
    var weeklySummary: Bool = true
    var desktopNotifications: Bool = false

    var isLoading = false
    var isSaving = false
    var phone: String = ""

    private var currentUserId: UUID?
    private var settingsId: UUID?
    var branch: String? = nil

    func configure(userId: UUID, fullName: String, userEmail: String, userPhone: String? = nil) {
        currentUserId = userId
        firstName = fullName.components(separatedBy: " ").first ?? ""
        lastName = fullName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        email = userEmail
        phone = userPhone ?? ""
        loadSettings()
    }

    private func loadSettings() {
        guard let userId = currentUserId else { return }
        isLoading = true

        Task {
            do {
                if let settings = try await DatabaseService.shared.fetchManagerSettings(userId: userId) {
                    await MainActor.run {
                        self.settingsId = settings.id
                        self.approveAbove100k = settings.approveAbove100k
                        self.accessRiskReports = settings.accessRiskReports
                        self.manageLoanOfficers = settings.manageLoanOfficers
                        self.emailNotifications = settings.emailNotifications
                        self.weeklySummary = settings.weeklySummary
                        self.desktopNotifications = settings.desktopNotifications
                        self.isLoading = false
                    }
                } else {
                    let defaults = ManagerSettings(userId: userId)
                    let created = try await DatabaseService.shared.upsertManagerSettings(defaults)
                    await MainActor.run {
                        self.settingsId = created.id
                        self.isLoading = false
                    }
                }
            } catch {
                print("Error loading settings: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    func saveProfile() async {
        guard let userId = currentUserId else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await DatabaseService.shared.updateBasicProfile(
                id: userId,
                fullName: "\(firstName) \(lastName)",
                email: email,
                phone: phone
            )
            await DatabaseService.shared.logAudit(
                title: "Profile Updated: \(firstName) \(lastName)",
                actor: "Manager",
                category: "Profile",
                status: "Completed",
                icon: "person.fill",
                color: "blue",
                branch: branch
            )
        } catch {
            print("Error saving profile: \(error)")
        }
    }

    func updatePermission(_ key: String, value: Bool) async {
        guard let userId = currentUserId else { return }
        var settings = buildCurrentSettings(userId: userId)
        switch key {
        case "approveAbove100k": settings.approveAbove100k = value
        case "accessRiskReports": settings.accessRiskReports = value
        case "manageLoanOfficers": settings.manageLoanOfficers = value
        default: break
        }

        do {
            let updated = try await DatabaseService.shared.upsertManagerSettings(settings)
            await MainActor.run { self.settingsId = updated.id }
            await DatabaseService.shared.logAudit(
                title: "Permission Updated: \(key)",
                actor: "Manager",
                category: "Permissions",
                status: "Completed",
                icon: "lock.shield.fill",
                color: "blue",
                branch: branch
            )
        } catch {
            print("Error updating permission: \(error)")
        }
    }

    func updatePreference(_ key: String, value: Bool) async {
        guard let userId = currentUserId else { return }
        var settings = buildCurrentSettings(userId: userId)
        switch key {
        case "emailNotifications": settings.emailNotifications = value
        case "weeklySummary": settings.weeklySummary = value
        case "desktopNotifications": settings.desktopNotifications = value
        default: break
        }

        do {
            let updated = try await DatabaseService.shared.upsertManagerSettings(settings)
            await MainActor.run { self.settingsId = updated.id }
            await DatabaseService.shared.logAudit(
                title: "Preference Updated: \(key)",
                actor: "Manager",
                category: "Preferences",
                status: "Completed",
                icon: "bell.fill",
                color: "gray",
                branch: branch
            )
        } catch {
            print("Error updating preference: \(error)")
        }
    }

    private func buildCurrentSettings(userId: UUID) -> ManagerSettings {
        var settings = ManagerSettings(userId: userId)
        if let sid = settingsId { settings.id = sid }
        settings.approveAbove100k = approveAbove100k
        settings.accessRiskReports = accessRiskReports
        settings.manageLoanOfficers = manageLoanOfficers
        settings.emailNotifications = emailNotifications
        settings.weeklySummary = weeklySummary
        settings.desktopNotifications = desktopNotifications
        return settings
    }
}