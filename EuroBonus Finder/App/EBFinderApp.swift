import SwiftUI

// Sunset build for the old TestFlight: one screen that sends testers to the
// launched app and the new TestFlight, both linked from the website.

let siteURL = URL(string: "https://eurobonus.pompa.se/")!

@main
struct EBFinderApp: App {
    init() {
        // Wipe what the old build stored: the App Group it shared with the
        // extension, and the app's own defaults.
        let bundleID = Bundle.main.bundleIdentifier!
        let group = "group." + bundleID
        UserDefaults(suiteName: group)?.removePersistentDomain(forName: group)
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
    }

    var body: some Scene {
        WindowGroup {
            SunsetView()
        }
    }
}

struct SunsetView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            EBAppIcon(size: 96, float: true)
            VStack(spacing: 12) {
                Text("sunset.title").brandTitle(BrandPalette.ink)
                Text("sunset.body").brandBody(BrandPalette.sub)
            }
            .multilineTextAlignment(.center)
            Spacer()
            SetupButton(title: "sunset.cta", trailingIcon: "arrow.up.right", shimmer: true) {
                openURL(siteURL)
            }
            Text("sunset.delete")
                .font(.footnote)
                .foregroundStyle(BrandPalette.sub)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandBackground())
    }
}

#Preview {
    SunsetView()
}
