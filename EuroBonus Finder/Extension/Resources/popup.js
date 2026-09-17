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
        [`pending_return_${shopUuid}`]: {
          originalUrl,
          timestamp: Date.now(),
        },
      });
    } catch (e) {
      return Promise.resolve();
    }
  };

  // EB icon glyph — the framed "EB" monogram (currentColor).
  const ebGlyph = (size) =>
    `<svg width="${size}" height="${size}" fill="none" viewBox="0 0 24 24" aria-hidden="true">` +
    `<path fill="currentColor" fill-rule="evenodd" d="M12.31 15.5v-7h2.663q.754 0 1.253.24.503.235.75.645.253.411.252.93 0 .428-.163.731-.164.3-.438.49a1.9 1.9 0 0 1-.615.27v.068q.37.02.71.228.344.205.56.582.218.375.218.909 0 .543-.262.977-.261.43-.788.68-.526.25-1.324.25zm1.26-1.06h1.355q.687 0 .989-.263a.87.87 0 0 0 .306-.683 1.05 1.05 0 0 0-.588-.957 1.44 1.44 0 0 0-.673-.147H13.57zm0-2.963h1.247q.326 0 .587-.12a.928.928 0 0 0 .564-.878.87.87 0 0 0-.285-.67q-.282-.263-.84-.263H13.57z" clip-rule="evenodd"></path>` +
    `<path fill="currentColor" d="M6.5 8.5v7h4.552v-1.063H7.76v-1.91h3.03v-1.064H7.76v-1.9h3.264V8.5z"></path>` +
    `<path fill="currentColor" fill-rule="evenodd" d="M4.2 4h15.6A2.2 2.2 0 0 1 22 6.2v11.6a2.2 2.2 0 0 1-2.2 2.2H4.2A2.2 2.2 0 0 1 2 17.8V6.2A2.2 2.2 0 0 1 4.2 4m0 1.5a.7.7 0 0 0-.7.7v11.6a.7.7 0 0 0 .7.7h15.6a.7.7 0 0 0 .7-.7V6.2a.7.7 0 0 0-.7-.7z" clip-rule="evenodd"></path></svg>`;

  const CHEVRON_ICON =
    `<svg width="16" height="16" fill="none" viewBox="0 0 24 24" aria-hidden="true">` +
    `<path d="m9 6 6 6-6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path></svg>`;

  const INFO_ICON =
    `<svg width="18" height="18" fill="none" viewBox="0 0 24 24" aria-hidden="true">` +
    `<circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.6"></circle>` +
    `<path d="M12 8v4M12 16h.01" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"></path></svg>`;

  // Status = shadcn Alert: [icon] [title + description]. Match → success + EB glyph.
  // "empty" = no card; centered in the content area.
  const setStatus = (html, klass) => {
    statusEl.className = `status ${klass || ""}`.trim();
    const icon = klass === "match" ? ebGlyph(18) : INFO_ICON;
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
          ${entry.url ? `<span class="item-actions">${CHEVRON_ICON}</span>` : ""}
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
