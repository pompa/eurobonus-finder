import SwiftUI

// The main view — where the app lands after onboarding, and the root of the
// navigation stack. A standard iOS inset-grouped settings list:
// native surfaces and tint, plain SF Symbol leading icons (no colored tiles).
// The Extension row drills into extension settings and shows a warning marker
// when the extension is off or lacks all-sites access.

struct MainView: View {
    let state: ExtensionState
    /// Sends the user back through onboarding; `ContentView` owns that state.
    let onResetOnboarding: () -> Void
    @Environment(\.openURL) private var openURL
    @AppStorage("guidedTestNonce") private var guidedTestNonce = 0
    @AppStorage(SharedDefaultsKey.market, store: Market.store) private var market = Market.se

    var body: some View {
        List {
            // Guided "try it out" test — runs the badge + banner tour in Safari.
            Section {
                GuidedTestCard(disabled: state.needsAttention, action: startGuidedTest)

                Button(action: onResetOnboarding) {
                    SettingsRow(symbol: "arrow.counterclockwise", title: "settings.resetOnboarding")
                }
                .buttonStyle(.plain)
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Kick off the guided test: bump the shared nonce the content script polls
    /// for, then open a Google search in Safari for the user's market (`gl` searches
    /// as if from that country — market codes double as Google's ccTLDs — `hl` is the
    /// app's UI language; the partner-name terms bias the shopping results toward
    /// EuroBonus partners so a badge reliably appears).
    private func startGuidedTest() {
        // Carry a fresh, monotonic nonce in the URL fragment (#ebf=…). The content
        // script reads it synchronously on the results page to start the tour; a
        // new value each run is what lets the test be re-run.
        guidedTestNonce += 1
        var components = URLComponents(string: "https://www.google.\(market.rawValue)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "apple studio display xdr webhallen komplett proshop"),
            URLQueryItem(name: "hl", value: Bundle.main.preferredLocalizations.first ?? "en"),
            URLQueryItem(name: "gl", value: market.rawValue),
        ]
        components.fragment = "ebf=\(guidedTestNonce)"
        if let url = components.url { openURL(url) }
    }
}

// MARK: - About

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                SettingsRow(title: "about.version", detail: Text(verbatim: appVersion))
            }

            Section {
                Link(destination: URL(string: "https://github.com/pompa/eurobonus-finder")!) {
                    SettingsRow(title: "about.source", trailing: .external)
                }
                .buttonStyle(.plain)
                Link(destination: URL(string: "https://github.com/pompa/eurobonus-finder/blob/main/LICENSE")!) {
                    SettingsRow(title: "about.license", detail: Text(verbatim: "MIT"), trailing: .external)
                }
                .buttonStyle(.plain)
            }

            Section {
                Text("about.disclaimer.body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text("about.disclaimer.header")
            }
        }
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.large)
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

// MARK: - Guided test card

/// The "try it out" card at the top of the main view — a 2-step guided test the user
/// runs in Safari. Step 1 (the button) opens a Google search for the user's market; the
/// extension then coaches the EB badge and, on the partner site, the banner.
/// Disabled until the extension is on with all-sites access, otherwise the
/// content script never runs and nothing would happen.
private struct GuidedTestCard: View {
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primary)
                Text("settings.guidedTest.title")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 9) {
                GuidedTestStepRow(index: 1, title: "settings.guidedTest.step1")
                GuidedTestStepRow(index: 2, title: "settings.guidedTest.step2")
            }

            SButton("settings.guidedTest.button", systemImage: "magnifyingglass", action: action)
                .disabled(disabled)

            Text(disabled ? "settings.guidedTest.disabledHint" : "settings.guidedTest.caption")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
    }
}

/// A single numbered step in the guided-test card (numbered disc + label).
private struct GuidedTestStepRow: View {
    let index: Int
    let title: LocalizedStringKey
    @ScaledMetric(relativeTo: .footnote) private var discSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(index)")
                .font(.footnote.bold())
                .foregroundStyle(Theme.Colors.primaryForeground)
                .frame(width: discSize, height: discSize)
                .background(Theme.Colors.primary, in: .circle)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
