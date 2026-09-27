import SwiftUI

#if DEBUG

/// Debug — raw values for troubleshooting: the app's live extension state, the
/// App Group the app and extension share, and the app's own defaults.
/// Keys and values are shown verbatim, so nothing here is localized.
struct DebugView: View {
    let state: ExtensionState
    @State private var shared: [(key: String, value: String)] = []
    @State private var standard: [(key: String, value: String)] = []

    // Writable copies of the App Group values that drive the app's screens.
    @AppStorage(SharedDefaultsKey.setupState, store: .shared) private var setupState = SetupState.active
    @AppStorage(SharedDefaultsKey.tutorialProgress(.seenBadge), store: .shared) private var seenBadge = false
    @AppStorage(SharedDefaultsKey.tutorialProgress(.visitedPartner), store: .shared) private var visitedPartner = false
    @AppStorage(SharedDefaultsKey.tutorialProgress(.sasShoppingReturn), store: .shared) private var sasShoppingReturn = false
    @AppStorage(SharedDefaultsKey.permissionHasAllUrls, store: .shared) private var hasAllUrls = false

    var body: some View {
        List {
            // The extension overwrites these on its next page load; enough to try each screen.
            Section {
                Picker(selection: $setupState) {
                    ForEach(SetupState.allCases, id: \.self) { Text(verbatim: $0.rawValue) }
                } label: {
                    Text(verbatim: "setupState")
                }
                Toggle(isOn: $seenBadge) { Text(verbatim: "tutorialProgress.seenBadge") }
                Toggle(isOn: $visitedPartner) { Text(verbatim: "tutorialProgress.visitedPartner") }
                Toggle(isOn: $sasShoppingReturn) { Text(verbatim: "tutorialProgress.sasShoppingReturn") }
                Toggle(isOn: $hasAllUrls) { Text(verbatim: "permission.hasAllUrls") }
                    .onChange(of: hasAllUrls) { state.readPermissionPing(); load() }
                Button {
                    UserDefaults.shared.set(Date().timeIntervalSince1970, forKey: SharedDefaultsKey.permissionPingTimestamp)
                    state.readPermissionPing()
                    load()
                } label: {
                    Text(verbatim: "Stamp permission ping now")
                }
                Button {
                    UserDefaults.shared.removeObject(forKey: SharedDefaultsKey.permissionPingTimestamp)
                    state.readPermissionPing()
                    load()
                } label: {
                    Text(verbatim: "Clear permission ping")
                }
            } header: {
                Text(verbatim: "Controls")
            }
            .font(.footnote.monospaced())

            Section {
                row("status", String(describing: state.status))
                row("hostPermission", String(describing: state.hostPermission))
                row("lastPingAt", state.lastPingAt.map { String(describing: $0) } ?? "nil")
                row("rateLimitedUntil", state.rateLimitedUntil.map { String(describing: $0) } ?? "nil")
            } header: {
                Text(verbatim: "Extension state")
            }

            Section {
                ForEach(shared, id: \.key) { row($0.key, $0.value) }
            } header: {
                Text(verbatim: "App Group (app + extension)")
            }

            Section {
                ForEach(standard, id: \.key) { row($0.key, $0.value) }
            } header: {
                Text(verbatim: "App defaults")
            }
        }
        .textSelection(.enabled)
        .navigationTitle("about.debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                Task { await refresh() }
            } label: {
                Label {
                    Text(verbatim: "Refresh")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .refreshable { await refresh() }
        .onAppear(perform: load)
    }

    /// Reloads at once, then again once `state.refresh()` returns (it waits up to 2.5s for Safari).
    private func refresh() async {
        load()
        await state.refresh()
        load()
    }

    private func row(_ key: String, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value)
        } label: {
            Text(verbatim: key).font(.footnote.monospaced())
        }
    }

    private func load() {
        shared = Self.dump(UserDefaults.shared, domain: appGroupID)
        standard = Self.dump(.standard, domain: Bundle.main.bundleIdentifier!)
    }

    private static func dump(_ defaults: UserDefaults, domain: String) -> [(key: String, value: String)] {
        (defaults.persistentDomain(forName: domain) ?? [:])
            .map { (key: $0.key, value: String(describing: $0.value)) }
            .sorted { $0.key < $1.key }
    }
}
#endif
