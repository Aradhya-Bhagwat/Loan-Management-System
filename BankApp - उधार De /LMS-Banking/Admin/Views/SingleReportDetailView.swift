import SwiftUI

struct SingleReportDetailView: View {
    let reportType: AdminReportType
    @Bindable var controller: AdminDashboardViewModel
    @State private var showGeneratedReport = false
    @State private var lastReport: GeneratedReport?
    @State private var showDateRangePicker = false
    @State private var showAllHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Report Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: reportTypeIcon)
                            .font(.title)
                            .foregroundColor(reportType.tint)
                        Text(reportType.title)
                            .font(.title.bold())
                    }
                    Text(reportType.previewTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                // Report Options
                VStack(spacing: 0) {
                    ModernDropdownRow(title: "Reporting Window", selection: $controller.selectedRange, options: ReportRange.allCases) { $0.title }

                    if controller.selectedRange == .custom {
                        Divider().padding(.leading, 16).opacity(0.5)

                        Button {
                            showDateRangePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.appGreen)
                                    .font(.system(size: 15, weight: .semibold))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Date Range")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("\(controller.customStartDate.formatted(date: .abbreviated, time: .omitted)) → \(controller.customEndDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().padding(.vertical, 8).opacity(0.5)

                    ModernDropdownRow(title: "Export Format", selection: $controller.selectedFormat, options: ReportFormat.allCases) { $0.title }

                    Divider().padding(.vertical, 8).opacity(0.5)

                    ModernToggleRow(
                        title: "Include audit trail",
                        subtitle: "Attach compliance logs",
                        isOn: $controller.includeAuditTrail
                    )

                    Divider().padding(.vertical, 8).opacity(0.5)

                    ModernToggleRow(
                        title: "Include branch breakdown",
                        subtitle: "Show granular performance",
                        isOn: $controller.includeBranchBreakdown
                    )
                }
                .padding(20)
                .background(Color.appCard)
                .cornerRadius(24)
                .padding(.horizontal)

                // Error display
                if let error = controller.reportGenerationError {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appRed)

                        if let fix = controller.reportGenerationFix {
                            Text(fix)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appRed.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }

                // Action Button
                Button {
                    controller.reportGenerationError = nil
                    controller.reportGenerationFix = nil
                    controller.selectedReportType = reportType
                    controller.generateProfessionalReport()
                } label: {
                    HStack {
                        if controller.isGeneratingReport {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(controller.isGeneratingReport ? "Generating..." : "Generate \(reportType.title) Report")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(reportType.tint)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: reportType.tint.opacity(0.3), radius: 8, y: 4)
                }
                .disabled(controller.isGeneratingReport)
                .padding(.horizontal)

                // History for this type
                VStack(alignment: .leading, spacing: 16) {
                    Text("GENERATION HISTORY")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    let history = controller.dbGeneratedReports.filter { $0.type == reportType }

                    if history.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.3))
                            Text("No history for this report type")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color.appCard.opacity(0.5))
                        .cornerRadius(20)
                        .padding(.horizontal)
                    } else {
                        let visibleHistory = Array(history.prefix(10))
                        VStack(spacing: 12) {
                            ForEach(visibleHistory) { report in
                                ModernReportRow(report: report) {
                                    controller.deleteReport(report)
                                }
                            }
                        }
                        .padding(.horizontal)

                        if history.count > 10 {
                            Button {
                                showAllHistory = true
                            } label: {
                                HStack {
                                    Text("View All \(history.count) Reports")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(reportType.tint)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(reportType.tint)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.appCard)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(reportType.tint.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDateRangePicker) {
            DateRangePickerSheet(
                startDate: $controller.customStartDate,
                endDate: $controller.customEndDate
            )
        }
        .onChange(of: controller.lastGeneratedReport) { _, newValue in
            if let report = newValue, report.type == reportType {
                lastReport = report
                showGeneratedReport = true
            }
        }
        .navigationDestination(isPresented: $showGeneratedReport) {
            if let report = lastReport, let urlString = report.fileUrl, let url = URL(string: urlString) {
                ReportWebView(url: url, title: report.name)
            }
        }
        .navigationDestination(isPresented: $showAllHistory) {
            FullReportHistoryView(
                reportType: reportType,
                history: controller.dbGeneratedReports.filter { $0.type == reportType },
                controller: controller
            )
        }
    }

    private var reportTypeIcon: String {
        switch reportType {
        case .portfolioHealth: return "briefcase.fill"
        case .repaymentTrend: return "chart.line.uptrend.xyaxis"
        case .npaAnalysis: return "exclamationmark.triangle.fill"
        case .auditCompliance: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Native Date Range Picker Sheet

private struct DateRangePickerSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Environment(\.dismiss) private var dismiss

    @State private var tempStart: Date
    @State private var tempEnd: Date

    init(startDate: Binding<Date>, endDate: Binding<Date>) {
        _startDate = startDate
        _endDate = endDate
        _tempStart = State(initialValue: startDate.wrappedValue)
        _tempEnd = State(initialValue: endDate.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "From",
                        selection: $tempStart,
                        in: ...tempEnd,
                        displayedComponents: .date
                    )
                    .tint(.appGreen)

                    DatePicker(
                        "To",
                        selection: $tempEnd,
                        in: tempStart...Date(),
                        displayedComponents: .date
                    )
                    .tint(.appGreen)
                } footer: {
                    Text("Report will include data from \(tempStart.formatted(date: .long, time: .omitted)) to \(tempEnd.formatted(date: .long, time: .omitted)).")
                        .font(.footnote)
                }
            }
            .navigationTitle("Custom Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        startDate = tempStart
                        endDate = tempEnd
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(.appGreen)
                }
            }
        }
    }
}

// MARK: - Full Report History View

private struct FullReportHistoryView: View {
    let reportType: AdminReportType
    let history: [GeneratedReport]
    @Bindable var controller: AdminDashboardViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(history) { report in
                    ModernReportRow(report: report) {
                        controller.deleteReport(report)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("\(reportType.title) — All Reports")
        .navigationBarTitleDisplayMode(.inline)
    }
}
