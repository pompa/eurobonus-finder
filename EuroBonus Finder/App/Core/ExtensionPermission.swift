import SwiftUI

/// The website access Safari grants the extension, explained on the onboarding
/// permissions step. Mirrors `host_permissions` + `content_scripts` in manifest.json.
enum ExtensionPermission: CaseIterable, Identifiable {
    case allWebsites, feed

    var id: Self { self }

    var title: Text {
        switch self {
        case .allWebsites: Text("permissions.allWebsites.title")
        // The feed host is a build setting (FEED_HOST), not committed copy.
        case .feed: Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "EBFeedHost") as? String ?? "")
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .allWebsites: "permissions.allWebsites.detail"
        case .feed: "permissions.feed.detail"
        }
    }
}
