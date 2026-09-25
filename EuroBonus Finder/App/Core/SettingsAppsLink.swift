import SwiftUI

extension View {
    /// Routes Markdown links in this view to Settings › Apps (the rate-limit fallback).
    func opensSettingsApps() -> some View {
        environment(\.openURL, OpenURLAction { _ in .systemAction(ExtensionState.settingsAppsURL) })
    }
}
