// Sunset build: a Smart App Banner on every page that sends testers to the
// launched app and the new TestFlight, both linked from the website. Once it's
// closed or its View button tapped, it never shows again.
(async function () {
  const api = globalThis.browser || globalThis.chrome;
  if (!api || !api.storage) return;

  const SITE_URL = "https://eurobonus.pompa.se/";
  const ROOT_ID = "ebfinder-root";
  const DONE_KEY = "sunsetBannerDone";

  // Wipe everything the old build kept (market, feed cache, Tutorial, pending
  // returns, its per-site banner flag); only DONE_KEY survives.
  let stored = {};
  try {
    stored = await api.storage.local.get(null);
    const stale = Object.keys(stored).filter((k) => k !== DONE_KEY);
    if (stale.length) await api.storage.local.remove(stale);
  } catch (e) {}
  try {
    sessionStorage.removeItem("ebfinder.bannerClosed");
  } catch (e) {}

  if (stored[DONE_KEY]) return;
  if (window.location.hostname === new URL(SITE_URL).hostname) return;
  if (document.getElementById(ROOT_ID)) return;

  const t = (key) => (api.i18n && api.i18n.getMessage(key)) || key;

  const root = document.createElement("div");
  root.id = ROOT_ID;
  const shadow = root.attachShadow({ mode: "open" });
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = api.runtime.getURL("styles.css");
  shadow.appendChild(link);

  const banner = document.createElement("div");
  banner.className = "banner flat";
  banner.innerHTML = `
    <button class="btn btn-icon btn-sm btn-ghost tap banner-close" type="button" aria-label="${t("close")}"><span class="glyph" aria-hidden="true">×</span></button>
    <span class="eb-glyph"><img src="${api.runtime.getURL("images/icon-128.png")}" width="40" height="40" alt=""></span>
    <div class="banner-body">
      <div class="banner-title">${t("sunsetTitle")}</div>
      <div class="banner-desc">${t("sunsetDesc")}</div>
    </div>
    <a href="${SITE_URL}" target="_blank" rel="noopener noreferrer" class="btn btn-primary btn-sm tap">${t("sunsetCta")}</a>`;
  shadow.appendChild(banner);
  document.documentElement.prepend(root);

  // Push the page, and its fixed top bars, down by the banner's height.
  const pushed = [...document.querySelectorAll("body *")]
    .filter((el) => {
      const s = window.getComputedStyle(el);
      return s.position === "fixed" && s.top === "0px";
    })
    .map((el) => [el, el.style.top]);
  const syncOffset = () => {
    const h = banner.offsetHeight;
    if (h <= 0) return;
    document.documentElement.style.setProperty("margin-top", `${h}px`, "important");
    pushed.forEach(([el]) => el.style.setProperty("top", `${h}px`, "important"));
  };
  const observer = new ResizeObserver(syncOffset);
  observer.observe(banner);

  const close = () => {
    observer.disconnect();
    root.remove();
    document.documentElement.style.removeProperty("margin-top");
    pushed.forEach(([el, top]) => {
      el.style.removeProperty("top");
      el.style.top = top;
    });
    api.storage.local.set({ [DONE_KEY]: true }).catch(() => {});
  };
  shadow.querySelector(".banner-close").addEventListener("click", close);
  // View opens the site in a new tab (the link's default) and retires the
  // banner — after the click, so the link is still in the page when it fires.
  shadow.querySelector(".btn-primary").addEventListener("click", () => setTimeout(close));

  // Double rAF: let opacity:0 paint first so the fade-in transition runs.
  requestAnimationFrame(() => requestAnimationFrame(() => banner.classList.add("is-visible")));
})();
