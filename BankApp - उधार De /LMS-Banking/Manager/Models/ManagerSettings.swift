import Foundation

struct ManagerSettings: Identifiable, Codable {
    var id: UUID
    let userId: UUID
    var approveAbove100k: Bool
    var accessRiskReports: Bool
    var manageLoanOfficers: Bool
    var emailNotifications: Bool
    var weeklySummary: Bool
    var desktopNotifications: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case approveAbove100k = "approve_above_100k"
        case accessRiskReports = "access_risk_reports"
        case manageLoanOfficers = "manage_loan_officers"
        case emailNotifications = "email_notifications"
        case weeklySummary = "weekly_summary"
        case desktopNotifications = "desktop_notifications"
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        approveAbove100k: Bool = true,
        accessRiskReports: Bool = true,
        manageLoanOfficers: Bool = false,
        emailNotifications: Bool = true,
        weeklySummary: Bool = true,
        desktopNotifications: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.approveAbove100k = approveAbove100k
        self.accessRiskReports = accessRiskReports
        self.manageLoanOfficers = manageLoanOfficers
        self.emailNotifications = emailNotifications
        self.weeklySummary = weeklySummary
        self.desktopNotifications = desktopNotifications
    }
}