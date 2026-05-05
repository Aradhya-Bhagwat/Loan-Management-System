

import SwiftUI
import Supabase
import LocalAuthentication

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("useBiometrics") private var useBiometrics = false
    @State private var isUnlocked = false

    var body: some View {
        ZStack {
            Group {
            if authManager.isChecking {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authManager.isAuthenticated {
                if authManager.needsPasswordSetup {

                    SetPasswordView()
                } else {

                    MainTabView()
                }
            } else {

                OnboardingRouter()
            }
            }

            if useBiometrics && !isUnlocked {
                Color.theme.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    Image(systemName: "faceid")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.theme.primaryAccent)
                    Text("App Locked")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(Color.theme.textPrimary)
                    Button("Unlock") {
                        authenticate()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.theme.primaryAccent)
                    .controlSize(.large)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                if useBiometrics {
                    isUnlocked = false
                }
            } else if newPhase == .active {
                if useBiometrics && !isUnlocked {
                    authenticate()
                }
            }
        }
        .onAppear {
            if useBiometrics && !isUnlocked {
                authenticate()
            } else if !useBiometrics {
                isUnlocked = true
            }
        }
    }

    private func authenticate() {
        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock your app") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        isUnlocked = true
                    }
                }
            }
        } else {

            isUnlocked = true
        }
    }
}
