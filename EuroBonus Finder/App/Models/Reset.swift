import Foundation

/// Reset: wipes everything the app stores and stamps `lastResetAt` so the
/// extension wipes its own storage the next time it runs. Setup restarts because
/// `setupState` is gone. Keeps only the settings rate limit, which iOS still enforces.
enum Reset {
    static func perform() {
        UserDefaults.resetShared()

        let standard = UserDefaults.standard
        let rateLimit = standard.object(forKey: ExtensionState.rateLimitedUntilKey)
        standard.persistentDomain(forName: Bundle.main.bundleIdentifier!)?.keys.forEach(standard.removeObject)
        standard.set(rateLimit, forKey: ExtensionState.rateLimitedUntilKey)
    }
}
