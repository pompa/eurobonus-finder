import SafariServices

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
            let type = dict["type"] as? String
        else { return ["ok": true] }
        let defaults = UserDefaults.shared

        switch type {
        case "get-market":
            // Absent until the user picks a region; pre-region users were Swedish.
            return ["market": defaults.string(forKey: SharedDefaultsKey.market) ?? "se"]

        case "host-permission-ping":
            defaults.set(Date().timeIntervalSince1970, forKey: SharedDefaultsKey.permissionPingTimestamp)
            defaults.set(dict["hasAllUrls"] as? Bool ?? false, forKey: SharedDefaultsKey.permissionHasAllUrls)
            defaults.set(dict["origin"] as? String ?? "", forKey: SharedDefaultsKey.permissionLastOrigin)

        case "tutorial":
            // Mirror of the extension's `tutorial` object, stored as JSON for the app.
            let tutorial = dict["tutorial"] as? [String: Any] ?? [:]
            if let data = try? JSONSerialization.data(withJSONObject: tutorial, options: [.sortedKeys]) {
                defaults.set(String(decoding: data, as: UTF8.self), forKey: SharedDefaultsKey.tutorial)
            }

        case "get-last-reset-at":
            return [
                "lastResetAt": defaults.integer(forKey: SharedDefaultsKey.lastResetAt),
                "lastTutorialResetAt": defaults.integer(forKey: SharedDefaultsKey.lastTutorialResetAt),
            ]

        case "reset":
            // The extension's dev page asked for a Reset: wipe the App Group (the app
            // lands in Setup) and stamp it; the extension wipes its own storage.
            return ["lastResetAt": UserDefaults.resetShared()]

        default:
            break
        }
        return ["ok": true]
    }
}
