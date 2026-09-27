import SwiftUI

/// Screens on the main navigation stack. Every route can also be opened by a
/// deep link, `$(APP_URL_SCHEME)://<host>` (the scheme is a build setting).
enum Route: Hashable {
    case extensionSettings
    case about
    #if DEBUG
    case debug
    #endif

    /// The Setup screen a `setup/<screen>` deep link opens (the Test page links
    /// back to `setup/verify`), or nil for any other link.
    static func setupScreen(for url: URL) -> SetupScreen? {
        guard url.host() == "setup" else { return nil }
        return SetupScreen(rawValue: url.lastPathComponent)
    }

    /// The stack a deep link opens, or nil for an unknown link.
    static func path(for url: URL) -> [Route]? {
        switch url.host() {
        case "extension": [.extensionSettings]
        case "about": [.about]
        #if DEBUG
        case "debug": [.about, .debug]
        #endif
        default: nil
        }
    }
}


/// The Setup screens a deep link can open; `done` is the finish screen.
enum SetupScreen: String {
    case welcome, region, `extension`, verify, done
}

/// A Setup deep link as received: `seq` makes the same screen linked twice
/// count as two arrivals, so a second tap on the Test page still jumps.
struct SetupLink: Equatable {
    let screen: SetupScreen
    let seq: Int
}
