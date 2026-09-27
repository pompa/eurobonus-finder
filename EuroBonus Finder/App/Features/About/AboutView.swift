import SwiftUI

/// About — the app card (what it is, who made it; opens the website), version,
/// source and the disclaimer page.
struct AboutView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                Link(destination: URL(string: "https://eurobonus.pompa.se/")!) {
                    AppCard()
                }
                .buttonStyle(.plain)
            }

            Section {
                SettingsRow(title: "about.version", detail: Text(verbatim: appVersion))
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

/// The app's icon, name and a line on its purpose and author — laid out like
/// the account card at the top of iOS Settings.
private struct AppCard: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 60

    var body: some View {
        HStack(spacing: 14) {
            Image("EBIcon")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.225, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: appName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("about.card.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}
