import SafariServices

/// Stamped into Info.plist from $(APP_BUNDLE_ID) at build time — the appex
/// can't derive the container app's id from its own.
let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as! String

enum SharedDefaultsKey {
    static let permissionPingTimestamp = "permission.lastPingTimestamp"
    static let permissionHasAllUrls = "permission.hasAllUrls"
    static let permissionLastOrigin = "permission.lastOrigin"
    static let market = "market"
}

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey]

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: handle(message: message)]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    private func handle(message: Any?) -> [String: Any] {
        guard
            let dict = message as? [String: Any],
            let type = dict["type"] as? String,
            let defaults = UserDefaults(suiteName: appGroupID)
        else { return ["ok": true] }

        if type == "get-market" {
            // Absent until the user picks a region; pre-region users were Swedish.
            return ["market": defaults.string(forKey: SharedDefaultsKey.market) ?? "se"]
        }
        guard type == "host-permission-ping" else { return ["ok": true] }

        let hasAllUrls = dict["hasAllUrls"] as? Bool ?? false
        let origin = dict["origin"] as? String ?? ""
        defaults.set(Date().timeIntervalSince1970, forKey: SharedDefaultsKey.permissionPingTimestamp)
        defaults.set(hasAllUrls, forKey: SharedDefaultsKey.permissionHasAllUrls)
        defaults.set(origin, forKey: SharedDefaultsKey.permissionLastOrigin)
        return ["ok": true]
    }
}
