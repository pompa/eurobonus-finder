// Sunset build: a Smart App Banner on every page that sends testers to the
// launched app and the new TestFlight, both linked from the website. Closing it
// hides it everywhere for a day.
(async function () {
  const api = globalThis.browser || globalThis.chrome;
  if (!api || !api.storage) return;

  const SITE_URL = "https://eurobonus.pompa.se/";
  if (window.location.hostname === new URL(SITE_URL).hostname) return;

  const ROOT_ID = "ebfinder-root";
  const CLOSED_KEY = "sunsetBannerClosedAt";
  const SNOOZE_MS = 24 * 60 * 60 * 1000;

  try {
    const r = await api.storage.local.get([CLOSED_KEY]);
    if (Date.now() - (r[CLOSED_KEY] || 0) < SNOOZE_MS) return;
  } catch (e) {}
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

  shadow.querySelector(".banner-close").addEventListener("click", () => {
    observer.disconnect();
    root.remove();
    document.documentElement.style.removeProperty("margin-top");
    pushed.forEach(([el, top]) => {
      el.style.removeProperty("top");
      el.style.top = top;
    });
    api.storage.local.set({ [CLOSED_KEY]: Date.now() }).catch(() => {});
  });

  // Double rAF: let opacity:0 paint first so the fade-in transition runs.
  requestAnimationFrame(() => requestAnimationFrame(() => banner.classList.add("is-visible")));
})();
