import SwiftUI

struct AdminDashboardView: View {
    @Environment(AuthViewModel.self) var authController
    @State private var controller = AdminDashboardViewModel()

    var body: some View {
        GeometryReader { proxy in
            let metrics = DashboardLayoutMetrics(width: proxy.size.width)

            TabView(selection: $controller.selectedTab) {
                NavigationStack {
                    OverviewScreen(metrics: metrics, controller: controller)
                        .navigationTitle("Overview")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink {
                                    AdminProfileView()
                                } label: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: metrics.isLargePadLayout ? 30 : 24, weight: .semibold))
                                        .foregroundColor(.appGreen)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                }
                .tabItem { Label("Overview", systemImage: AdminTab.overview.icon) }
                .tag(AdminTab.overview)

                NavigationStack {
                    UsersScreen(metrics: metrics, controller: controller)
                        .navigationTitle("Users")
                }
                .tabItem { Label("Users", systemImage: AdminTab.users.icon) }
                .tag(AdminTab.users)

                NavigationStack {
                    ControlScreen(metrics: metrics, controller: controller)
                        .navigationTitle("Control")
                }
                .tabItem { Label("Control", systemImage: AdminTab.control.icon) }
                .tag(AdminTab.control)
            }
            .tint(Color.appGreen)
            .onAppear {
                if let adminName = authController.currentUser?.name {
                    controller.currentAdminName = adminName
                }
            }
            .onAppear { controller.startLiveRefresh() }
            .onDisappear { controller.stopLiveRefresh() }
        }
    }
}
