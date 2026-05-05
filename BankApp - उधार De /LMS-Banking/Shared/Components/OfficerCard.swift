import SwiftUI

struct OfficerSummaryCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

struct OfficerCard: View {
    let officer: LoanOfficer
    var underperforming: Bool { officer.defaultRate > 5 }
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        Group {
            if sizeClass == .compact {
                iPhoneLayout
            } else {
                iPadLayout
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(underperforming ? Color.appRed.opacity(0.25) : Color.clear, lineWidth: 1)
        )
    }

    private var iPhoneLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
//            HStack(spacing: 14) {
//                profileImage
//                VStack(alignment: .leading, spacing: 3) {
//                    nameHeader
//                    Text(officer.role)
//                        .font(.system(size: 13))
//                        .foregroundStyle(.secondary)
//                }
//            }
            
            HStack(spacing: 14) {
                profileImage
                VStack(alignment: .leading, spacing: 3) {
                    nameHeader
                    Text(officer.role)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack {
                OfficerMetric(label: "Loans", value: "\(officer.loansHandled)")
                Spacer()
                OfficerMetric(label: "Active",  value: "\(officer.activeLoans)")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Default Rate").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("\(officer.defaultRate, specifier: "%.1f")%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(underperforming ? Color.appRed : Color.primary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Approval Rate").font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    approvalProgressBar
                    Text("\(Int(officer.approvalRate))%")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }

    private var iPadLayout: some View {
        HStack(spacing: 20) {
            HStack(spacing: 14) {
                profileImage
                VStack(alignment: .leading, spacing: 3) {
                    nameHeader
                    Text(officer.role)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, alignment: .leading)

            Spacer()

            HStack(spacing: 32) {
                OfficerMetric(label: "Loans Handled", value: "\(officer.loansHandled)")
                OfficerMetric(label: "Active Loans",  value: "\(officer.activeLoans)")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Approval Rate")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        approvalProgressBar
                            .frame(width: 80, height: 6)
                        Text("\(Int(officer.approvalRate))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Rate")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("\(officer.defaultRate, specifier: "%.1f")%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(underperforming ? Color.appRed : Color.primary)
                }
            }
        }
    }

    private var profileImage: some View {
        ZStack {
            Circle()
                .fill(Color.appGreen.opacity(0.15))
                .frame(width: 50, height: 50)
            Text(officer.initials)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.appGreen)
        }
    }

    private var nameHeader: some View {
        HStack(spacing: 6) {
            Text(officer.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            if underperforming {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appRed)
            }
        }
    }

    private var approvalProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.appSecondary).frame(height: 6)
                Capsule()
                    .fill(Color.appGreen)
                    .frame(width: geo.size.width * (officer.approvalRate / 100), height: 6)
            }
        }
        .frame(height: 6)
    }
}

struct OfficerMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}
