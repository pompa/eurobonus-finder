// Talks to the host app for the rest of the extension: reports Safari's
// website-access grants (content scripts can't use the permissions API), owns
// Tutorial progress and mirrors it to the app, and applies Resets. Native
// messaging lives here because it can hang when called from a content script.
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

const sendNative = (message) => api.runtime.sendNativeMessage("application.id", message);

// Tutorial progress: { seenBadge, visitedPartner, sasShoppingReturn } → true when
// done, in any order. Only this script writes it; every write is mirrored to the
// app (App Group `tutorialProgress.<step>`) so it can hide its Tutorial card.
const TUTORIAL_STEPS = ["seenBadge", "visitedPartner", "sasShoppingReturn"];

const setTutorialProgress = async (tutorialProgress) => {
  await api.storage.local.set({ tutorialProgress });
  try {
    await sendNative({ type: "tutorial-progress", tutorialProgress });
  } catch (e) {}
  return tutorialProgress;
};

// ponytail: unserialized read-merge-write; steps land on separate page loads, queue writes if that changes.
const completeTutorialStep = async (step) => {
  const { tutorialProgress = {} } = await api.storage.local.get("tutorialProgress");
  if (!TUTORIAL_STEPS.includes(step) || tutorialProgress[step]) return tutorialProgress;
  return setTutorialProgress({ ...tutorialProgress, [step]: true });
};

// Reset: the app stamps `lastResetAt` (epoch ms) in the App Group; when it
// differs from our copy, wipe everything we store and keep the new stamp.
const wipe = async (lastResetAt) => {
  await api.storage.local.clear();
  await api.storage.local.set({ lastResetAt });
};

const syncReset = async () => {
  try {
    const { lastResetAt } = await sendNative({ type: "get-last-reset-at" });
    const local = await api.storage.local.get("lastResetAt");
    if (lastResetAt && lastResetAt !== local.lastResetAt) await wipe(lastResetAt);
  } catch (e) {}
};

// Reset started from the extension's dev page: the app wipes the App Group, we wipe ourselves.
const reset = async () => {
  const { lastResetAt } = await sendNative({ type: "reset" });
  await wipe(lastResetAt);
  return { lastResetAt };
};

api.runtime.onMessage.addListener((message) => {
  if (!message) return;
  if (message.type === "report-permissions") reportPermissions(message.origin);
  if (message.type === "get-permissions") return readGrants();
  if (message.type === "sync-reset") return syncReset();
  if (message.type === "complete-tutorial-step") return completeTutorialStep(message.step);
  if (message.type === "set-tutorial-progress") return setTutorialProgress(message.tutorialProgress);
  if (message.type === "reset") return reset();
});
api.runtime.onInstalled.addListener(() => api.storage.local.remove("reportedPermissions"));
api.permissions.onAdded?.addListener(() => reportPermissions());
api.permissions.onRemoved?.addListener(() => reportPermissions());
