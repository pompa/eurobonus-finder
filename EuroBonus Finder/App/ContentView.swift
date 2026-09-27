import SwiftUI

/// App root: Setup until it's finished, then the main navigation stack.
/// Routes are mapped to screens here, in one place.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionState = ExtensionState()
    @State private var path: [Route] = []
    @State private var setupLink: SetupLink?
    @AppStorage(SharedDefaultsKey.setupState, store: .shared) private var setupState = SetupState.active

    var body: some View {
        Group {
            if setupState == .active {
                SetupView(state: extensionState, link: setupLink) { result in
                    withAnimation(.snappy) { setupState = result }
                }
            } else {
                NavigationStack(path: $path) {
                    MainView(state: extensionState)
                        .navigationDestination(for: Route.self, destination: screen)
                }
                .tint(.blue)
            }
        }
        // A Reset (from About or the extension) drops back to Setup; start the
        // main stack fresh when the user comes out of it.
        .onChange(of: setupState) { if setupState == .active { path = [] } }
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
            if setupState == .active {
                setupLink = SetupLink(screen: screen, seq: (setupLink?.seq ?? 0) + 1)
            } else {
                path = [.extensionSettings]
            }
            return
        }
        guard let route = Route.path(for: url) else { return }
        if setupState == .active {
            Market.preselectDeviceDefault()
            setupState = .incomplete
        }
        path = route
    }
}

#Preview {
    ContentView()
}
