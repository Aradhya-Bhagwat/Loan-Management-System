import SwiftUI

struct LoanOfficerNotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationService = NotificationService.shared
    @State private var selectedFilter: NotificationFilter = .all
    var onSelect: (LoanOfficerNotification) -> Void

    private var filteredNotifications: [LoanOfficerNotification] {
        notificationService.notifications.filter { notification in
            selectedFilter.matches(notification.type)
        }
    }

    private var unreadFilteredCount: Int {
        filteredNotifications.filter { !$0.isRead }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OfficerTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter bar
                    filterBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    if notificationService.isLoading && notificationService.notifications.isEmpty {
                        Spacer()
                        ProgressView("Loading notifications…")
                            .tint(.appGreen)
                        Spacer()
                    } else if filteredNotifications.isEmpty {
                        Spacer()
                        emptyState
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredNotifications) { notification in
                                    NotificationRow(
                                        notification: notification,
                                        onTap: {
                                            notificationService.markAsRead(notification.id)
                                            onSelect(notification)
                                            dismiss()
                                        },
                                        onMarkRead: {
                                            notificationService.markAsRead(notification.id)
                                        },
                                        onDelete: {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                notificationService.deleteNotification(notification.id)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .refreshable {
                            await notificationService.loadNotifications()
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if notificationService.unreadCount > 0 {
                        Button {
                            notificationService.markAllRead()
                        } label: {
                            Text("Read All")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.appGreen)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if !notificationService.notifications.isEmpty {
                            Button {
                                // Add a simple confirmation or just delete
                                notificationService.deleteAllNotifications()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                        }
                        
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.appGreen)
                    }
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(NotificationFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 11, weight: .bold))

                        Text(filter.title)
                            .font(.system(size: 13, weight: .semibold))

                        let count = filter.unreadCount(in: notificationService.notifications)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(selectedFilter == filter ? .white.opacity(0.3) : Color.appGreen)
                                )
                        }
                    }
                    .foregroundStyle(selectedFilter == filter ? .white : OfficerTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(selectedFilter == filter ? Color.appGreen : OfficerTheme.filterBackground)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(OfficerTheme.accentGreen.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "bell.slash")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(OfficerTheme.accentGreen.opacity(0.5))
            }

            Text("No notifications")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OfficerTheme.textPrimary)

            Text(selectedFilter == .all
                 ? "You're all caught up! New notifications will appear here."
                 : "No \(selectedFilter.title.lowercased()) notifications yet.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OfficerTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: LoanOfficerNotification
    let onTap: () -> Void
    let onMarkRead: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(notification.iconColor.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: notification.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(notification.iconColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(notification.title)
                            .font(.system(size: 16, weight: notification.isRead ? .medium : .bold))
                            .foregroundStyle(OfficerTheme.textPrimary)
                            .lineLimit(1)

                        if !notification.isRead {
                            Circle()
                                .fill(.appGreen)
                                .frame(width: 8, height: 8)
                        }

                        Spacer()

                        Text(notification.relativeTimestamp)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(OfficerTheme.textSecondary)
                    }

                    Text(notification.subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(OfficerTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Type tag
                    HStack(spacing: 4) {
                        Image(systemName: notification.iconName)
                            .font(.system(size: 9, weight: .bold))
                        Text(notification.type.displayTitle)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(notification.iconColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(notification.iconColor.opacity(0.1))
                    .clipShape(Capsule())
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(OfficerTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        notification.isRead ? OfficerTheme.softLine : OfficerTheme.accentGreen.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .opacity(notification.isRead ? 0.75 : 1.0)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !notification.isRead {
                Button {
                    onMarkRead()
                } label: {
                    Label("Mark as Read", systemImage: "envelope.open")
                }
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    LoanOfficerNotificationsView(onSelect: { _ in })
        .preferredColorScheme(.dark)
}
