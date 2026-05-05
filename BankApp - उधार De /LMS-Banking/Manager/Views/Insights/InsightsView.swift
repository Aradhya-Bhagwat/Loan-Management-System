import SwiftUI

struct InsightsView: View {
    @State private var controller = InsightsViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        if sizeClass == .compact {
            return [GridItem(.flexible(), spacing: 16)]
        } else {
            return [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Reports, analytics, and export options")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(controller.reportTypes) { report in
                        NavigationLink(destination: ReportDetailView(title: report.title)) {
                            ReportCard(report: report)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(sizeClass == .compact ? 16 : 28)
        }
        .background(Color.appBackground)
        .navigationTitle("Insights")
        .refreshable {
            controller.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
}