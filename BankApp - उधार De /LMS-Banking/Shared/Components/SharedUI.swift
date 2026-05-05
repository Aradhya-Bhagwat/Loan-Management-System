import SwiftUI

// MARK: - View Extensions
extension View {
    /// Standard card style used across Admin, Manager and Loan Officer dashboards
    func appCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .padding(20)
            .background(Color.appCard)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 16, x: 0, y: 10)
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let title: String
    let value: String
    let change: String?
    let icon: String
    let iconTint: Color
    let showChevron: Bool
    
    init(title: String, value: String, change: String? = nil, icon: String, iconTint: Color, showChevron: Bool = true) {
        self.title = title
        self.value = value
        self.change = change
        self.icon = icon
        self.iconTint = iconTint
        self.showChevron = showChevron
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(iconTint)
                    .frame(width: 56, height: 56)
                    .background(iconTint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.top, 4)
                }
            }

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .background(Color.appCard)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 16, x: 0, y: 10)
    }
}

// MARK: - Dashboard Grid
struct DashboardGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @ViewBuilder let content: Content
    
    var body: some View {
        let columns = sizeClass == .regular
            ? [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)]
            : [GridItem(.flexible(), spacing: 16)]
        
        LazyVGrid(columns: columns, spacing: sizeClass == .regular ? 24 : 16) {
            content
        }
    }
}

// MARK: - Section Header
struct AppSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.primary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Badge Components
struct AppStatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Profile Components
struct ProfileAvatarHeader: View {
    let name: String
    let subtitle: String
    let color: Color = .appGreen
    
    var body: some View {
        HStack(spacing: 16) {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
                .frame(width: 70, height: 70)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

struct SettingsReadOnlyRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

struct SettingsEditableRow: View {
    let title: String
    let value: String
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Button("Edit") {
                onEdit()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.appGreen)
        }
    }
}
