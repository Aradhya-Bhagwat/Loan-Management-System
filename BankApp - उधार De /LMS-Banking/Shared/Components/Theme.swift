import SwiftUI

// MARK: - App Colors
extension Color {
    static let appGreen        = Color(red: 0.25, green: 0.78, blue: 0.35)  // slightly toned lime green
    static let appGreenLight   = Color(red: 0.94, green: 0.98, blue: 0.94)   // soft lime wash background
    static let appOrange       = Color(red: 0.85, green: 0.55, blue: 0.20)   // muted amber warning
    static let appRed          = Color(red: 0.78, green: 0.25, blue: 0.26)   // muted rose destructive
    static let appBlue         = Color(red: 0.20, green: 0.50, blue: 0.95)   // bright blue
    static let appTeal         = Color(red: 0.18, green: 0.72, blue: 0.78)   // bright teal
    static let appIndigo       = Color(red: 0.40, green: 0.40, blue: 0.90)   // bright indigo
    static let appPurple       = Color(red: 0.65, green: 0.35, blue: 0.90)   // bright purple
    static let appBackground   = Color(UIColor.systemGroupedBackground)
    static let appCard         = Color(UIColor.secondarySystemGroupedBackground)
    static let appSecondary    = Color(UIColor.tertiarySystemGroupedBackground)
}

extension ShapeStyle where Self == Color {
    static var appGreen: Color { .appGreen }
    static var appGreenLight: Color { .appGreenLight }
    static var appOrange: Color { .appOrange }
    static var appRed: Color { .appRed }
    static var appBlue: Color { .appBlue }
    static var appTeal: Color { .appTeal }
    static var appIndigo: Color { .appIndigo }
    static var appPurple: Color { .appPurple }
    static var appBackground: Color { .appBackground }
    static var appCard: Color { .appCard }
    static var appSecondary: Color { .appSecondary }
}

extension Color {
    static func riskColor(_ risk: RiskLevel) -> Color {
        switch risk {
        case .low:    return .appGreen
        case .medium: return .appOrange
        case .high:   return .appRed
        }
    }

    static func statusColor(_ status: LoanStatus) -> Color {
        switch status {
        case .submitted:             return Color(red: 0.85, green: 0.70, blue: 0.10)
        case .underReview:           return .appOrange
        case .recommended:           return .appBlue
        case .approved:              return .appGreen
        case .rejected:              return .appRed
        case .returnedForCorrection: return .orange
        }
    }

    static func themeColor(for accent: String) -> Color {
        switch accent.lowercased() {
        case "green": return .appGreen
        case "orange": return .appOrange
        case "red": return .appRed
        case "blue": return .blue
        case "purple": return .purple
        default: return .secondary
        }
    }
}

// MARK: - Responsive Layout Helper
struct ResponsiveLayout {
    let size: CGSize
    let horizontalSizeClass: UserInterfaceSizeClass?

    var isPad: Bool { horizontalSizeClass == .regular }
    var isCompact: Bool { size.width < 600 }
    
    var horizontalPadding: CGFloat { isPad ? 32 : 20 }
    var spacing: CGFloat { isPad ? 24 : 16 }
    
    var columnCount: Int {
        if size.width > 1000 { return 3 }
        if size.width > 600 { return 2 }
        return 1
    }
    
    var cardCornerRadius: CGFloat { isPad ? 24 : 18 }
    
    func adaptiveWidth(_ ratio: CGFloat) -> CGFloat {
        let width = size.width - (horizontalPadding * 2)
        return width * ratio
    }
}

// MARK: - Card Style Modifier
struct CardStyle: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.appCard)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func cardStyle(padding: CGFloat = 20) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Badge Views
struct RiskBadge: View {
    let risk: RiskLevel

    var body: some View {
        Text(risk.rawValue)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.riskColor(risk))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.riskColor(risk).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct StatusBadge: View {
    let status: LoanStatus
    
    var displayText: String {
        switch status {
        case .submitted:             return "Submitted"
        case .underReview:           return "Under Review"
        case .recommended:           return "Recommended"
        case .approved:              return "Approved"
        case .rejected:              return "Rejected"
        case .returnedForCorrection: return "Returned"
        }
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.statusColor(status).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct OverdueStatusBadge: View {
    let status: OverdueStatus

    var color: Color {
        switch status {
        case .overdue:   return .appOrange
        case .defaulted: return .appRed
        }
    }

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Components
struct SectionHeader: View {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
