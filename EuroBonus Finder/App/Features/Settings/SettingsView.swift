import SwiftUI

/// Settings — region and language, Debug (Debug builds only), and Reset settings.
struct SettingsView: View {
    @AppStorage(SharedDefaultsKey.market, store: .shared) private var market = Market.se

    /// The app's active UI language, named in itself ("Svenska").
    private var languageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: code).localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }

    var body: some View {
        List {
            Section {
                // Only the value opens the menu, so pressing it doesn't highlight the whole row.
                HStack {
                    SettingsRow(symbol: "globe", title: "settings.region")
                    Menu {
                        Picker(selection: $market) {
                            ForEach(Market.allCases) { Text(verbatim: $0.name).tag($0) }
                        } label: {
                            EmptyView()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(verbatim: market.name)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    // Menu labels take the list's blue tint; keep the value neutral like its siblings.
                    .tint(.primary)
                }

                // The extension takes its language from Safari, which the app can't override,
                // so the app doesn't either: iOS lists a Language row on the app's Settings page.
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    SettingsRow(symbol: "character.bubble.fill", title: "settings.language",
                                detail: Text(verbatim: languageName), trailing: .external)
                }
                .buttonStyle(.plain)
            }

            #if DEBUG
            Section {
                NavigationLink(value: Route.debug) {
                    SettingsRow(symbol: "ladybug.fill", title: "about.debug")
                }
            }
            #endif

            Section {
                // Setup takes over once `setupState` is cleared (see ContentView).
                Button("about.reset", role: .destructive) { withAnimation(.snappy) { Reset.perform() } }
            } footer: {
                Text("about.reset.hint")
            }
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
