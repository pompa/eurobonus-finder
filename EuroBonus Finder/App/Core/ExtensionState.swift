import SafariServices

let appGroupID = "group." + Bundle.main.bundleIdentifier!

enum SharedDefaultsKey {
    static let permissionPingTimestamp = "permission.lastPingTimestamp"
    static let permissionHasAllUrls = "permission.hasAllUrls"
    static let permissionLastOrigin = "permission.lastOrigin"
    static let market = "market"
}

enum ExtensionStatus: Equatable {
    case unknown
    case enabled
    case disabled
    case error(String)
}

enum HostPermission: Equatable {
    case unknown
    case allWebsites
    case someWebsites
}

@MainActor
@Observable
final class ExtensionState {
    var status: ExtensionStatus = .unknown
    var hostPermission: HostPermission = .unknown

    private(set) var rateLimitedUntil: Date?
    private var recentOpens: [Date] = []
    private static let rateLimitWindow: TimeInterval = 61
    /// App-only, so `.standard` like our `@AppStorage` keys — not the shared app-group suite.
    private static let rateLimitedUntilKey = "rateLimitedUntil"
    static let settingsAppsURL = URL(string: "App-Prefs:SAFARI")!

    init() {
        if let date = Self.savedRateLimit() {
            lock(until: date)
        }
    }

    /// Whether opening Safari's extension settings is currently blocked by iOS's rate limit.
    var isRateLimited: Bool {
        rateLimitedUntil != nil
    }

    func refresh() async {
        // The permission ping is a cheap synchronous read — pick it up immediately.
        hostPermission = readHostPermission()

        // The state check bridges into Safari and can't be cancelled, so apply
        // its result when it lands rather than blocking the UI on it…
        Task { @MainActor in
            let result = await self.checkExtensionState()
            self.status = result
            self.hostPermission = self.readHostPermission()
        }
        // …and if no check has landed shortly (a landed one is never `.unknown`),
        // fall back to the actionable setup step instead of hanging. A late result
        // still corrects it. Skipped when the caller is cancelled, e.g. on backgrounding.
        guard (try? await Task.sleep(for: .seconds(2.5))) != nil else { return }
        if status == .unknown { status = .disabled }
    }

    private func checkExtensionState() async -> ExtensionStatus {
        do {
            let state = try await SFSafariExtensionManager.stateOfExtension(
                withIdentifier: extensionBundleIdentifier
            )
            return state.isEnabled ? .enabled : .disabled
        } catch {
            return Self.classify(error)
        }
    }

    /// Safari failing to resolve the extension surfaces as a thrown `SFError`
    /// rather than `isEnabled == false`. Codes 1–4 (no extension / no
    /// attachment / loading interrupted / internal error) mean "not ready
    /// yet", so route them to the friendly enable step. Codes 5+ (e.g. missing
    /// entitlement) signal a real build/config bug and stay visible.
    private static func classify(_ error: Error) -> ExtensionStatus {
        let ns = error as NSError
        if ns.domain == "SFErrorDomain", (1...4).contains(ns.code) {
            return .disabled
        }
        return .error(error.localizedDescription)
    }

    /// Opens the extension's Safari settings; when iOS rate-limits it, the UI falls back to linking Settings › Apps.
    func openSafariExtensionPreferences() async {
        guard !isRateLimited else { return }
        let now = Date.now
        do {
            try await SFSafariSettings.openExtensionsSettings(forIdentifiers: [extensionBundleIdentifier])
            recordOpen(at: now)
        } catch let error as NSError where error.domain == "SFErrorDomain" && error.code == 6 {
            lock(until: now + Self.rateLimitWindow)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    /// iOS allows one open per window; a second one inside it means the next will be refused.
    private func recordOpen(at now: Date) {
        recentOpens = recentOpens.filter { now.timeIntervalSince($0) < Self.rateLimitWindow } + [now]
        if recentOpens.count >= 2 {
            lock(until: recentOpens[recentOpens.count - 2] + Self.rateLimitWindow)
        }
    }

    private func lock(until date: Date) {
        rateLimitedUntil = date
        Self.saveRateLimit(until: date)
        Task {
            try? await Task.sleep(for: .seconds(date.timeIntervalSinceNow))
            if rateLimitedUntil == date { rateLimitedUntil = nil }
        }
    }

    /// A lock saved by an earlier launch, if it hasn't expired yet.
    private static func savedRateLimit() -> Date? {
        guard let date = UserDefaults.standard.object(forKey: rateLimitedUntilKey) as? Date, date > .now else {
            return nil
        }
        return date
    }

    private static func saveRateLimit(until date: Date) {
        UserDefaults.standard.set(date, forKey: rateLimitedUntilKey)
    }

    /// Time left on the rate limit at `date`, formatted as a countdown (e.g. "0:42").
    func settingsCountdown(at date: Date) -> String {
        let seconds = max(0, Int((rateLimitedUntil ?? date).timeIntervalSince(date).rounded(.up)))
        return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    /// On, with access to all websites — nothing left to set up.
    var isSetUp: Bool {
        status == .enabled && hostPermission == .allWebsites
    }

    /// Installed but not fully usable: switched off, errored, or enabled without
    /// all-websites access. `.unknown` (still loading) stays quiet so we never
    /// flash a false warning on launch.
    var needsAttention: Bool {
        switch status {
        case .disabled, .error: true
        case .enabled: hostPermission == .someWebsites
        case .unknown: false
        }
    }

    var errorMessage: String? {
        if case .error(let message) = status { return message }
        return nil
    }

    /// Whether Safari has granted `permission`, as last reported by the extension;
    /// nil until it has pinged from a page load.
    func isGranted(_ permission: ExtensionPermission) -> Bool? {
        switch permission {
        case .allWebsites: hostPermission == .unknown ? nil : hostPermission == .allWebsites
        }
    }

    private func readHostPermission() -> HostPermission {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            defaults.object(forKey: SharedDefaultsKey.permissionPingTimestamp) != nil
        else { return .unknown }
        return defaults.bool(forKey: SharedDefaultsKey.permissionHasAllUrls)
            ? .allWebsites
            : .someWebsites
    }
}
