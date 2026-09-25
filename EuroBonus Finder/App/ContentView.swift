import SwiftUI

/// App root: onboarding until it's finished, then the main navigation stack.
/// Routes are mapped to screens here, in one place.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionState = ExtensionState()
    @State private var path: [Route] = []
    @AppStorage(OnboardingState.storageKey) private var onboardingState = OnboardingState.active

    var body: some View {
        Group {
            if onboardingState == .active {
                OnboardingView(state: extensionState) { result in
                    withAnimation(.snappy) { onboardingState = result }
                }
            } else {
                NavigationStack(path: $path) {
                    MainView(state: extensionState) {
                        withAnimation(.snappy) { onboardingState = .active }
                    }
                    .navigationDestination(for: Route.self, destination: screen)
                }
                .tint(.blue)
            }
        }
        .onOpenURL(perform: open)
        .task(id: scenePhase) {
            if scenePhase == .active { await extensionState.refresh() }
        }
    }

    @ViewBuilder
    private func screen(for route: Route) -> some View {
        switch route {
        case .extensionSettings: ExtensionSettingsView(state: extensionState)
        case .about: AboutView()
        }
    }

    /// Deep links open on the main stack; one arriving mid-onboarding skips the
    /// rest of it (the user can finish setting up from extension settings).
    private func open(_ url: URL) {
        guard let route = Route.path(for: url) else { return }
        if onboardingState == .active {
            Market.preselectDeviceDefault()
            onboardingState = .incomplete
        }
        path = route
    }
}

#Preview {
    ContentView()
}
