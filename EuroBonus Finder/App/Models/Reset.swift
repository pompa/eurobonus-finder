import Foundation

/// Reset: wipes everything the app stores and stamps `setup.resetAt` so the
/// extension wipes its own storage the next time it runs. Setup shows again
/// because `setup.finishedAt` is gone. Keeps only the settings rate limit, which iOS still enforces.
enum Reset {
    static func perform() {
        UserDefaults.resetShared()

        let standard = UserDefaults.standard
        let rateLimit = standard.object(forKey: ExtensionState.rateLimitedUntilKey)
        standard.persistentDomain(forName: Bundle.main.bundleIdentifier!)?.keys.forEach(standard.removeObject)
        standard.set(rateLimit, forKey: ExtensionState.rateLimitedUntilKey)
    }
}
