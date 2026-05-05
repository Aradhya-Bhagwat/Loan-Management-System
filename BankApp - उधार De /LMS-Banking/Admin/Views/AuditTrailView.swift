import SwiftUI

struct AuditTrailView: View {
    @Bindable var controller: AdminDashboardViewModel
    @State private var rowsPerPage: Int = 25
    @State private var currentPage: Int = 0
    @State private var daysBack: Int = 90
    @State private var selectedEntry: AuditEntry? = nil

    private var cutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
    }

    private var filtered: [AuditEntry] {
        controller.filteredAuditEntries.filter { entry in
            guard let date = parseDate(entry.time) else { return true }
            return date >= cutoffDate
        }
    }

    private var totalCount: Int { filtered.count }
    private var totalPages: Int { max(1, Int(ceil(Double(totalCount) / Double(rowsPerPage)))) }
    private var rangeStart: Int { totalCount == 0 ? 0 : currentPage * rowsPerPage + 1 }
    private var rangeEnd: Int { min(rangeStart + rowsPerPage - 1, totalCount) }

    private var pagedEntries: [AuditEntry] {
        let start = currentPage * rowsPerPage
        let end = min(start + rowsPerPage, totalCount)
        guard start < totalCount else { return [] }
        return Array(filtered[start..<end])
    }

    var body: some View {
        List {
            // 1. Insights Summary Section
            Section {
                HStack(spacing: 0) {
                    AuditMetricItem(title: "Total", value: "\(totalCount)", color: .primary)
                    Divider().padding(.vertical, 8)
                    AuditMetricItem(title: "Success", value: "\(successRate)%", color: .appGreen)
                    Divider().padding(.vertical, 8)
                    AuditMetricItem(title: "Alerts", value: "\(securityAlertCount)", color: securityAlertCount > 0 ? .appRed : .secondary)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.appCard)
            .listRowInsets(EdgeInsets())

            // 2. Active Filters Section (Only shown when filtered)
            if controller.hasActiveAuditFilters || daysBack != 90 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if daysBack != 90 {
                                FilterBadge(text: "Last \(daysBack)d") { daysBack = 90 }
                            }
                            if controller.selectedBranch != "All" {
                                FilterBadge(text: controller.selectedBranch) { controller.selectedBranch = "All" }
                            }
                            if controller.selectedCategory != "All" {
                                FilterBadge(text: controller.selectedCategory) { controller.selectedCategory = "All" }
                            }
                            if controller.selectedStatus != "All" {
                                FilterBadge(text: controller.selectedStatus) { controller.selectedStatus = "All" }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            // 3. Log Entries Section
            Section {
                if pagedEntries.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try adjusting your filters or search terms.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(pagedEntries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            AuditRowNative(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                HStack {
                    Text("ACTIVITY LOG")
                    Spacer()
                    Text("\(rangeStart)-\(rangeEnd) of \(totalCount)")
                        .font(.caption2.monospacedDigit())
                        .fontWeight(.bold)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.appBackground)
        .navigationTitle("Audit Trails")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $controller.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search actor, action, or branch")
        .refreshable { await DatabaseService.shared.fetchAuditTrail() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    if currentPage > 0 { currentPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
                .disabled(currentPage == 0)
            }
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Picker("Page", selection: $currentPage) {
                        ForEach(0..<totalPages, id: \.self) { page in
                            Text("Page \(page + 1) of \(totalPages)").tag(page)
                        }
                    }
                } label: {
                    Text("Page \(currentPage + 1) of \(totalPages)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    if currentPage < totalPages - 1 { currentPage += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .fontWeight(.semibold)
                }
                .disabled(currentPage >= totalPages - 1)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            AuditDetailSheet(entry: entry)
        }
    }

    private var filterMenu: some View {
        Menu {
            Menu("Time Range") {
                Picker("Time", selection: $daysBack) {
                    Text("Last 30 Days").tag(30)
                    Text("Last 60 Days").tag(60)
                    Text("Last 90 Days").tag(90)
                    Text("Last 180 Days").tag(180)
                }
            }
            
            Menu("Branch") {
                Picker("Branch", selection: $controller.selectedBranch) {
                    Text("All Branches").tag("All")
                    ForEach(controller.auditBranchOptions, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
            }

            Menu("Category") {
                Picker("Category", selection: $controller.selectedCategory) {
                    Text("All Categories").tag("All")
                    ForEach(controller.auditCategoryOptions, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
            }

            Menu("Status") {
                Picker("Status", selection: $controller.selectedStatus) {
                    Text("All Status").tag("All")
                    ForEach(controller.auditStatusOptions, id: \.self) { stat in
                        Text(stat).tag(stat)
                    }
                }
            }

            if controller.hasActiveAuditFilters || daysBack != 90 {
                Divider()
                Button(role: .destructive) {
                    controller.clearAuditFilters()
                    daysBack = 90
                    currentPage = 0
                } label: {
                    Label("Reset All", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .symbolVariant((controller.hasActiveAuditFilters || daysBack != 90) ? .fill : .none)
        }
    }

    // MARK: - Helpers

    private var successRate: Int {
        let successful = filtered.filter { $0.displayStatus.lowercased().contains("success") || $0.displayStatus.lowercased().contains("active") || $0.displayStatus.lowercased().contains("verified") }.count
        return filtered.isEmpty ? 100 : (successful * 100 / filtered.count)
    }

    private var securityAlertCount: Int {
        filtered.filter { $0.displayCategory.lowercased().contains("security") || $0.displayStatus.lowercased().contains("blocked") }.count
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

// MARK: - Subviews

struct AuditMetricItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FilterBadge: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.appGreen.opacity(0.1))
        .foregroundColor(.appGreen)
        .clipShape(Capsule())
    }
}

struct AuditRowNative: View {
    let entry: AuditEntry
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: entry.displayIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(entry.iconColor)
                .frame(width: 36, height: 36)
                .background(entry.iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text(entry.displayActor)
                    Text("•")
                    Text(entry.displayBranch)
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text(entry.displayStatus)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(entry.statusColor)
                    .textCase(.uppercase)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AuditDetailSheet: View {
    let entry: AuditEntry
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Action", value: entry.displayTitle)
                    LabeledContent("Actor", value: entry.displayActor)
                    LabeledContent("Branch", value: entry.displayBranch)
                    LabeledContent("Category", value: entry.displayCategory)
                    LabeledContent("Status", value: entry.displayStatus)
                } header: {
                    Text("Transaction Details")
                }
                
                Section {
                    LabeledContent("Date", value: entry.time)
                    LabeledContent("Event ID", value: entry.id.uuidString)
                        .font(.system(size: 12, design: .monospaced))
                } header: {
                    Text("System Metadata")
                }
            }
            .navigationTitle("Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
