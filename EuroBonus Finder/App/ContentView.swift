import SwiftUI

/// App root: Setup until it's finished, then the main navigation stack.
/// Routes are mapped to screens here, in one place.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionState = ExtensionState()
    @State private var path: [Route] = []
    @State private var setupLink: SetupLink?
    @SharedJSON(SharedDefaultsKey.setup, default: Setup()) private var setup

    var body: some View {
        Group {
            if setup.state == .active {
                SetupView(state: extensionState, link: setupLink) { result in
                    withAnimation(.snappy) { setup.state = result }
                }
            } else {
                NavigationStack(path: $path) {
                    MainView(state: extensionState)
                        .navigationDestination(for: Route.self, destination: screen)
                }
            }
        }
        // Leaving Setup forgets its last deep link, so a later Reset (from
        // Settings or the extension) starts Setup at welcome rather than on the
        // Test page's return screen; coming back out starts the main stack fresh.
        .onChange(of: setup.state) {
            if setup.state == .active { path = [] } else { setupLink = nil }
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
        case .settings: SettingsView()
        case .about: AboutView()
        #if DEBUG
        case .debug: DebugView(state: extensionState)
        #endif
        }
    }

    /// Setup links jump within Setup, or land on extension settings once it's
    /// over. Other deep links open on the main stack; one arriving mid-Setup
    /// skips the rest of it (the user can finish setting up from extension settings).
    private func open(_ url: URL) {
        if let screen = Route.setupScreen(for: url) {
            if setup.state == .active {
                setupLink = SetupLink(screen: screen, seq: (setupLink?.seq ?? 0) + 1)
            } else {
                path = [.extensionSettings]
            }
            return
        }
        guard let route = Route.path(for: url) else { return }
        if setup.state == .active {
            Market.preselectDeviceDefault()
            setup.state = .incomplete
        }
        path = route
    }
}

#Preview {
    ContentView()
}
