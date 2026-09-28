import SwiftUI

/// App root: the main navigation stack, with Setup as a full-screen cover on
/// top of it. Setup shows while `setup.finishedAt` is nil — first launch, after
/// a Reset, or after "Set up again" — and whenever a `setup/<screen>` deep link
/// asks for it. Nothing else decides; the extension's real state is read live.
/// Routes are mapped to screens here, in one place.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionState = ExtensionState()
    @State private var path: [Route] = []
    @State private var setupLink: SetupLink?
    @State private var showSetup: Bool
    @SharedJSON(SharedDefaultsKey.setup, default: Setup()) private var setup

    init() {
        // Decided before the first frame, so Main never flashes behind Setup.
        _showSetup = State(initialValue: UserDefaults.shared.decode(Setup.self, forKey: SharedDefaultsKey.setup)?.finishedAt == nil)
    }

    var body: some View {
        NavigationStack(path: $path) {
            MainView(state: extensionState)
                .navigationDestination(for: Route.self, destination: screen)
        }
        .fullScreenCover(isPresented: $showSetup) {
            SetupView(state: extensionState, link: setupLink) {
                setup.finishedAt = epochMs()
            }
        }
        .onChange(of: setup.finishedAt) { showSetup = setup.finishedAt == nil }
        // A dismissed Setup forgets its deep link, so the next run starts at welcome.
        .onChange(of: showSetup) { if !showSetup { setupLink = nil } else { path = [] } }
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

    /// Setup links (the Test page's "Back to the app") open Setup on that
    /// screen. Other deep links open on the main stack, over a running Setup.
    private func open(_ url: URL) {
        if let screen = Route.setupScreen(for: url) {
            setupLink = SetupLink(screen: screen, seq: (setupLink?.seq ?? 0) + 1)
            showSetup = true
            return
        }
        guard let route = Route.path(for: url) else { return }
        Market.preselectDeviceDefault()
        showSetup = false
        path = route
    }
}

#Preview {
    ContentView()
}
