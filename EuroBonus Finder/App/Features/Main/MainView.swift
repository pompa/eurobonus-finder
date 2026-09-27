import SwiftUI

// The main view — where the app lands after Setup, and the root of the
// navigation stack. A standard iOS inset-grouped settings list: the Safari
// Extension row (the app icon as its tile, like iOS's own Extensions list,
// with a warning marker when the extension is off or lacks all-sites access),
// Settings, and a Support group.

struct MainView: View {
    let state: ExtensionState
    // Tutorial progress, mirrored from the extension (one key per `TutorialStep`).
    @AppStorage(SharedDefaultsKey.tutorialProgress(.seenBadge), store: .shared) private var seenBadge = false
    @AppStorage(SharedDefaultsKey.tutorialProgress(.visitedPartner), store: .shared) private var visitedPartner = false
    @AppStorage(SharedDefaultsKey.tutorialProgress(.sasShoppingReturn), store: .shared) private var sasShoppingReturn = false

    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.extensionSettings) {
                    SettingsRow(image: "EBIcon", title: "settings.extension", warning: state.needsAttention)
                }
            }

            Section {
                NavigationLink(value: Route.settings) {
                    SettingsRow(symbol: "gearshape.fill", title: "settings.title")
                }
            }

            Section {
                Link(destination: URL(string: "mailto:support+ebfinder@pompa.se")!) {
                    SettingsRow(symbol: "envelope.fill", title: "settings.email",
                                detail: Text(verbatim: "support@pompa.se"), trailing: .external)
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.about) {
                    SettingsRow(symbol: "info.circle.fill", title: "settings.about")
                }
            } header: {
                Text("settings.support")
            }

            // Gone once every Tutorial step is done; a Reset brings it back.
            if !(seenBadge && visitedPartner && sasShoppingReturn) {
                Section {
                    // Standalone button: no inset-grouped card behind it.
                    TutorialCard(disabled: state.needsAttention)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text("tutorial.title")
                }
            }
        }
        .navigationTitle(Text(verbatim: appName))
    }
}
