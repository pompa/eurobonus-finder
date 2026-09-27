import Foundation

/// Progress through Setup, persisted in the App Group under
/// `SharedDefaultsKey.setupState`. `incomplete` means the user skipped extension
/// setup; they can finish it from the main view. Absent (e.g. after a Reset) means `active`.
enum SetupState: String, CaseIterable {
    case active, completed, incomplete
}
