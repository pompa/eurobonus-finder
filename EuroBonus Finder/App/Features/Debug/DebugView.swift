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
    @SharedJSON(SharedDefaultsKey.setup, default: Setup()) private var setup
    @SharedJSON(SharedDefaultsKey.permissions, default: Permissions()) private var permissions

    var body: some View {
        List {
            // The extension overwrites these on its next page load; enough to try each screen.
            Section {
                Button {
                    setup.finishedAt = nil
                } label: {
                    Text(verbatim: "Run Setup again (clear setup.finishedAt)")
                }
                Button {
                    UserDefaults.resetTutorial()
                    load()
                } label: {
                    Text(verbatim: "Reset tutorial")
                }
                Toggle(isOn: $permissions.hasAllUrls) { Text(verbatim: "permissions.hasAllUrls") }
                    .onChange(of: permissions.hasAllUrls) { state.readPermissionPing(); load() }
                Button {
                    permissions.pingedAt = Date().timeIntervalSince1970
                    state.readPermissionPing()
                    load()
                } label: {
                    Text(verbatim: "Stamp permission ping now")
                }
                Button {
                    UserDefaults.shared.removeObject(forKey: SharedDefaultsKey.permissions)
                    state.readPermissionPing()
                    load()
                } label: {
                    Text(verbatim: "Clear permissions")
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
