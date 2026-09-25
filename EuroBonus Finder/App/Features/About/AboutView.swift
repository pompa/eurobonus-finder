import SwiftUI

/// About — version, source, license and disclaimer, plus Reset settings.
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

            Section {
                // Setup takes over once `setupState` is cleared (see ContentView).
                Button("about.reset", role: .destructive) { withAnimation(.snappy) { Reset.perform() } }
            }
        }
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

