// Shared by content.js and popup.js: the user's market, the per-market partner
// feed (built by workers/eb-feed), localized strings and the link into the app.
globalThis.EBFeed = (() => {
  const api = globalThis.browser || globalThis.chrome;
  // __FEED_HOST__ / __APP_URL_SCHEME__ are replaced with $(FEED_HOST) /
  // $(APP_URL_SCHEME) at build time (project.yml).
  const FEED_BASE = "https://__FEED_HOST__";
  const APP_URL = "__APP_URL_SCHEME__://";
  const MARKETS = ["se", "no", "dk", "fi"];
  const MARKET_KEY = "market";
  const CACHE_TTL_MS = 60 * 60 * 1000;

  // Last market the host app reported; "se" until it has answered once.
  const getMarket = async () => {
    try {
      const r = await api.storage.local.get([MARKET_KEY]);
      if (MARKETS.includes(r[MARKET_KEY])) return r[MARKET_KEY];
    } catch (e) {}
    return "se";
  };

  // A native-message read can hang in Safari, so never await this on the hot
  // path: it only updates storage for the next page load.
  const refreshMarket = async () => {
    if (!api.runtime || !api.runtime.sendNativeMessage) return;
    try {
      const res = await Promise.race([
        api.runtime.sendNativeMessage("application.id", { type: "get-market" }),
        new Promise((resolve) => setTimeout(resolve, 2000)),
      ]);
      if (res && MARKETS.includes(res.market)) {
        await api.storage.local.set({ [MARKET_KEY]: res.market });
      }
    } catch (e) {}
  };

  // Resolves to the feed's `data` map (key → entry), or null.
  const loadFeed = async (market) => {
    const cacheKey = `feed_${market}`;
    try {
      const r = await api.storage.local.get([cacheKey]);
      const c = r[cacheKey];
      if (c && Date.now() - c.timestamp < CACHE_TTL_MS) return c.data;
    } catch (e) {}
    try {
      const res = await fetch(`${FEED_BASE}/${market}.json`, { credentials: "omit" });
      if (!res.ok) return null;
      const json = await res.json();
      if (!json || typeof json.data !== "object") return null;
      try {
        await api.storage.local.set({ [cacheKey]: { data: json.data, timestamp: Date.now() } });
      } catch (e) {}
      return json.data;
    } catch (e) {
      return null;
    }
  };

  // Feed keys are `host` or `host/firstSegment` (lowercase, no www.). Any subdomain
  // belongs to its partner, so drop leading labels down to the apex, closest host
  // first. Returns the matching key or null.
  const matchKey = (urlStr, data) => {
    let url;
    try {
      url = new URL(urlStr);
    } catch (e) {
      return null;
    }
    const segment = url.pathname.split("/").find(Boolean);
    const labels = url.hostname.toLowerCase().replace(/^www\./, "").split(".");
    // Stop at two labels: a bare TLD or public suffix is never a partner key.
    for (let i = 0; i + 2 <= labels.length; i++) {
      const host = labels.slice(i).join(".");
      if (segment) {
        const withPath = `${host}/${segment.toLowerCase()}`;
        if (data[withPath]) return withPath;
      }
      if (data[host]) return host;
    }
    return null;
  };

  const hostOfKey = (key) => key.split("/")[0];

  const formatPoints = (value) =>
    (parseInt(value, 10) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");

  // Localized string with {placeholder} substitution.
  const t = (key, vars = {}) => {
    let s = (api.i18n && api.i18n.getMessage(key)) || key;
    for (const [k, v] of Object.entries(vars)) s = s.split(`{${k}}`).join(v);
    return s;
  };

  // "per 100 kr" / "som ny kund" for an entry, in the market's currency.
  const suffix = (entry, market, short = false) =>
    entry.type === "fixed"
      ? t("suffixFixed")
      : t(short ? "suffixVariableShort" : "suffixVariable", { unit: market === "fi" ? "€" : "kr" });

  const effectivePoints = (entry) =>
    formatPoints(entry.campaign && entry.campaignPoints ? entry.campaignPoints : entry.points);

  return {
    appURL: (path) => APP_URL + path,
    getMarket,
    refreshMarket,
    loadFeed,
    matchKey,
    hostOfKey,
    t,
    suffix,
    effectivePoints,
  };
})();
