(async function () {
  const api = globalThis.browser || globalThis.chrome;
  const statusEl = document.getElementById("status");
  const ctaEl = document.getElementById("cta");
  const listEl = document.getElementById("match-list");

  const { t } = EBFeed;
  document.getElementById("status-text").textContent = t("popupSearching");
  ctaEl.textContent = t("cta");
  document.getElementById("credit-text").textContent = t("popupCredit");

  // The popup isn't subject to the content-script hang, so it waits (capped).
  await EBFeed.refreshMarket();
  const market = await EBFeed.getMarket();
  const regionName = new Intl.DisplayNames([api.i18n.getUILanguage()], { type: "region" }).of(
    market.toUpperCase(),
  );
  document.getElementById("region-text").textContent = t("popupRegion", { region: regionName });

  const storePendingReturn = (originalUrl, shopUuid) => {
    try {
      return api.storage.local.set({
        [`pendingSasShoppingReturn.${shopUuid}`]: {
          originalUrl,
          timestamp: Date.now(),
        },
      });
    } catch (e) {
      return Promise.resolve();
    }
  };

  // EB icon — the app icon PNG, as in the banner and coachmark.
  const ebIcon = (size) =>
    `<img class="eb-glyph" src="images/icon-128.png" alt="" width="${size}" height="${size}" style="display:block;width:${size}px;height:${size}px;border-radius:22%">`;

  const CHEVRON = `<span class="glyph" aria-hidden="true">\u203a</span>`;

  const INFO_ICON =
    `<svg width="18" height="18" fill="none" viewBox="0 0 24 24" aria-hidden="true">` +
    `<circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.6"></circle>` +
    `<path d="M12 8v4M12 16h.01" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"></path></svg>`;

  // Status = shadcn Alert: [icon] [title + description]. Match → success + EB glyph.
  // "empty" = no card; centered in the content area.
  const setStatus = (html, klass) => {
    statusEl.className = `status ${klass || ""}`.trim();
    const icon = klass === "match" ? ebIcon(40) : INFO_ICON;
    statusEl.innerHTML = `<span class="status-icon">${icon}</span><div class="status-body">${html}</div>`;
  };

  // Match-list row = shadcn ghost Item: content (name / points + suffix) · actions (chevron when linkable).
  const renderMatchItem = (li, entry) => {
    li.innerHTML = `
      <a href="${entry.url}" target="_blank" rel="noopener noreferrer">
        <div class="item">
          <span class="item-content">
            <div class="item-title">${entry.name}</div>
            <div class="item-desc">${t("pointsShort", { count: EBFeed.effectivePoints(entry) })} ${EBFeed.suffix(entry, market, true)}</div>
          </span>
          ${entry.url ? `<span class="item-actions">${CHEVRON}</span>` : ""}
        </div>
      </a>
    `;
  };

  const renderMatchList = (keys, shops) => {
    listEl.innerHTML = "";
    listEl.classList.add("visible");
    for (const key of keys) {
      if (!shops[key]) continue;
      const li = document.createElement("li");
      renderMatchItem(li, shops[key]);
      listEl.appendChild(li);
    }
  };

  const getCurrentTab = async () => {
    try {
      const tabs = await api.tabs.query({ active: true, currentWindow: true });
      return tabs && tabs[0] ? tabs[0] : null;
    } catch (e) {
      return null;
    }
  };

  // Missing website access: nudge the user to finish setup in the app.
  Promise.resolve(api.runtime.sendMessage({ type: "get-permissions" }))
    .then((grants) => {
      if (!grants || grants.hasAllUrls) return;
      const noticeEl = document.getElementById("setup-notice");
      noticeEl.href = EBFeed.appURL("extension");
      noticeEl.innerHTML = `<span class="status-icon">${INFO_ICON}</span><div class="status-body"><strong>${t("popupSetupTitle")}</strong>${t("popupSetupDesc")}</div>`;
      noticeEl.style.display = "flex";
    })
    .catch(() => {});

  const tab = await getCurrentTab();
  if (!tab || !tab.url) {
    setStatus(t("popupNoTab"), "empty");
    return;
  }

  const shops = await EBFeed.loadFeed(market);
  if (!shops) {
    setStatus(t("popupFeedError"), "empty");
    return;
  }

  let tabHost = "";
  try {
    tabHost = new URL(tab.url).hostname;
  } catch (e) {}
  const isGoogle = tabHost.includes("google.");

  if (isGoogle) {
    let response = null;
    try {
      response = await api.tabs.sendMessage(tab.id, { type: "ebfinder-detected" });
    } catch (e) {}
    const matches = (response && response.matches) || [];
    if (matches.length === 0) {
      setStatus(
        `<strong>${t("popupGoogleTitle")}</strong>${t("popupGoogleNone")}`,
        "empty",
      );
      return;
    }
    statusEl.style.display = "none";
    renderMatchList(matches, shops);
    return;
  }

  const matchedKey = EBFeed.matchKey(tab.url, shops);
  if (!matchedKey) {
    setStatus(
      `<strong>${t("popupNotPartnerTitle")}</strong>${t("popupNotPartnerDesc")}`,
      "empty",
    );
    return;
  }

  const entry = shops[matchedKey];
  const points = `<strong style="display:inline">${t("points", { count: EBFeed.effectivePoints(entry) })}</strong>`;
  setStatus(
    `<strong>${t("bannerTitle", { name: entry.name })}</strong>${t("earn", { points, suffix: EBFeed.suffix(entry, market) })}.`,
    "match",
  );
  ctaEl.href = entry.url;
  ctaEl.style.display = "flex";
  ctaEl.addEventListener("click", () => {
    // Fire-and-forget so the browser's default new-tab navigation keeps the user-gesture.
    storePendingReturn(tab.url, matchedKey);
  });
})();
