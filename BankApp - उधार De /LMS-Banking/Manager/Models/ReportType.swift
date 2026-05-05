import Foundation

struct InsightReportType: Identifiable, Codable {
    var id = UUID()
    let title: String
    let description: String
    let iconName: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case iconName = "icon_name"
    }
}
