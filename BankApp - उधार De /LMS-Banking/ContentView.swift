import SwiftUI

// MARK: - Root Content View
struct ContentView: View {
    @State private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            // Priority 0: MFA step-up (aal2)
            if authViewModel.isMfaChallengeRequired {
                MFAChallengeView(authController: authViewModel)
            }
            // Priority 1: Password Reset flow
            else if authViewModel.isPasswordResetRequired {
                AuthView(authController: authViewModel)
            } 
            // Priority 2: Dashboard flow (only if authenticated AND user is available)
            else if authViewModel.isAuthenticated, let user = authViewModel.currentUser {
                switch user.role {
                case .admin:
                    AdminDashboardView()
                        .environment(authViewModel)
                case .manager:
                    ManagerRootView()
                        .environment(authViewModel)
                case .officer:
                    LoanOfficerDashboardView(officerId: user.id)
                        .environment(authViewModel)
                case .borrower:
                    VStack {
                        Text("Borrower Dashboard")
                            .font(.largeTitle)
                        Button("Logout") {
                            authViewModel.logout()
                        }
                        .padding()
                    }
                    .environment(authViewModel)
                }
            } 
            // Default: Show login screen
            else {
                AuthView(authController: authViewModel)
            }
        }
        .animation(.easeInOut, value: authViewModel.isAuthenticated)
        .animation(.easeInOut, value: authViewModel.isPasswordResetRequired)
        .animation(.easeInOut, value: authViewModel.isMfaChallengeRequired)
        .onOpenURL { url in
            authViewModel.handleDeepLink(url: url)
        }
        .sheet(
            isPresented: Binding(
                get: { authViewModel.isPresentingMfaEnrollment },
                set: { authViewModel.isPresentingMfaEnrollment = $0 }
            )
        ) {
            MFAEnrollmentView(authController: authViewModel)
        }
    }
}

struct ManagerRootView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @State private var router = AppRouter.shared
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var loansViewModel = LoansViewModel()
    @State private var isLiveRefreshActive = false

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Overview", systemImage: "square.grid.2x2.fill", value: 0) {
                NavigationStack {
                    DashboardView(controller: dashboardViewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink {
                                    SettingsView()
                                } label: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(Color.appGreen)
                                }
                            }
                        }
                }
            }

            Tab("Loans", systemImage: "building.columns.fill", value: 1) {
                NavigationStack {
                    LoansView(selectedSegment: $router.loansSegment, controller: loansViewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink {
                                    SettingsView()
                                } label: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(Color.appGreen)
                                }
                            }
                        }
                }
            }
        }
        .tint(.appGreen)
        .onAppear {
            let branch = authViewModel.currentUser?.branch
            dashboardViewModel.branch = branch
            loansViewModel.branch = branch
            startLiveRefresh()
        }
        .onDisappear { stopLiveRefresh() }
    }

    private func startLiveRefresh() {
        guard !isLiveRefreshActive else { return }
        isLiveRefreshActive = true
        DatabaseService.shared.startLiveRefresh { [weak dashboardViewModel] in
            Task { @MainActor in
                dashboardViewModel?.loadData()
            }
        }
        DatabaseService.shared.startLiveRefresh { [weak loansViewModel] in
            Task { @MainActor in
                loansViewModel?.loadData()
            }
        }
    }

    private func stopLiveRefresh() {
        isLiveRefreshActive = false
        DatabaseService.shared.stopLiveRefresh()
    }
}

#Preview {
    ContentView()
}
