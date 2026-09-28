import Foundation

// Compiled into both the app and the extension: the App Group they share and
// the keys they read and write in it. Keys match the extension's JS names.

/// Stamped into both Info.plists from $(APP_BUNDLE_ID) at build time — the appex
/// can't derive the container app's id from its own.
nonisolated let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as! String

extension UserDefaults {
    /// The App Group suite shared by the app and the extension.
    /// `UserDefaults` is documented thread-safe, it just isn't marked `Sendable`.
    nonisolated(unsafe) static let shared = UserDefaults(suiteName: appGroupID)!

    /// The App Group half of a Reset: wipes it and stamps `lastResetAt` (epoch ms), which
    /// it returns. Key by key rather than `removePersistentDomain`, so `@AppStorage` observers fire.
    @discardableResult
    static func resetShared() -> Int {
        shared.persistentDomain(forName: appGroupID)?.keys.forEach(shared.removeObject)
        let lastResetAt = Int(Date().timeIntervalSince1970 * 1000)
        shared.set(lastResetAt, forKey: SharedDefaultsKey.lastResetAt)
        return lastResetAt
    }

    /// Tutorial-only Reset, same mechanism: clears the mirrored progress and stamps
    /// `lastTutorialResetAt` (epoch ms), so the extension clears its own copy next run.
    static func resetTutorial() {
        TutorialStep.allCases.forEach { shared.removeObject(forKey: SharedDefaultsKey.tutorialProgress($0)) }
        shared.set(Int(Date().timeIntervalSince1970 * 1000), forKey: SharedDefaultsKey.lastTutorialResetAt)
    }
}

enum SharedDefaultsKey {
    static let setupState = "setupState"
    static let market = "market"
    /// Epoch ms of the last Reset. The extension keeps its own copy and wipes
    /// itself when the two differ — the app only writes it, the extension only reads it.
    static let lastResetAt = "lastResetAt"
    /// Epoch ms of the last Tutorial Reset (the Tutorial card starting a search); read like `lastResetAt`.
    static let lastTutorialResetAt = "lastTutorialResetAt"
    static let permissionPingTimestamp = "permission.lastPingTimestamp"
    static let permissionHasAllUrls = "permission.hasAllUrls"
    static let permissionLastOrigin = "permission.lastOrigin"

    /// One Bool per step, mirrored from the extension's `tutorialProgress`.
    static func tutorialProgress(_ step: TutorialStep) -> String {
        "tutorialProgress.\(step.rawValue)"
    }
}

/// The things the Tutorial teaches, completed in any order.
enum TutorialStep: String, CaseIterable {
    case seenBadge, visitedPartner, sasShoppingReturn
}
