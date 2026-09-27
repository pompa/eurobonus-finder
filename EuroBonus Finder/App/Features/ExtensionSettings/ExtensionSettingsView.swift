import SwiftUI

// Extension settings — reached from the main view's Safari Extension row and
// the `…://extension` deep link. Same inset-grouped style as the main view: the
// live status of the extension and its website access, a link into Safari's
// settings for it (rate-limited by iOS; see `ExtensionState`), and the Test
// page with troubleshooting for when website access isn't confirmed.

struct ExtensionSettingsView: View {
    let state: ExtensionState
    @State private var troubleshooting = false

    var body: some View {
        let allowed = state.isGranted(.allWebsites) == true
        List {
            Section {
                SettingsRow(symbol: "puzzlepiece.extension.fill", title: "settings.extension",
                            detail: extensionStatusText.map { Text($0) })
                // Safari only reveals Allow; Ask and Deny look identical to the
                // extension, so anything else is unknown and shown as a warning.
                SettingsRow(symbol: "network", title: "extensionSettings.permissions",
                            detail: allowed ? Text("extensionSettings.permission.allow") : nil,
                            warning: !allowed)
                if state.isRateLimited {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        openSettingsRow(detail: Text(verbatim: state.settingsCountdown(at: context.date)).monospacedDigit())
                            .disabled(true)
                    }
                } else {
                    openSettingsRow(detail: nil)
                }
            } footer: {
                // One hint at a time, most pressing first.
                if let error = state.errorMessage {
                    Text(verbatim: error)
                } else if state.isRateLimited {
                    Text("extension.settingsPath")
                        .opensSettingsApps()
                } else if state.status != .enabled {
                    Text("extensionSettings.extensionHint")
                } else if !allowed {
                    Text("extensionSettings.permissionHint")
                }
            }

            Section {
                Link(destination: TestPage.url(setup: true)) {
                    SettingsRow(symbol: "safari.fill", title: "extensionSettings.test", trailing: .external)
                }
                .buttonStyle(.plain)
                if !allowed {
                    Button {
                        troubleshooting = true
                    } label: {
                        SettingsRow(symbol: "questionmark.circle.fill", title: "extensionSettings.troubleshoot")
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("extensionSettings.testHint")
            }
        }
        .navigationTitle("settings.extension")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $troubleshooting) { TroubleshootSheet() }
    }

    private func openSettingsRow(detail: Text?) -> some View {
        Button {
            Task { await state.openSafariExtensionPreferences() }
        } label: {
            SettingsRow(symbol: "gearshape.fill", title: "extensionSettings.open",
                        detail: detail, trailing: .external)
        }
        .buttonStyle(.plain)
    }

    /// On / Off (nothing while the first check is still running).
    private var extensionStatusText: LocalizedStringKey? {
        switch state.status {
        case .enabled: "settings.extension.on"
        case .disabled, .error: "settings.extension.off"
        case .unknown: nil
        }
    }
}
