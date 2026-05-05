import Foundation

struct KPI: Identifiable, Codable {
    var id = UUID()
    let title: String
    let value: String
    let change: String?
    let iconName: String
    let accent: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case value
        case change
        case iconName = "icon_name"
        case accent
    }
}
