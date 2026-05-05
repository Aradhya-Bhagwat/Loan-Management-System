import Foundation

class CSVService {
    static let shared = CSVService()
    private init() {}

    func generateCSV(
        title: String,
        kpis: [KPI],
        auditEntries: [AuditEntry],
        includeAudit: Bool
    ) -> String {
        var csvString = "Report Title,Value,Change\n"
        
        // Add KPIs
        for kpi in kpis {
            csvString += "\(kpi.title),\(kpi.value.replacingOccurrences(of: ",", with: "")),\(kpi.change ?? "")\n"
        }
        
        if includeAudit {
            csvString += "\nAudit Trail\n"
            csvString += "Date,Actor,Action,Status\n"
            for entry in auditEntries {
                csvString += "\(entry.time),\(entry.displayActor),\(entry.displayTitle),\(entry.displayStatus)\n"
            }
        }
        
        return csvString
    }
}
