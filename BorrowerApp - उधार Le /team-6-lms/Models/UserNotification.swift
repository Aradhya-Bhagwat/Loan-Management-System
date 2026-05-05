import Foundation

struct UserNotification: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let message: String
    let type: String
    let isRead: Bool
    let createdAt: String
    let metadata: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case message
        case type
        case isRead = "is_read"
        case createdAt = "created_at"
        case metadata
    }

    var applicationId: UUID? {
        guard let metadata = metadata,
              let data = metadata.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let idString = dict["application_id"] else {
            return nil
        }
        return UUID(uuidString: idString)
    }

    var timeAgo: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: createdAt)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: createdAt)
        }
        guard let created = date else { return "" }

        let interval = Date().timeIntervalSince(created)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: created)
    }

    var typeIcon: String {
        switch type {
        case "payment": return "creditcard.fill"
        case "loan": return "briefcase.fill"
        case "alert": return "exclamationmark.triangle.fill"
        case "chat": return "bubble.left.and.bubble.right.fill"
        default: return "info.circle.fill"
        }
    }

    var typeColor: String {
        switch type {
        case "payment": return "green"
        case "loan": return "blue"
        case "alert": return "orange"
        case "chat": return "purple"
        default: return "accent"
        }
    }
}
