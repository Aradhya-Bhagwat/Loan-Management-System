import SwiftUI

struct NotificationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var notifications: [UserNotification] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonNotificationRow()
                        }
                    } else if notifications.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 64))
                                .foregroundColor(Color.gray.opacity(0.3))
                            Text("No notifications yet")
                                .font(.headline)
                                .foregroundColor(Color.theme.textSecondary)
                            Text("Payment receipts and updates will appear here")
                                .font(.subheadline)
                                .foregroundColor(Color.theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 100)
                    } else {
                        ForEach(notifications) { notification in
                            NotificationRow(notification: notification)
                                .onTapGesture {
                                    handleNotificationTap(notification)
                                }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.theme.appBackground.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.theme.primaryAccent)
                }
            }
            .task {
                await loadNotifications()
            }
            .refreshable {
                await loadNotifications()
            }
        }
    }

    private func loadNotifications() async {
        do {
            notifications = try await SupabaseManager.shared.fetchNotifications()
        } catch is CancellationError {

        } catch {
            print("Error fetching notifications: \(error)")
        }
        isLoading = false
    }

    private func handleNotificationTap(_ notification: UserNotification) {

        if !notification.isRead {
            Task {
                try? await SupabaseManager.shared.markNotificationRead(id: notification.id)
                await loadNotifications()
            }
        }

        if notification.type == "chat", let appId = notification.applicationId {

            dismiss()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                ChatNavigationRouter.shared.navigateToChat(applicationId: appId)
            }
        }
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let notification: UserNotification

    private var iconColor: Color {
        switch notification.type {
        case "payment": return Color.green
        case "loan": return Color.blue
        case "alert": return Color.orange
        case "chat": return Color.purple
        default: return Color.theme.primaryAccent
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: notification.typeIcon)
                    .foregroundColor(iconColor)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.theme.textPrimary)

                    if !notification.isRead {
                        Circle()
                            .fill(Color.theme.primaryAccent)
                            .frame(width: 8, height: 8)
                    }

                    Spacer()
                    Text(notification.timeAgo)
                        .font(.caption2)
                        .foregroundColor(Color.theme.textSecondary)
                }

                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(Color.theme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if notification.type == "chat" && notification.applicationId != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption2)
                        Text("Tap to open chat")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(Color.purple)
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(notification.isRead ? Color.theme.cardBackground : Color.theme.primaryAccent.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Skeleton
struct SkeletonNotificationRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 14)
                    .frame(maxWidth: 200)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.08))
                    .frame(height: 12)
            }
        }
        .padding(16)
        .background(Color.theme.cardBackground)
        .cornerRadius(16)
        .redacted(reason: .placeholder)
    }
}

#Preview {
    NotificationView()
}
