import SwiftUI

struct ReportCard: View {
    let report: InsightReportType

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: report.iconName)
                .font(.system(size: 22))
                .foregroundStyle(Color.appGreen)
                .frame(width: 50, height: 50)
                .background(Color.appGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(report.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(report.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .cardStyle(padding: 18)
    }
}