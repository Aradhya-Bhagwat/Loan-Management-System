import SwiftUI

// MARK: - Dark Mode Support
extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Officer Theme

enum OfficerTheme {
    static let background = Color(
        light: Color(red: 0.95, green: 0.95, blue: 0.98),
        dark: .appBackground
    )
    static let card = Color(
        light: Color.white.opacity(0.97),
        dark: .appCard
    )
    static let textPrimary = Color(
        light: Color(red: 0.12, green: 0.12, blue: 0.15),
        dark: Color(red: 0.92, green: 0.92, blue: 0.96)
    )
    static let textSecondary = Color(
        light: Color(red: 0.54, green: 0.56, blue: 0.60),
        dark: Color(red: 0.60, green: 0.62, blue: 0.68)
    )
    static let filterBackground = Color(
        light: Color(red: 0.95, green: 0.95, blue: 0.98),
        dark: Color(red: 0.15, green: 0.15, blue: 0.18)
    )
    static let softLine = Color(
        light: Color(red: 0.90, green: 0.91, blue: 0.94),
        dark: Color(red: 0.20, green: 0.20, blue: 0.24)
    )
    
    // Accents
    static let accentBlue = Color(light: Color(red: 0.27, green: 0.55, blue: 0.98), dark: Color(red: 0.35, green: 0.60, blue: 1.0))
    static let accentGreen = Color.appGreen
    static let reject = Color(light: Color(red: 0.95, green: 0.39, blue: 0.38), dark: Color(red: 0.98, green: 0.45, blue: 0.45))
    
    // Icons
    static let iconBlue = Color(light: Color(red: 0.34, green: 0.62, blue: 0.98), dark: Color(red: 0.45, green: 0.70, blue: 1.0))
    static let iconGreen = Color.appGreen
    static let iconAmber = Color(light: Color(red: 0.95, green: 0.70, blue: 0.32), dark: Color(red: 1.0, green: 0.75, blue: 0.40))
    static let iconRed = Color(light: Color(red: 0.94, green: 0.43, blue: 0.46), dark: Color(red: 0.98, green: 0.50, blue: 0.52))
}

// MARK: - Doc Status

enum DocStatus {
    case uploaded
    case pending
}

// MARK: - White Card

struct WhiteCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .appCard()
    }
}

// MARK: - Tag

struct Tag: View {
    let text: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
            .clipShape(Capsule())
    }
}
