import SwiftUI

// Extension settings — reached from the main view's Safari Extension row and
// the `…://extension` deep link. Same inset-grouped style as the main view: the
// live status of the extension and its website access, plus a link into
// Safari's settings for it (rate-limited by iOS; see `ExtensionState`).

struct ExtensionSettingsView: View {
    let state: ExtensionState

    var body: some View {
        List {
            // Hints show until each value is known and set properly.
            Section {
                SettingsRow(symbol: "puzzlepiece.extension.fill", title: "settings.extension",
                            detail: extensionStatusText.map { Text($0) })
            } footer: {
                if let error = state.errorMessage {
                    Text(verbatim: error)
                } else if state.status != .enabled {
                    Text("extensionSettings.extensionHint")
                }
            }

            ForEach(ExtensionPermission.allCases) { permission in
                // Safari only reveals Allow; Ask and Deny look identical to the
                // extension, so anything else is unknown and shown as a warning.
                let allowed = state.isGranted(permission) == true
                Section {
                    SettingsRow(symbol: "network", title: permission.title,
                                detail: allowed ? Text("extensionSettings.permission.allow") : nil,
                                warning: !allowed)
                } footer: {
                    if !allowed {
                        Text("extensionSettings.permissionHint")
                    }
                }
            }

            Section {
                if state.isRateLimited {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        openSettingsRow(detail: Text(verbatim: state.settingsCountdown(at: context.date)).monospacedDigit())
                            .disabled(true)
                    }
                } else {
                    openSettingsRow(detail: nil)
                }
            } footer: {
                if state.isRateLimited {
                    Text("extension.settingsPath")
                        .opensSettingsApps()
                }
            }
        }
        .navigationTitle("settings.extension")
        .navigationBarTitleDisplayMode(.large)
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
