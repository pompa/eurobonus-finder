import Foundation

// Compiled into both the app and the extension: the App Group they share and
// what they keep in it. Each key holds one JSON object (a Codable struct
// below), so a Reset, the Debug listing and the extension's mirror all deal
// with four values instead of a bunch of stray keys.

/// Stamped into both Info.plists from $(APP_BUNDLE_ID) at build time — the appex
/// can't derive the container app's id from its own.
nonisolated let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as! String

enum SharedDefaultsKey {
    /// `Setup`: Setup progress and the chosen market.
    static let setup = "setup"
    /// `Permissions`: Safari's grants as the extension last reported them.
    static let permissions = "permissions"
    /// The extension's `tutorial` object as JSON: an epoch-ms stamp per step
    /// (badgeTapped, activateTapped, returned, finished, dismissed). Written by
    /// the extension, only read here.
    static let tutorial = "tutorial"
    /// `ResetStamps`: when the app last reset, so the extension can follow.
    static let reset = "reset"
}

/// Setup progress and the market chosen in it (changeable later in Settings).
/// Absent (e.g. after a Reset) means Setup is active and no market chosen.
struct Setup: Codable, Equatable {
    var state: SetupState = .active
    var market: Market?

    /// The market to use: `.se` until one is chosen (pre-market users were Swedish).
    var chosenMarket: Market {
        get { market ?? .se }
        set { market = newValue }
    }
}

/// Safari's grants, as reported by the extension's ping on each page load.
struct Permissions: Codable, Equatable {
    var hasAllUrls = false
    var origin = ""
    /// Epoch seconds of the ping.
    var pingedAt: Double
}

/// Epoch ms of the app's last Reset and last Tutorial reset. The extension
/// keeps its own copies and wipes itself / its progress when they differ —
/// the app only writes these, the extension only reads them.
struct ResetStamps: Codable, Equatable {
    var at: Int?
    var tutorialAt: Int?
}

enum Tutorial {
    /// Whether the mirrored `tutorial` JSON says the Tutorial is over: finished, or dismissed with Skip tour.
    static func isOver(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return dict["finished"] != nil || dict["dismissed"] != nil
    }
}

extension UserDefaults {
    /// The App Group suite shared by the app and the extension.
    /// `UserDefaults` is documented thread-safe, it just isn't marked `Sendable`.
    nonisolated(unsafe) static let shared = UserDefaults(suiteName: appGroupID)!

    /// The JSON object under `key`, or nil when absent or unreadable.
    func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let json = string(forKey: key), let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Stores `value` as a JSON string under `key` (sorted keys, so the Debug listing is stable).
    func encode<T: Encodable>(_ value: T, forKey key: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(value) else { return }
        set(String(decoding: data, as: UTF8.self), forKey: key)
    }

    /// Reads, mutates and writes back the JSON object under `key` (`fallback` when absent).
    func update<T: Codable>(_ key: String, fallback: T, _ mutate: (inout T) -> Void) {
        var value = decode(T.self, forKey: key) ?? fallback
        mutate(&value)
        encode(value, forKey: key)
    }

    static var nowMs: Int { Int(Date().timeIntervalSince1970 * 1000) }

    /// The App Group half of a Reset: wipes it and stamps `reset.at` (epoch ms), which
    /// it returns. Key by key rather than `removePersistentDomain`, so `@AppStorage` observers fire.
    @discardableResult
    static func resetShared() -> Int {
        shared.persistentDomain(forName: appGroupID)?.keys.forEach(shared.removeObject)
        let at = nowMs
        shared.encode(ResetStamps(at: at), forKey: SharedDefaultsKey.reset)
        return at
    }

    /// Tutorial-only Reset, same mechanism: clears the mirrored progress and stamps
    /// `reset.tutorialAt`, so the extension clears its own copy next run.
    static func resetTutorial() {
        shared.removeObject(forKey: SharedDefaultsKey.tutorial)
        shared.update(SharedDefaultsKey.reset, fallback: ResetStamps()) { $0.tutorialAt = nowMs }
    }
}
