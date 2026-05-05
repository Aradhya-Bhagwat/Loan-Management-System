

import SwiftUI

struct MainTabView: View {
    @State private var chatDestination: ChatDestination?
    @State private var isLoadingChat = false

    struct ChatDestination: Identifiable {
        let id = UUID()
        let applicationId: UUID
        let borrowerId: UUID
        let officerId: UUID
        let officerName: String
    }

    init() {

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.theme.cardBackground)

        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.lightGray
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.lightGray
        ]

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            LoansView()
                .tabItem {
                    Label("Loans", systemImage: "banknote.fill")
                }
        }
        .tint(Color.theme.primaryAccent)
        .task {
            await ChatNotificationMonitor.shared.start()
        }
        .onChange(of: ChatNavigationRouter.shared.pendingChatApplicationId) { _, newAppId in
            if let appId = newAppId {
                handleChatNavigation(applicationId: appId)
            }
        }
        .fullScreenCover(item: $chatDestination) { dest in
            NavigationStack {
                BorrowerChatView(
                    applicationId: dest.applicationId,
                    borrowerId: dest.borrowerId,
                    officerId: dest.officerId,
                    officerName: dest.officerName
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { chatDestination = nil }
                            .foregroundStyle(Color.theme.primaryAccent)
                    }
                }
            }
        }
        .overlay {
            if isLoadingChat {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                        Text("Opening chat…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func handleChatNavigation(applicationId: UUID) {

        ChatNavigationRouter.shared.clearPending()

        isLoadingChat = true

        Task {
            do {

                let applications = try await SupabaseManager.shared.fetchMyApplications()
                guard let app = applications.first(where: { $0.id == applicationId }) else {
                    print("❌ [MainTabView] Application not found for ID: \(applicationId)")
                    await MainActor.run { isLoadingChat = false }
                    return
                }

                guard let borrowerId = app.borrowerId,
                      let officerId = app.assignedOfficerId else {
                    print("❌ [MainTabView] Missing borrower or officer ID")
                    await MainActor.run { isLoadingChat = false }
                    return
                }

                let officer = try await SupabaseManager.shared.fetchOfficer(id: officerId)
                let officerName = officer?.fullName ?? "Loan Officer"

                await MainActor.run {
                    isLoadingChat = false
                    chatDestination = ChatDestination(
                        applicationId: applicationId,
                        borrowerId: borrowerId,
                        officerId: officerId,
                        officerName: officerName
                    )
                }
            } catch {
                print("❌ [MainTabView] Error navigating to chat: \(error)")
                await MainActor.run { isLoadingChat = false }
            }
        }
    }
}

#Preview {
    MainTabView()
}
