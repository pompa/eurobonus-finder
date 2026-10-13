import SwiftUI

// The main view — where the app lands after Setup, and the root of the
// navigation stack. A standard iOS inset-grouped settings list: the Safari
// Extension row (the app icon as its tile, like iOS's own Extensions list,
// with a warning marker when the extension is off or lacks all-sites access),
// Settings, and a Support group.

struct MainView: View {
    let state: ExtensionState
    // Tutorial progress, mirrored from the extension.
    @SharedJSON(SharedDefaultsKey.tutorial, default: TutorialProgress()) private var tutorial

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

            // Gone once the Tutorial is finished or skipped; a Reset brings it back.
            if !tutorial.isOver {
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
