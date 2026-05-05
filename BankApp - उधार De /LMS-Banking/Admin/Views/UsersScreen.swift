import SwiftUI

struct UsersScreen: View {
    let metrics: DashboardLayoutMetrics
    @Bindable var controller: AdminDashboardViewModel
    @State private var isPresentingBulkInvite = false
    @State private var isPresentingSingleInvite = false

    private var roleSearchPlaceholder: String {
        "Search \(controller.selectedRole.title.lowercased())s..."
    }
    
    private var userCardHeight: CGFloat {
        metrics.isCompact ? 135 : 155
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Area
                VStack(alignment: .leading, spacing: 16) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextField(roleSearchPlaceholder, text: $controller.searchText)
                            .textFieldStyle(.plain)
                            .font(.body)

                        if !controller.searchText.isEmpty {
                            Button {
                                controller.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.appCard)
                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .padding(.horizontal, metrics.horizontalPadding)

                    // Role Selector
                    Picker("User Role", selection: $controller.selectedRole) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.title).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, metrics.horizontalPadding)

                    // Stats Summary
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(controller.selectedRole.title)s")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("\(controller.filteredUsers.count)")
                                .font(.headline.bold())
                                .foregroundColor(.appGreen)
                            Text("Total")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appGreen.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, metrics.horizontalPadding)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(
                    Rectangle()
                        .fill(Color.appBackground)
                        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 5)
                )

                // User Content
                ScrollView {
                    VStack(spacing: 16) {
                        if controller.filteredUsers.isEmpty {
                            emptyStateView
                        } else {
                            LazyVGrid(columns: metrics.userGridColumns, spacing: metrics.isCompact ? 12 : 20) {
                                ForEach(controller.filteredUsers) { user in
                                    NavigationLink {
                                        UserDetailView(user: user, controller: controller)
                                    } label: {
                                        UserCard(user: user)
                                            .contextMenu {
                                                Button {
                                                    let isBlocked = user.status == .blocked
                                                    controller.setUserBlocked(id: user.id, name: user.name, branch: user.branch, isBlocked: !isBlocked)
                                                } label: {
                                                    Label(user.status == .blocked ? "Unblock User" : "Block User", 
                                                          systemImage: user.status == .blocked ? "lock.open.fill" : "lock.fill")
                                                }
                                                
                                                Button(role: .destructive) {
                                                    controller.deleteUser(id: user.id)
                                                } label: {
                                                    Label("Delete User", systemImage: "trash")
                                                }
                                            }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: userCardHeight, maxHeight: userCardHeight, alignment: .topLeading)
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 120) // Extra padding for FAB
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    controller.fetchUsers()
                }
            }

            // Floating Action Button
            actionButton
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Branch", selection: $controller.selectedUserBranch) {
                        Text("All Branches").tag("All")
                        ForEach(controller.userBranchOptions, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .symbolVariant(controller.selectedUserBranch == "All" ? .none : .fill)
                        .foregroundColor(controller.selectedUserBranch == "All" ? .primary : .appGreen)
                }
            }
        }
        .sheet(isPresented: $isPresentingBulkInvite) {
            BulkInviteView(controller: controller)
        }
        .sheet(isPresented: $isPresentingSingleInvite) {
            NavigationStack {
                AddUserView { name, email, phone, role, branch in
                    controller.inviteUser(name: name, email: email, phone: phone, role: role, branch: branch)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { isPresentingSingleInvite = false }
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: controller.selectedRole)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: controller.searchText)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: controller.selectedUserBranch)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            
            ZStack {
                Circle()
                    .fill(Color.appGreen.opacity(0.05))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appGreen, .appGreen.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No \(controller.selectedRole.title.lowercased())s found")
                    .font(.title3.bold())
                
                Text(controller.searchText.isEmpty && !controller.hasActiveUserFilters
                     ? "You haven't added any \(controller.selectedRole.title.lowercased())s yet."
                     : "Try adjusting your search terms or branch filter to find what you're looking for.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if controller.searchText.isEmpty && !controller.hasActiveUserFilters {
                Button {
                    isPresentingSingleInvite = true
                } label: {
                    Text("Add First \(controller.selectedRole.title)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.appGreen)
                        .clipShape(Capsule())
                }
            } else {
                Button("Clear Search and Filters") {
                    controller.searchText = ""
                    controller.clearUserFilters()
                }
                .font(.headline)
                .foregroundColor(.appGreen)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actionButton: some View {
        Menu {
            Button {
                isPresentingSingleInvite = true
            } label: {
                Label("Add Single User", systemImage: "person.badge.plus")
            }

            Button {
                isPresentingBulkInvite = true
            } label: {
                Label("Bulk Import Users", systemImage: "tray.and.arrow.down")
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                
                if !metrics.isCompact {
                    Text("Add User")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, metrics.isCompact ? 20 : 24)
            .padding(.vertical, 20)
            .background(
                Capsule()
                    .fill(Color.appGreen)
                    .shadow(color: Color.appGreen.opacity(0.35), radius: 15, x: 0, y: 8)
            )
        }
        .padding(.trailing, metrics.horizontalPadding)
        .padding(.bottom, 28)
    }
}
