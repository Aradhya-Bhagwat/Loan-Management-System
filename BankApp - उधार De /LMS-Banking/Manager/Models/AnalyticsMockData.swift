import Foundation
import SwiftUI

enum TimeframeRange: String, CaseIterable, Identifiable {
    case oneMonth = "1 month"
    case threeMonths = "3 month"
    case sixMonths = "6 month"
    case oneYear = "1 year"

    var id: String { self.rawValue }

    var dataPointCount: Int {
        switch self {
        case .oneMonth: return 4 // weeks
        case .threeMonths: return 3 // months
        case .sixMonths: return 6 // months
        case .oneYear: return 12 // months
        }
    }

    func label(for index: Int) -> String {
        switch self {
        case .oneMonth: return "Week \(index + 1)"
        case .threeMonths: return "M\(index + 1)"
        case .sixMonths: return "M\(index + 1)"
        case .oneYear: return "M\(index + 1)"
        }
    }
}

struct KPIData: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let value: String
    let change: String?
}

struct ChartDataEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let label: String
    let category: String?
    let value: Double
}

struct MetricRowData: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let value: String
}
