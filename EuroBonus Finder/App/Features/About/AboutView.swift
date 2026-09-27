import SwiftUI

/// About — the app card (what it is, who made it), version, website, source
/// and the disclaimer page.
struct AboutView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                AppCard()
            }

            Section {
                SettingsRow(title: "about.version", detail: Text(verbatim: appVersion))
                Link(destination: URL(string: "https://eurobonus.pompa.se/")!) {
                    SettingsRow(title: "about.website", trailing: .external)
                }
                .buttonStyle(.plain)
                Link(destination: URL(string: "https://github.com/pompa/eurobonus-finder")!) {
                    SettingsRow(title: "about.source", trailing: .external)
                }
                .buttonStyle(.plain)
                Link(destination: URL(string: "https://eurobonus.pompa.se/disclaimer/")!) {
                    SettingsRow(title: "about.disclaimer", trailing: .external)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The app's icon, name, what it does and who made it — laid out like the
/// General card at the top of iOS Settings › General.
private struct AppCard: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("EBIcon")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.225, style: .continuous))
                .padding(.bottom, 8)
            Text(verbatim: appName)
                .font(.title2.weight(.bold))
            Text("about.card.subtitle")
                .foregroundStyle(.secondary)
            // The name is a Markdown link (ronald.pompa.se) in the localized string.
            Text("about.card.developedBy")
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 8)
    }
}
