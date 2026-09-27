// Live status box for /setup-extension-permission/ (the Test page the app's
// Setup opens). The extension's content script marks
// <html data-ebfinder-access="all|partial"> when it runs here; until then Safari
// isn't letting it run on this page. Success is drawn here too, in the brand blue.
(() => {
  // APP_URL_SCHEME in EuroBonus Finder/Config/Build.xcconfig — the site build has no access to it.
  const APP_URL = "eurobonusfinder://setup/verify";
  const NOT_DETECTED_AFTER_MS = 4000;
  const sv = document.documentElement.lang === "sv";
  const T = sv
    ? {
        waiting: "Väntar på tillägget…",
        notDetected: "Tillägget körs inte här än. Följ stegen nedan och ladda sedan om sidan.",
        all: "Det funkar! EuroBonus Finder får köras på alla webbplatser.",
        partial: "Nästan framme: tillägget körs här, men inte på alla webbplatser än. Se nedan.",
        back: "Tillbaka till appen",
        reload: "Ladda om",
      }
    : {
        waiting: "Waiting for the extension…",
        notDetected: "The extension isn't running here yet. Follow the steps below, then reload.",
        all: "It works! EuroBonus Finder is allowed on every website.",
        partial: "Almost there: the extension runs here, but not on every website yet. See below.",
        back: "Back to the app",
        reload: "Reload",
      };

  const style = document.createElement("style");
  style.textContent = `
    .ebf-status { position: relative; margin: 0 0 32px; padding: 18px 56px 18px 20px; border-radius: 16px;
      background: oklch(0.967 0.0029 264.542); color: var(--foreground); font-weight: 600; }
    .ebf-status[data-state="all"] { background: var(--primary); color: var(--primary-foreground); }
    .ebf-status[data-state="all"] .ebf-back { background: var(--primary-foreground); color: var(--primary); }
    .ebf-status[data-state="all"] .ebf-reload { background: oklch(1 0 0 / 0.18); color: var(--primary-foreground); }
    .ebf-status[data-state="partial"], .ebf-status[data-state="notDetected"] { background: oklch(0.97 0.05 85); }
    .ebf-status p { margin: 0; }
    .ebf-corner { position: absolute; top: 12px; right: 12px; width: 32px; height: 32px;
      display: flex; align-items: center; justify-content: center; }
    .ebf-spinner { width: 20px; height: 20px; border-radius: 50%;
      border: 2.5px solid oklch(0 0 0 / 0.12); border-top-color: var(--primary);
      animation: ebf-spin 0.8s linear infinite; }
    @keyframes ebf-spin { to { transform: rotate(360deg); } }
    .ebf-reload { width: 32px; height: 32px; padding: 0; border: 0; border-radius: 50%; cursor: pointer;
      background: oklch(0 0 0 / 0.06); color: var(--foreground); display: flex; align-items: center; justify-content: center; }
    .ebf-reload:hover { background: oklch(0 0 0 / 0.1); }
    .ebf-back { display: block; margin: 16px -36px 0 0; padding: 15px 22px; border-radius: var(--radius-full);
      background: var(--primary); color: var(--primary-foreground); text-decoration: none;
      font-size: 17px; font-weight: 700; text-align: center; }
    @media (min-width: 600px) {
      .ebf-back { display: inline-block; margin-right: 0; padding: 11px 20px; font-size: 15px; }
    }
    @media (prefers-reduced-motion: reduce) { .ebf-spinner { animation-duration: 2s; } }
  `;
  document.head.appendChild(style);

  const box = document.createElement("section");
  box.className = "ebf-status";
  box.setAttribute("role", "status");
  box.innerHTML = `
    <p></p>
    <div class="ebf-corner"></div>
    <a class="ebf-back" href="${APP_URL}" hidden>${T.back}</a>`;
  const text = box.querySelector("p");
  const corner = box.querySelector(".ebf-corner");
  const back = box.querySelector(".ebf-back");
  const spinner = `<span class="ebf-spinner" aria-hidden="true"></span>`;
  const reload = `<button class="ebf-reload" type="button" aria-label="${T.reload}">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M21 12a9 9 0 1 1-2.6-6.4"/><polyline points="21 3 21 9 15 9"/></svg></button>`;
  corner.addEventListener("click", (e) => { if (e.target.closest(".ebf-reload")) location.reload(); });
  const hero = document.querySelector("main .hero");
  (hero || document.querySelector("main")).after(box);

  const started = Date.now();
  let shown = "";
  const render = () => {
    const access = document.documentElement.dataset.ebfinderAccess;
    const state = access || (Date.now() - started >= NOT_DETECTED_AFTER_MS ? "notDetected" : "waiting");
    if (state === shown) return;
    shown = state;
    box.dataset.state = state;
    text.textContent = T[state];
    corner.innerHTML = state === "waiting" ? spinner : reload;
    back.hidden = state === "waiting";
  };
  render();
  // Keep polling: Safari can start the extension on this page after the user allows it.
  setInterval(render, 500);
})();
