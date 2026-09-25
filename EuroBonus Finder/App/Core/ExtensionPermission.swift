import SwiftUI

/// The website access Safari grants the extension, explained on the onboarding
/// setup step. Mirrors `content_scripts` in manifest.json.
enum ExtensionPermission: CaseIterable, Identifiable {
    case allWebsites

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .allWebsites: "permissions.allWebsites.title"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .allWebsites: "permissions.allWebsites.detail"
        }
    }
}
