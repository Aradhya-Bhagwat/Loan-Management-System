import Foundation
import SwiftUI

struct AuditLog: Codable, Identifiable {
    let id: UUID
    let title: String
    let actor: String
    let category: String
    let status: String
    let icon: String
    let iconColor: String
    let createdAt: String? 

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case actor
        case category
        case status
        case icon
        case iconColor = "icon_color"
        case createdAt = "created_at"
    }
}
