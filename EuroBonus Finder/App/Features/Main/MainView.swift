import SwiftUI

// The main view — where the app lands after Setup, and the root of the
// navigation stack. A standard iOS inset-grouped settings list:
// native surfaces and tint, plain SF Symbol leading icons (no colored tiles).
// The Extension row drills into extension settings and shows a warning marker
// when the extension is off or lacks all-sites access.

struct MainView: View {
    let state: ExtensionState
    @AppStorage(SharedDefaultsKey.market, store: .shared) private var market = Market.se
    // Tutorial progress, mirrored from the extension (one key per `TutorialStep`).
    @AppStorage(SharedDefaultsKey.tutorialProgress(.seenBadge), store: .shared) private var seenBadge = false
    @AppStorage(SharedDefaultsKey.tutorialProgress(.visitedPartner), store: .shared) private var visitedPartner = false
    @AppStorage(SharedDefaultsKey.tutorialProgress(.sasShoppingReturn), store: .shared) private var sasShoppingReturn = false

    var body: some View {
        List {
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

            Section {
                NavigationLink(value: Route.extensionSettings) {
                    SettingsRow(symbol: "puzzlepiece.extension.fill", title: "settings.extension",
                                warning: state.needsAttention)
                }

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
            }

            Section {
                Link(destination: URL(string: "mailto:support+ebfinder@pompa.se")!) {
                    SettingsRow(symbol: "envelope.fill", title: "settings.contact",
                                detail: Text(verbatim: "support@pompa.se"), trailing: .external)
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.about) {
                    SettingsRow(symbol: "info.circle.fill", title: "settings.about")
                }
            }

            Section {
                CreditCard()
            }
        }
        .navigationTitle(Text(verbatim: appName))
    }
}

/// "Made by Ronald Pompa" with social links — the last card on the main view.
private struct CreditCard: View {
    private let links: [(image: String, label: String, url: URL)] = [
        ("Social-github", "GitHub", URL(string: "https://link.pompa.se/gh")!),
        ("Social-x", "X", URL(string: "https://link.pompa.se/x")!),
        ("Social-linkedin", "LinkedIn", URL(string: "https://link.pompa.se/ln")!),
    ]

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("settings.madeBy")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(verbatim: "Ronald Pompa")
                    .font(.headline)
            }
            Spacer(minLength: 8)
            ForEach(links, id: \.url) { link in
                Link(destination: link.url) {
                    Image(link.image)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color(.tertiarySystemFill), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: link.label))
            }
        }
        .padding(.vertical, 4)
    }
}
