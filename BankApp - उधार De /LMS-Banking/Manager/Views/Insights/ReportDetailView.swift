import SwiftUI

struct ReportDetailView: View {
    let title: String
    @Environment(AuthViewModel.self) var authController
    @State private var selectedTimeframe: TimeframeRange = .oneMonth
    @State private var controller = AnalyticsViewModel()
    @State private var isExporting = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    private var reportIcon: String {
        if title.lowercased().contains("portfolio") { return "briefcase.fill" }
        if title.lowercased().contains("repayment") { return "chart.line.uptrend.xyaxis" }
        if title.lowercased().contains("npa") { return "exclamationmark.triangle.fill" }
        if title.lowercased().contains("audit") { return "shield.checkered" }
        return "doc.text.fill"
    }

    private var reportColor: Color {
        return .appGreen
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with icon + title (left-aligned)
                    HStack(spacing: 14) {
                        Image(systemName: reportIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(reportColor)
                            .frame(width: 52, height: 52)
                            .background(reportColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(TimeframeRange.allCases) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    VStack(spacing: 32) {
                        if title.lowercased().contains("portfolio") {
                            PortfolioHealthView(timeframe: selectedTimeframe, controller: controller)
                        } else if title.lowercased().contains("repayment") {
                            RepaymentTrendsView(timeframe: selectedTimeframe, controller: controller)
                        } else if title.lowercased().contains("npa") {
                            NpaAnalysisView(timeframe: selectedTimeframe, controller: controller)
                        } else if title.lowercased().contains("audit") {
                            AuditComplianceView(timeframe: selectedTimeframe, controller: controller)
                        } else {
                            Text("No data available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .padding(.top, 24)
            }
            .background(Color.appBackground)
            
            if isExporting {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                
                ProgressView("Generating PDF...")
                    .padding(24)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        generatePDF()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                }
            }
        }
        .task {
            controller.branch = authController.currentUser?.branch
            if title.lowercased().contains("audit") {
                controller.actorFilter = "Manager"
            }
            await loadData()
        }
        .onChange(of: selectedTimeframe) { _, _ in
            Task { await loadData() }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func loadData() async {
        if title.lowercased().contains("portfolio") {
            await controller.loadPortfolioHealth(timeframe: selectedTimeframe)
        } else if title.lowercased().contains("repayment") {
            await controller.loadRepaymentTrends(timeframe: selectedTimeframe)
        } else if title.lowercased().contains("npa") {
            await controller.loadNPA(timeframe: selectedTimeframe)
        } else if title.lowercased().contains("audit") {
            await controller.loadAuditCompliance(timeframe: selectedTimeframe)
        }
    }

    private func generatePDF() {
        isExporting = true
        
        let payload = ReportExportService.preparePayload(
            title: title,
            timeframe: selectedTimeframe.rawValue,
            controller: controller,
            userName: authController.currentUser?.name
        )
        
        let html = ReportHTMLTemplate.generate(payload: payload)
        
        PDFService.shared.generatePDF(fromHTML: html) { data in
            guard let data = data else {
                isExporting = false
                return
            }
            
            saveAndShare(data: data)
        }
    }
    
    private func saveAndShare(data: Data) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(title.replacingOccurrences(of: " ", with: "_"))_\(selectedTimeframe.rawValue.replacingOccurrences(of: " ", with: "_")).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            DispatchQueue.main.async {
                self.shareURL = fileURL
                self.isExporting = false
                self.showShareSheet = true
            }
        } catch {
            print("Error saving PDF: \(error)")
            DispatchQueue.main.async {
                self.isExporting = false
            }
        }
    }
}

