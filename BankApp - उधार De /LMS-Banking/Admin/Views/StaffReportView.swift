import SwiftUI

struct StaffReportView: View {
    @Bindable var controller: AdminDashboardViewModel
    @State private var searchText = ""
    @State private var selectedRole: UserRole = .officer

    private var staff: [UserItem] {
        controller.users.filter { $0.role != .borrower }
    }

    private var filtered: [UserItem] {
        staff.filter { user in
            let matchRole = user.role == selectedRole
            let matchSearch = searchText.isEmpty
                || user.name.localizedCaseInsensitiveContains(searchText)
                || user.email.localizedCaseInsensitiveContains(searchText)
                || user.branch.localizedCaseInsensitiveContains(searchText)
            return matchRole && matchSearch
        }
    }

    // Breakdown counts
    private var roleCounts: [(role: UserRole, count: Int)] {
        UserRole.allCases
            .filter { $0 != .borrower }
            .map { role in (role, staff.filter { $0.role == role }.count) }
            .filter { $0.count > 0 }
    }

    var body: some View {
        List {
            // Summary cards
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        staffSummaryChip(
                            label: "Total",
                            count: staff.count,
                            color: .appGreen
                        )
                        ForEach(roleCounts, id: \.role) { item in
                            staffSummaryChip(
                                label: item.role.title,
                                count: item.count,
                                color: .appGreen
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            // Role filter
            Section {
                Picker("Role", selection: $selectedRole) {
                    ForEach(UserRole.allCases.filter { $0 != .borrower }) { role in
                        Text(role.title).tag(role)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Search
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by name, email or branch…", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Staff list
            Section("\(filtered.count) \(selectedRole.title)\(filtered.count == 1 ? "" : "s")") {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No \(selectedRole.title)s found",
                        systemImage: "person.slash",
                        description: Text(searchText.isEmpty ? "No staff in this role." : "Try a different search.")
                    )
                } else {
                    ForEach(filtered) { user in
                        NavigationLink {
                            UserDetailView(user: user, controller: controller)
                        } label: {
                            staffRow(user)
                        }
                    }
                }
            }
        }
        .navigationTitle("Staff Report")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search staff…")
        .onAppear { controller.fetchUsers() }
    }

    // MARK: - Subviews

    private func staffRow(_ user: UserItem) -> some View {
        HStack(spacing: 14) {
            Text(user.initials)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.appGreen)
                .frame(width: 44, height: 44)
                .background(Color.appGreen.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(user.name)
                    .font(.body.weight(.semibold))
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(user.branch)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                AppStatusBadge(text: user.status.title, color: user.status.textColor)
            }
        }
        .padding(.vertical, 4)
    }

    private func staffSummaryChip(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 72)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}
