import SwiftUI

/// Starts the Tutorial: opens a Google search in Safari, where the extension takes
/// over with its Coachmarks. Disabled until the extension is on with all-sites
/// access, otherwise the content script never runs and nothing would happen.
struct TutorialCard: View {
    let disabled: Bool
    @Environment(\.openURL) private var openURL
    @AppStorage(SharedDefaultsKey.market, store: .shared) private var market = Market.se

    var body: some View {
        VStack(spacing: 14) {
            // Flat (not glass): a content button inside the list, like the
            // system's own "Browse Extensions".
            Button(action: start) {
                Label("tutorial.button", systemImage: "magnifyingglass")
                    .labelStyle(.titleAndIcon) // the list would otherwise drop the icon
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(disabled)

            Text(disabled ? "tutorial.disabledHint" : "tutorial.caption")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    /// Opens a Google search for the user's market (`gl` searches as if from that
    /// country — market codes double as Google's ccTLDs — `hl` is the app's UI
    /// language; the query matches the hint under the button). The `#ebfTutorial` fragment tells the
    /// content script this search came from here, so it can coach even when no Badge shows.
    /// Starts the Tutorial over: any earlier progress is cleared first (app and extension).
    private func start() {
        UserDefaults.resetTutorial()
        var components = URLComponents(string: "https://www.google.\(market.rawValue)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "Apple Display XDR"),
            URLQueryItem(name: "hl", value: Bundle.main.preferredLocalizations.first ?? "en"),
            URLQueryItem(name: "gl", value: market.rawValue),
        ]
        components.fragment = "ebfTutorial"
        if let url = components.url { openURL(url) }
    }
}
