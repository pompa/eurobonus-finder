import SwiftUI

// Post-onboarding home — a standard iOS inset-grouped settings list. Native
// surfaces and tint; plain SF Symbol leading icons (no colored tiles). Row
// titles are primary (only the footer link and the system back/links take the
// blue tint). Root → Om (About). A warning marker appears on
// Extension Settings when the extension is off or lacks all-sites access.

struct SettingsView: View {
    let state: ExtensionState
    @Environment(\.openURL) private var openURL
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("guidedTestNonce") private var guidedTestNonce = 0
    @AppStorage(SharedDefaultsKey.market, store: Market.store) private var market = Market.se

    var body: some View {
        NavigationStack {
            List {
                // Guided "try it out" test — runs the badge + banner tour in Safari.
                Section {
                    GuidedTestCard(disabled: extensionNeedsAttention, action: startGuidedTest)

                    Button {
                        withAnimation(.snappy) { hasCompletedOnboarding = false }
                    } label: {
                        SettingsRow(symbol: "arrow.counterclockwise", title: "settings.resetOnboarding")
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    Button {
                        Task { await state.openSafariExtensionPreferences() }
                    } label: {
                        SettingsRow(symbol: "puzzlepiece.extension.fill", title: "settings.extension",
                                    detail: extensionStatusText.map { Text($0) },
                                    warning: extensionNeedsAttention, trailing: .chevron)
                    }
                    .buttonStyle(.plain)

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
                    Button {
                        openURL(URL(string: "mailto:support+ebfinder@pompa.se")!)
                    } label: {
                        SettingsRow(symbol: "envelope.fill", title: "settings.contact",
                                    detail: Text(verbatim: "support@pompa.se"), trailing: .external)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AboutView()
                    } label: {
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
        .tint(.blue)
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

    /// The extension is installed but not fully usable: switched off, errored,
    /// or enabled without all-websites access. `.unknown` (still loading) stays
    /// quiet so we never flash a false warning on launch.
    private var extensionNeedsAttention: Bool {
        switch state.status {
        case .disabled, .error: return true
        case .enabled: return state.hostPermission == .someWebsites
        case .unknown: return false
        }
    }

    /// On / Off value shown on the Extension row (nil while still loading).
    private var extensionStatusText: LocalizedStringKey? {
        switch state.status {
        case .enabled: return "settings.extension.on"
        case .disabled, .error: return "settings.extension.off"
        case .unknown: return nil
        }
    }
}

// MARK: - About

private struct AboutView: View {
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                SettingsRow(title: "about.version", detail: Text(verbatim: appVersion))
            }

            Section {
                Button {
                    openURL(URL(string: "https://github.com/pompa/eurobonus-finder")!)
                } label: {
                    SettingsRow(title: "about.source", trailing: .external)
                }
                .buttonStyle(.plain)
                Button {
                    openURL(URL(string: "https://github.com/pompa/eurobonus-finder/blob/main/LICENSE")!)
                } label: {
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

// MARK: - Building blocks

private struct SettingsRow: View {    var symbol: String? = nil
    let title: LocalizedStringKey
    var detail: Text? = nil
    var warning: Bool = false
    var trailing: Trailing = .none

    enum Trailing { case none, chevron, external }

    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .center)
            }
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let detail {
                detail.foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            if warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.warning)
                    .accessibilityLabel(Text("settings.extension.warning"))
            }
            trailingIcon
        }
        // Plain-style buttons only hit-test drawn content; make the Spacer tappable too.
        .contentShape(.rect)
    }

    @ViewBuilder
    private var trailingIcon: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        case .external:
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

/// "Made by Ronald Pompa" with social links — the last card on the settings root.
private struct CreditCard: View {
    @Environment(\.openURL) private var openURL

    private let links: [(image: String, label: String, url: String)] = [
        ("Social-github", "GitHub", "https://link.pompa.se/gh"),
        ("Social-x", "X", "https://link.pompa.se/x"),
        ("Social-linkedin", "LinkedIn", "https://link.pompa.se/ln"),
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
                Button {
                    openURL(URL(string: link.url)!)
                } label: {
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

/// The "try it out" card at the top of settings — a 2-step guided test the user
/// runs in Safari. Step 1 (the button) opens a Swedish Google search; the
/// extension then coaches the EB badge and, on the partner site, the banner.
/// Disabled until the extension is on with all-sites access, otherwise the
/// content script never runs and nothing would happen.
private struct GuidedTestCard: View {    let disabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
                Text("settings.guidedTest.title")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 9) {
                GuidedTestStepRow(index: 1, title: "settings.guidedTest.step1")
                GuidedTestStepRow(index: 2, title: "settings.guidedTest.step2")
            }

            SButton("settings.guidedTest.button", systemImage: "magnifyingglass",
                    variant: .primary, size: .md, fullWidth: true, action: action)
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

/// A single numbered step in the guided-test card (indigo disc + label).
private struct GuidedTestStepRow: View {    let index: Int
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(index)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.primaryForeground)
                .frame(width: 22, height: 22)
                .background(Theme.Colors.primary, in: .circle)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
