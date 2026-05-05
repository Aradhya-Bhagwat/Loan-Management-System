import Foundation

@Observable
class InsightsViewModel {
    var reportTypes: [InsightReportType] = []
    var selectedRange: String = "Last 30 days"
    let ranges = ["Last 7 days", "Last 30 days", "Last 90 days", "Year to Date"]
    var isLoading = false
    var branch: String? = nil

    init() {
        loadData()
    }

    func loadData() {
        isLoading = true
        Task {
            do {
                let rt = try await DatabaseService.shared.fetchReportTypes()
                await MainActor.run {
                    self.reportTypes = rt
                    self.isLoading = false
                }
            } catch {
                print("Error loading insights data: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    func exportPDF(reportType: InsightReportType) async -> URL? {
        // TODO: Supabase report generation
        return nil
    }

    func exportExcel(reportType: InsightReportType) async -> URL? {
        // TODO: Supabase report generation
        return nil
    }
}
