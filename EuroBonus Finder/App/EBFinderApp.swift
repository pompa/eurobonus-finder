import SwiftUI

let extensionBundleIdentifier = Bundle.main.bundleIdentifier! + ".extension"

/// The app's display name. Keep in sync with `INFOPLIST_KEY_CFBundleDisplayName` in project.yml.
let appName = "EuroBonus Finder"

@main
struct EBFinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
