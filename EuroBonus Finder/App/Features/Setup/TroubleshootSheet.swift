import SwiftUI

/// What to do when the Test page didn't see the extension: the Safari settings
/// path, the prompt Safari shows on a page, and where to read or ask for more.
/// Presented from the verify step and from extension settings.
struct TroubleshootSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    step(1, "troubleshoot.step1")
                    step(2, "troubleshoot.step2")
                    step(3, "troubleshoot.step3")
                } footer: {
                    Text("troubleshoot.footer")
                }

                Section {
                    link(TestPage.url(setup: false), symbol: "book.fill", title: "troubleshoot.guide")
                    link(TestPage.appleSupportURL, symbol: "questionmark.circle.fill", title: "troubleshoot.apple")
                    link(TestPage.supportEmail, symbol: "envelope.fill", title: "troubleshoot.contact")
                }
            }
            .navigationTitle("troubleshoot.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("troubleshoot.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "\(number).circle.fill")
                .foregroundStyle(.tint)
        }
    }

    private func link(_ url: URL, symbol: String, title: LocalizedStringKey) -> some View {
        Link(destination: url) {
            SettingsRow(symbol: symbol, title: title, trailing: .external)
        }
        .buttonStyle(.plain)
    }
}
