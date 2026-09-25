import Foundation

/// The user's EuroBonus market — picks which partner feed the extension loads.
/// Independent of UI language. Stored in the App Group under
/// `SharedDefaultsKey.market`; absent means `.se` (pre-market users were Swedish).
enum Market: String, CaseIterable, Identifiable {
    case se, no, dk, fi

    var id: String { rawValue }

    /// Country name in the app's active UI language.
    var name: String {
        let locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        return locale.localizedString(forRegionCode: rawValue.uppercased()) ?? rawValue.uppercased()
    }

    /// The device region if it's a supported market, otherwise Sweden.
    static var deviceDefault: Market {
        Locale.current.region.flatMap { Market(rawValue: $0.identifier.lowercased()) } ?? .se
    }

    static let store = UserDefaults(suiteName: appGroupID)

    /// Stores the device region as the market unless one was already chosen.
    static func preselectDeviceDefault() {
        guard store?.string(forKey: SharedDefaultsKey.market) == nil else { return }
        store?.set(deviceDefault.rawValue, forKey: SharedDefaultsKey.market)
    }
}
