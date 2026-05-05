import SwiftUI

// MARK: - Hex Color Initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: 
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: 
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: 
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Global Theme Definition
struct AppTheme {

    let appBackground = Color(light: Color(hex: "#F2F2F7"), dark: Color(hex: "#121212"))
    let cardBackground = Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1E1E1E"))

    let textPrimary = Color(light: Color(hex: "#000000"), dark: Color(hex: "#FFFFFF"))
    let textSecondary = Color(light: Color(hex: "#8E8E93"), dark: Color(hex: "#A0A0A0"))

    let primaryAccent = Color(hex: "#83CA54") 
    let primaryText = Color(hex: "#FFFFFF") 

    let success = Color(hex: "#83CA54")
    let successBackground = Color(light: Color(hex: "#EAF5E1"), dark: Color(hex: "#1B2E1B"))

    let danger = Color(hex: "#FF4D4F")
    let dangerBackground = Color(light: Color(hex: "#FEECEE"), dark: Color(hex: "#2E1B1B"))

    let warning = Color(hex: "#FFA500")
    let warningBackground = Color(light: Color(hex: "#FFF4E5"), dark: Color(hex: "#2E261B"))

    let info = Color(hex: "#007AFF")
    let infoBackground = Color(light: Color(hex: "#E5F0FF"), dark: Color(hex: "#1B212E"))
}

extension Color {
    static let theme = AppTheme()

    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

enum BorrowerTheme {
    static let background = Color(
        light: Color(red: 0.95, green: 0.95, blue: 0.98),
        dark: Color(red: 0.05, green: 0.05, blue: 0.07)
    )
    static let card = Color(
        light: Color.white.opacity(0.97),
        dark: Color(red: 0.11, green: 0.11, blue: 0.15).opacity(0.97)
    )
    static let textPrimary = Color(
        light: Color(red: 0.12, green: 0.12, blue: 0.15),
        dark: Color(red: 0.92, green: 0.92, blue: 0.96)
    )
    static let textSecondary = Color(
        light: Color(red: 0.54, green: 0.56, blue: 0.60),
        dark: Color(red: 0.60, green: 0.62, blue: 0.68)
    )
    static let softLine = Color(
        light: Color(red: 0.90, green: 0.91, blue: 0.94),
        dark: Color(red: 0.20, green: 0.20, blue: 0.24)
    )

    static let accentGreen = Color(
        light: Color(red: 0.49, green: 0.80, blue: 0.24),
        dark: Color(red: 0.55, green: 0.85, blue: 0.30)
    )
    static let accentBlue = Color(
        light: Color(red: 0.27, green: 0.55, blue: 0.98),
        dark: Color(red: 0.35, green: 0.60, blue: 1.0)
    )

    static let filterBackground = Color(
        light: Color(red: 0.95, green: 0.95, blue: 0.98),
        dark: Color(red: 0.15, green: 0.15, blue: 0.18)
    )
}
