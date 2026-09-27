// Live status box for /setup-extension-permission/ (the Test page the app's
// Setup opens). The extension's content script marks
// <html data-ebfinder-access="all|partial"> when it runs here; until then Safari
// isn't letting it run on this page. In Setup the extension shows its own banner
// (#ebfinder-setup), which replaces this box.
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
      }
    : {
        waiting: "Waiting for the extension…",
        notDetected: "The extension isn't running here yet. Follow the steps below, then reload.",
        all: "It works! EuroBonus Finder is allowed on every website.",
        partial: "Almost there: the extension runs here, but not on every website yet. See below.",
        back: "Back to the app",
      };

  const style = document.createElement("style");
  style.textContent = `
    .ebf-status { display: flex; flex-wrap: wrap; align-items: center; gap: 12px 16px;
      margin: 0 0 32px; padding: 16px 20px; border-radius: 16px;
      background: oklch(0.967 0.0029 264.542); color: var(--foreground); font-weight: 600; }
    .ebf-status[data-state="all"] { background: oklch(0.95 0.05 150); }
    .ebf-status[data-state="partial"], .ebf-status[data-state="notDetected"] { background: oklch(0.97 0.05 85); }
    .ebf-status p { flex: 1 1 240px; margin: 0; }
    .ebf-status a { flex: none; padding: 9px 16px; border-radius: var(--radius-full);
      background: var(--primary); color: var(--primary-foreground); text-decoration: none; font-size: 14px; }
  `;
  document.head.appendChild(style);

  const box = document.createElement("section");
  box.className = "ebf-status";
  box.setAttribute("role", "status");
  box.innerHTML = `<p></p><a href="${APP_URL}">${T.back}</a>`;
  const text = box.querySelector("p");
  const hero = document.querySelector("main .hero");
  (hero || document.querySelector("main")).after(box);

  const started = Date.now();
  const render = () => {
    if (document.getElementById("ebfinder-setup")) {
      box.hidden = true;
      return;
    }
    const access = document.documentElement.dataset.ebfinderAccess;
    const state = access || (Date.now() - started >= NOT_DETECTED_AFTER_MS ? "notDetected" : "waiting");
    box.hidden = false;
    box.dataset.state = state;
    text.textContent = T[state];
  };
  render();
  // Keep polling: Safari can start the extension on this page after the user allows it.
  setInterval(render, 500);
})();
