import SwiftUI
import Charts

struct AnalyticsKPICard: View {
    let kpi: KPIData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kpi.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(kpi.value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }
}

struct AnalyticsKPIGrid: View {
    let kpis: [KPIData]
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    var columns: [GridItem] {
        if sizeClass == .compact {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        } else {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        }
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: sizeClass == .compact ? 12 : 16) {
            ForEach(kpis) { kpi in
                AnalyticsKPICard(kpi: kpi)
            }
        }
    }
}

struct ChartContainerCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            
            content()
                .frame(minHeight: 220)
        }
        .cardStyle(padding: 20)
    }
}

struct MetricListSection: View {
    let title: String
    let metrics: [MetricRowData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(metrics.indices, id: \.self) { index in
                    HStack {
                        Text(metrics[index].title)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(metrics[index].value)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    
                    if index < metrics.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
    }
}
