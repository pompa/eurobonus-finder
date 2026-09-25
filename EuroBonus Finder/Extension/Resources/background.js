// Reports Safari's website-access grants to the host app for its setup screen.
// Lives here because content scripts can't use the permissions API.
const api = globalThis.browser || globalThis.chrome;

const hasOriginAccess = async (origins) => {
  try {
    return await api.permissions.contains({ origins });
  } catch (e) {
    return false;
  }
};

// Safari can report the all-websites grant under more than one match-pattern
// shape, so probe several rather than trusting a single pattern.
const hasAllSitesAccess = async () => {
  for (const origins of [["*://*/*"], ["https://*/*", "http://*/*"], ["<all_urls>"]]) {
    if (await hasOriginAccess(origins)) return true;
  }
  return false;
};

const readGrants = async () => ({ hasAllUrls: await hasAllSitesAccess() });

// Only wakes the native handler when the grants changed since the last report.
const reportPermissions = async (origin = "") => {
  const grants = await readGrants();
  const key = JSON.stringify(grants);
  try {
    const { reportedPermissions } = await api.storage.local.get("reportedPermissions");
    if (reportedPermissions === key) return;
    await api.runtime.sendNativeMessage("application.id", {
      type: "host-permission-ping",
      origin,
      ...grants,
      timestamp: Date.now(),
    });
    await api.storage.local.set({ reportedPermissions: key });
  } catch (e) {}
};

api.runtime.onMessage.addListener((message) => {
  if (message && message.type === "report-permissions") reportPermissions(message.origin);
  if (message && message.type === "get-permissions") return readGrants();
});
api.runtime.onInstalled.addListener(() => api.storage.local.remove("reportedPermissions"));
api.permissions.onAdded?.addListener(() => reportPermissions());
api.permissions.onRemoved?.addListener(() => reportPermissions());
