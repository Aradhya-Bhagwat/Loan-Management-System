import Foundation
import SwiftUI

// MARK: - Notification Type

enum LoanOfficerNotificationType: String, CaseIterable, Identifiable {
    case chatMessage    = "chat_message"
    case newApplication = "new_application"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .chatMessage:    return "Messages"
        case .newApplication: return "Loans"
        }
    }
}

// MARK: - Notification Filter

enum NotificationFilter: String, CaseIterable, Identifiable {
    case all
    case messages
    case loans

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:      return "All"
        case .messages: return "Messages"
        case .loans:    return "Loans"
        }
    }

    var icon: String {
        switch self {
        case .all:      return "bell.fill"
        case .messages: return "bubble.left.and.bubble.right.fill"
        case .loans:    return "paperplane.fill"
        }
    }

    func matches(_ type: LoanOfficerNotificationType) -> Bool {
        switch self {
        case .all:      return true
        case .messages: return type == .chatMessage
        case .loans:    return type == .newApplication
        }
    }

    func unreadCount(in notifications: [LoanOfficerNotification]) -> Int {
        notifications.filter { !$0.isRead && matches($0.type) }.count
    }
}

// MARK: - Notification Model

struct LoanOfficerNotification: Identifiable {
    let id: UUID
    let applicationId: UUID?
    let title: String
    let subtitle: String
    let timestamp: Date
    var isRead: Bool
    let type: LoanOfficerNotificationType

    /// Create from a Supabase DB record
    init(from db: DBUserNotification) {
        self.id = db.id
        self.applicationId = db.applicationId
        self.title = db.title
        self.subtitle = db.message
        self.timestamp = db.createdDate ?? Date()
        self.isRead = db.isRead
        self.type = LoanOfficerNotificationType(rawValue: db.type) ?? .chatMessage
    }

    var iconName: String {
        switch type {
        case .chatMessage:    return "bubble.left.and.bubble.right.fill"
        case .newApplication: return "paperplane.fill"
        }
    }

    var iconColor: Color {
        switch type {
        case .chatMessage:    return .appGreen
        case .newApplication: return OfficerTheme.accentBlue
        }
    }

    /// Format the timestamp as a relative string
    var relativeTimestamp: String {
        let now = Date()
        let interval = now.timeIntervalSince(timestamp)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: timestamp)
        }
    }
}
