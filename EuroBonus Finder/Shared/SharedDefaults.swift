import Foundation

// Compiled into both the app and the extension: the App Group they share and
// what they keep in it. Three keys, each one JSON object with one writer:
//
//   setup        app                — market, when Setup finished, reset stamps
//   permissions  extension handler  — Safari's grants as last pinged
//   tutorial     extension          — Tutorial progress (mirrored from storage.local)
//
// Nothing else is stored. Whether the extension is on and allowed everywhere is
// not state: the app derives it live (ExtensionState) from Safari and the ping.

/// Stamped into both Info.plists from $(APP_BUNDLE_ID) at build time — the appex
/// can't derive the container app's id from its own.
nonisolated let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as! String

enum SharedDefaultsKey {
    static let setup = "setup"
    static let permissions = "permissions"
    static let tutorial = "tutorial"
}

/// Epoch milliseconds, the stamp format shared with the extension's JS.
func epochMs() -> Int { Int(Date().timeIntervalSince1970 * 1000) }

/// What the app decided: the market, and when Setup was finished (nil shows
/// Setup; clearing it runs Setup again). The reset stamps tell the extension
/// to wipe itself (`resetAt`) or its Tutorial progress (`tutorialResetAt`);
/// it keeps its own copies and acts when they differ.
struct Setup: Codable, Equatable {
    var market: Market?
    var finishedAt: Int?
    var resetAt: Int?
    var tutorialResetAt: Int?

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
    var pingedAt: Double = 0
}

/// The app's read of the extension's `tutorial` object: only the two stamps
/// that end it matter here (see background.js for the rest).
struct TutorialProgress: Codable, Equatable {
    var finished: Int?
    var dismissed: Int?

    /// Finished, or dismissed with Skip tour.
    var isOver: Bool { finished != nil || dismissed != nil }
}

/// One JSON object as a string — the App Group value format.
enum JSONText {
    static func decode<T: Decodable>(_ type: T.Type, from json: String) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Sorted keys, so the Debug listing and the extension's mirror are stable.
    static func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
}

extension UserDefaults {
    /// The App Group suite shared by the app and the extension.
    /// `UserDefaults` is documented thread-safe, it just isn't marked `Sendable`.
    nonisolated(unsafe) static let shared = UserDefaults(suiteName: appGroupID)!

    func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        string(forKey: key).flatMap { JSONText.decode(type, from: $0) }
    }

    func encode<T: Encodable>(_ value: T, forKey key: String) {
        set(JSONText.encode(value), forKey: key)
    }

    /// Reads, mutates and writes back the object under `key` (`fallback` when absent).
    func update<T: Codable>(_ key: String, fallback: T, _ mutate: (inout T) -> Void) {
        var value = decode(T.self, forKey: key) ?? fallback
        mutate(&value)
        encode(value, forKey: key)
    }

    /// The App Group half of a Reset: wipes it and stamps `setup.resetAt`, which it
    /// returns. Key by key rather than `removePersistentDomain`, so `@AppStorage` observers fire.
    @discardableResult
    static func resetShared() -> Int {
        shared.persistentDomain(forName: appGroupID)?.keys.forEach(shared.removeObject)
        let at = epochMs()
        shared.encode(Setup(resetAt: at), forKey: SharedDefaultsKey.setup)
        return at
    }

    /// Tutorial-only Reset, same mechanism: clears the mirrored progress and stamps
    /// `setup.tutorialResetAt`, so the extension clears its own copy next run.
    static func resetTutorial() {
        shared.removeObject(forKey: SharedDefaultsKey.tutorial)
        shared.update(SharedDefaultsKey.setup, fallback: Setup()) { $0.tutorialResetAt = epochMs() }
    }
}
