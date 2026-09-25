import SwiftUI

/// Screens on the main navigation stack. Every route can also be opened by a
/// deep link, `$(APP_URL_SCHEME)://<host>` (the scheme is a build setting).
enum Route: Hashable {
    case extensionSettings
    case about

    /// The stack a deep link opens, or nil for an unknown link.
    static func path(for url: URL) -> [Route]? {
        switch url.host() {
        case "extension": [.extensionSettings]
        case "about": [.about]
        default: nil
        }
    }
}

