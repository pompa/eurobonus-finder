import Foundation

/// Progress through onboarding, persisted under `storageKey`. `incomplete`
/// means the user skipped extension setup; they can finish it from the main view.
enum OnboardingState: String {
    case active, completed, incomplete

    static let storageKey = "onboardingState"

    /// Carries users over from the old `hasCompletedOnboarding` flag.
    static func migrateLegacyFlag(in defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: storageKey) == nil,
              defaults.bool(forKey: "hasCompletedOnboarding") else { return }
        defaults.set(completed.rawValue, forKey: storageKey)
    }
}
