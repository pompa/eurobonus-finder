import Foundation

/// The Test page: the page on eurobonus.pompa.se that Setup opens in Safari to
/// confirm the extension runs on every website. The app's language picks the
/// translation (the site has English and Swedish).
enum TestPage {
    private static var language: String { Bundle.main.preferredLocalizations.first ?? "en" }

    /// With `setup`, `#ebfSetup` makes the extension show its banner there and
    /// re-report its grants even when they haven't changed.
    static func url(setup: Bool) -> URL {
        let path = language == "sv" ? "/sv/test-extension/" : "/test-extension/"
        return URL(string: "https://eurobonus.pompa.se\(path)\(setup ? "#ebfSetup" : "")")!
    }

    /// Apple's "Get extensions to customize Safari on iPhone", in the app's
    /// language. The region is Apple's URL convention, not the user's market.
    static var appleSupportURL: URL {
        let locale = switch language {
        case "sv": "sv-se"
        case "da": "da-dk"
        case "nb": "no-no"
        case "fi": "fi-fi"
        default: "en-us"
        }
        return URL(string: "https://support.apple.com/\(locale)/102343")!
    }

    static let supportEmail = URL(string: "mailto:support+ebfinder@pompa.se")!
}
