import SwiftUI

struct FilterChip: View {
    let label: String
    let isActive: Bool
    var color: Color = .appGreen
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isActive ? color : Color.appSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}