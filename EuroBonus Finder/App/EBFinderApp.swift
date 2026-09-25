import SwiftUI

let extensionBundleIdentifier = Bundle.main.bundleIdentifier! + ".extension"

@main
struct EBFinderApp: App {
    init() {
        OnboardingState.migrateLegacyFlag()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
