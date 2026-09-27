// The Test page (eurobonus.pompa.se/test-extension, opened by the
// app's Setup): tell the page whether we run here and with what access; its own
// script draws the result, and handles the "extension never ran" case (then
// neither do we). Setup opens it with #ebfSetup, which forces a fresh ping.
const TEST_PAGE_HOST = "eurobonus.pompa.se";
// Declared before the IIFE below: it runs synchronously up to its first await.

(async function () {
  const api = globalThis.browser || globalThis.chrome;
  if (!api || !api.storage) return;

  // Tutorial: the app's Tutorial card opens its Google search with #ebfTutorial.
  // Capture it synchronously now, before Google's SERP JS can rewrite the URL.
  const fromTutorialCard = /[#&]ebfTutorial\b/.test(window.location.hash || "");
  // Setup: the app's verify step opens the Test page with #ebfSetup.
  const fromSetup = /[#&]ebfSetup\b/.test(window.location.hash || "");

  reportHostPermission(api, fromSetup);

  const { t } = EBFeed;

  if (window.location.hostname === TEST_PAGE_HOST) {
    await markTestPage(api);
    return;
  }
  EBFeed.refreshMarket();
  const market = await EBFeed.getMarket();

  // Lives in the page's own sessionStorage, shared with the site — hence the prefix.
  const SESSION_KEY = "ebfinder.bannerClosed";
  const ROOT_ID = "ebfinder-root";
  const DECORATED_ATTR = "data-ebfinder-decorated";
  const BADGE_CLASS = "ebfinder-badge";
  const PENDING_KEY_PREFIX = "pendingSasShoppingReturn.";
  const PENDING_TTL_MS = 60 * 60 * 1000;
  const COACH_ROOT_ID = "ebfinder-coach-root";

  const detectedMatches = new Set();

  if (api.runtime && api.runtime.onMessage) {
    api.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
      if (msg && msg.type === "ebfinder-detected") {
        sendResponse({ matches: Array.from(detectedMatches) });
      }
    });
  }

  const normalizeUrl = (urlStr) => {
    if (!urlStr) return "";
    try {
      const url = new URL(urlStr);
      return (url.hostname + url.pathname)
        .toLowerCase()
        .trim()
        .replace(/^www\./, "")
        .replace(/\/$/, "");
    } catch (e) {
      return urlStr
        .toLowerCase()
        .trim()
        .replace(/^https?:\/\//, "")
        .replace(/^www\./, "")
        .replace(/\/$/, "");
    }
  };

  const cleanHost = (s) =>
    (s || "")
      .toString()
      .trim()
      .toLowerCase()
      .replace(/^https?:\/\//, "")
      .split("/")[0];

  const storePendingReturn = (originalUrl, shopUuid) => {
    try {
      return api.storage.local.set({
        [`${PENDING_KEY_PREFIX}${shopUuid}`]: {
          originalUrl,
          timestamp: Date.now(),
        },
      });
    } catch (e) {
      return Promise.resolve();
    }
  };

  const looksLikePostSasLanding = (url) => {
    try {
      const u = new URL(url);
      const p = u.searchParams;
      if (p.has("irclickid") || p.has("irgwc") || p.has("irpid")) return true;
      if (p.has("awc") || p.has("awinmid") || p.has("awinaffid")) return true;
      if (p.has("at_gd") || p.has("tap_a") || p.has("tap_s")) return true;
      if (p.has("tduid")) return true;
      if (p.has("afsrc")) return true;
      const utmSource = (p.get("utm_source") || "").toLowerCase();
      if (
        /impact|awin|adtraction|tradedoubler|cobiro|loyaltykey/.test(utmSource)
      ) {
        return true;
      }
      const utmCampaign = (p.get("utm_campaign") || "").toLowerCase();
      if (
        utmCampaign.includes("sas") &&
        utmCampaign.includes("onlineshopping")
      ) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  };

  const buildReturnUrl = (originalUrl, sasLandingUrl) => {
    try {
      const original = new URL(originalUrl);
      const sas = new URL(sasLandingUrl);
      for (const [key, value] of sas.searchParams) {
        original.searchParams.set(key, value);
      }
      return original.toString();
    } catch (e) {
      return originalUrl;
    }
  };

  const handlePendingReturn = async (matchedId) => {
    const key = `${PENDING_KEY_PREFIX}${matchedId}`;
    let stored;
    try {
      stored = await api.storage.local.get([key]);
    } catch (e) {
      return false;
    }
    const pending = stored[key];
    if (!pending) return false;

    if (Date.now() - pending.timestamp > PENDING_TTL_MS) {
      try {
        await api.storage.local.remove([key]);
      } catch (e) {}
      return false;
    }

    const currentUrl = window.location.href;
    if (!looksLikePostSasLanding(currentUrl)) return false;

    if (normalizeUrl(currentUrl) === normalizeUrl(pending.originalUrl)) {
      try {
        await api.storage.local.remove([key]);
      } catch (e) {}
      return false;
    }

    const returnUrl = buildReturnUrl(pending.originalUrl, currentUrl);
    try {
      await api.storage.local.remove([key]);
    } catch (e) {}
    // No Coachmark for this step yet — the console line stands in for one.
    await completeTutorialStep("sasShoppingReturn");
    location.replace(returnUrl);
    return true;
  };

  // Shadow-DOM surfaces (banner, coachmark) pull tokens + the page-injected
  // component sheet — NOT the popup stylesheet — so host pages only download the
  // CSS the injected UI actually uses.
  const SHADOW_STYLESHEETS = ["tokens.css", "content.css"];
  const attachShadowStyles = (shadow) => {
    for (const href of SHADOW_STYLESHEETS) {
      const link = document.createElement("link");
      link.rel = "stylesheet";
      link.href = api.runtime.getURL(href);
      shadow.appendChild(link);
    }
  };

  const buildBanner = (key, shopList) => {
    const data = shopList[key];
    if (!data) return null;

    const root = document.createElement("div");
    root.id = ROOT_ID;

    const shadow = root.attachShadow({ mode: "open" });
    attachShadowStyles(shadow);

    const container = document.createElement("div");
    container.className = "fixed-banner-container";

    const name = data.name || "";
    const pointsSpan = `<span class="points-highlight">${t("points", { count: EBFeed.effectivePoints(data) })}</span>`;
    const titleFull = t("bannerTitle", { name });
    const titleShort = t("bannerTitleShort", { name });
    const desc = t("earn", {
      points: pointsSpan,
      suffix: EBFeed.suffix(data, market),
    });

    container.innerHTML = `
      <div class="banner-wrapper">
        <div class="banner-alert">
          <span class="alert-icon">${EB_GLYPH_SVG}</span>
          <div class="alert-body">
            <div class="alert-title">
              <span class="title-full">${titleFull}</span>
              <span class="title-short">${titleShort}</span>
            </div>
            <div class="alert-desc">${desc}</div>
          </div>
        </div>
        <div class="actions">
          <a href="${data.url}" target="_blank" rel="noopener noreferrer" class="cta-btn">
            <span class="cta-full">${t("cta")}</span>
            <span class="cta-short">${t("ctaShort")}</span>
          </a>
          <button class="close-btn" aria-label="${t("close")}">✕</button>
        </div>
      </div>`;
    shadow.appendChild(container);

    const ctaLink = shadow.querySelector(".cta-btn");
    if (ctaLink) {
      ctaLink.addEventListener("click", () => {
        // Fire-and-forget so the browser's default new-tab navigation keeps the user-gesture.
        storePendingReturn(window.location.href, key);
      });
    }

    const closeBtn = shadow.querySelector(".close-btn");
    if (closeBtn) {
      closeBtn.addEventListener("click", () => {
        // Fade out, then tear down once the transition finishes.
        container.classList.remove("is-visible");
        let done = false;
        const cleanup = () => {
          if (done) return;
          done = true;
          root.remove();
          document.documentElement.style.marginTop = "";
          document
            .querySelectorAll('[data-ebfinder-pushed="true"]')
            .forEach((el) => {
              el.style.top = el.dataset.ebfinderPrevTop || "";
            });
        };
        container.addEventListener("transitionend", cleanup, { once: true });
        setTimeout(cleanup, 450); // fallback if transitionend never fires
        try {
          sessionStorage.setItem(SESSION_KEY, "true");
        } catch (e) {}
      });
    }
    return root;
  };

  const showTopBanner = (key, shopList) => {
    if (document.getElementById(ROOT_ID)) return;
    const banner = buildBanner(key, shopList);
    if (!banner) return;
    document.documentElement.prepend(banner);

    const bannerEl = banner.shadowRoot.querySelector(".fixed-banner-container");
    if (!bannerEl) return;

    document.querySelectorAll("*").forEach((el) => {
      if (el.id === ROOT_ID) return;
      const s = window.getComputedStyle(el);
      if (s.position === "fixed" && s.top === "0px") {
        el.dataset.ebfinderPrevTop = el.style.top || "";
        el.dataset.ebfinderPushed = "true";
      }
    });

    const syncOffset = () => {
      const h = bannerEl.offsetHeight;
      if (h <= 0) return;
      document.documentElement.style.setProperty(
        "margin-top",
        `${h}px`,
        "important",
      );
      document
        .querySelectorAll('[data-ebfinder-pushed="true"]')
        .forEach((el) => {
          el.style.setProperty("top", `${h}px`, "important");
        });
    };

    syncOffset();
    new ResizeObserver(syncOffset).observe(bannerEl);

    // Double rAF: let the initial opacity:0 paint before flipping to visible so
    // the opacity transition actually runs (fades the banner in).
    requestAnimationFrame(() => {
      requestAnimationFrame(() => bannerEl.classList.add("is-visible"));
    });
  };

  // Mirrors --primary from tokens.css. Inline !important styles fight third-party
  // CSS on host pages, so `var(--*)` can't reach here — the value stays literal.
  const TOKENS = {
    primary: "#003df5" /* --primary (SAS blue) — same EB icon color as the banner */,
  };

  // EB icon glyph — the framed "EB" monogram (currentColor).
  const EB_GLYPH_SVG =
    '<svg width="17" height="17" fill="none" viewBox="0 0 24 24" aria-hidden="true" style="display:block">' +
    '<path fill="currentColor" fill-rule="evenodd" d="M12.31 15.5v-7h2.663q.754 0 1.253.24.503.235.75.645.253.411.252.93 0 .428-.163.731-.164.3-.438.49a1.9 1.9 0 0 1-.615.27v.068q.37.02.71.228.344.205.56.582.218.375.218.909 0 .543-.262.977-.261.43-.788.68-.526.25-1.324.25zm1.26-1.06h1.355q.687 0 .989-.263a.87.87 0 0 0 .306-.683 1.05 1.05 0 0 0-.588-.957 1.44 1.44 0 0 0-.673-.147H13.57zm0-2.963h1.247q.326 0 .587-.12a.928.928 0 0 0 .564-.878.87.87 0 0 0-.285-.67q-.282-.263-.84-.263H13.57z" clip-rule="evenodd"></path>' +
    '<path fill="currentColor" d="M6.5 8.5v7h4.552v-1.063H7.76v-1.91h3.03v-1.064H7.76v-1.9h3.264V8.5z"></path>' +
    '<path fill="currentColor" fill-rule="evenodd" d="M4.2 4h15.6A2.2 2.2 0 0 1 22 6.2v11.6a2.2 2.2 0 0 1-2.2 2.2H4.2A2.2 2.2 0 0 1 2 17.8V6.2A2.2 2.2 0 0 1 4.2 4m0 1.5a.7.7 0 0 0-.7.7v11.6a.7.7 0 0 0 .7.7h15.6a.7.7 0 0 0 .7-.7V6.2a.7.7 0 0 0-.7-.7z" clip-rule="evenodd"></path></svg>';

  // The badge renders the SAME framed EB monogram as the banner (EB_GLYPH_SVG),
  // colored in --primary; inline !important keeps host-page CSS from disturbing
  // its box. No separate background — the monogram already carries its own frame.
  const BADGE_STYLE = [
    "display:inline-flex !important",
    "align-items:center !important",
    "justify-content:center !important",
    "vertical-align:middle !important",
    `color:${TOKENS.primary} !important`,
    "background:transparent !important",
    "margin:0 0 0 6px !important",
    "padding:2px !important",
    "border:0 !important",
    "line-height:0 !important",
    "cursor:pointer !important",
    "user-select:none !important",
    "position:relative !important",
    "z-index:2147483646 !important",
    "opacity:1 !important",
  ].join(";");

  const injectBadge = (target, matchedKey, shopList) => {
    const entry = shopList[matchedKey];
    if (!target || !target.parentNode) return;
    if (target.classList && target.classList.contains(BADGE_CLASS)) return;
    const next = target.nextElementSibling;
    if (next && next.classList && next.classList.contains(BADGE_CLASS)) return;

    const badge = document.createElement("span");
    badge.className = BADGE_CLASS;
    badge.dataset.ebHost = EBFeed.hostOfKey(matchedKey);
    badge.innerHTML = EB_GLYPH_SVG;
    badge.title = t("badgeTitle", {
      name: entry.name,
      points: t("points", { count: EBFeed.effectivePoints(entry) }),
      suffix: EBFeed.suffix(entry, market),
    });
    badge.setAttribute("role", "link");
    badge.setAttribute("aria-label", t("badgeAria"));
    badge.setAttribute("tabindex", "0");
    badge.style.cssText = BADGE_STYLE;

    const activate = (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (typeof e.stopImmediatePropagation === "function")
        e.stopImmediatePropagation();
      if (entry.url) window.open(entry.url, "_blank", "noopener,noreferrer");
    };

    const swallow = (e) => {
      e.stopPropagation();
      if (typeof e.stopImmediatePropagation === "function")
        e.stopImmediatePropagation();
    };

    badge.addEventListener("click", activate);
    badge.addEventListener("mousedown", swallow);
    badge.addEventListener("pointerdown", swallow);
    badge.addEventListener("touchstart", swallow, { passive: true });
    badge.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") activate(e);
    });

    target.parentNode.insertBefore(badge, target.nextSibling);
  };

  const matchVendorString = (raw, shopList) => {
    if (!raw) return null;
    const trimmed = raw.trim().toLowerCase();
    let key = EBFeed.matchKey(`https://${trimmed}/`, shopList);
    if (key) return key;
    if (!trimmed.includes(".")) {
      // Market codes double as their country TLDs (.se, .no, .dk, .fi).
      for (const tld of [`.${market}`, ".com"]) {
        key = EBFeed.matchKey(`https://${trimmed}${tld}/`, shopList);
        if (key) return key;
      }
    }
    return null;
  };

  const ariaVendorSelector =
    '[aria-label^="From "],[aria-label^="Från "],[aria-label^="Fra "]';

  const decorateGooglePartners = (shopList) => {
    // Primary signal: Google's `data-dtld` ("displayed top-level domain") attribute,
    // present on both shopping card containers and the URL chip in organic results.
    const dtldElements = document.querySelectorAll(
      `[data-dtld]:not([${DECORATED_ATTR}])`,
    );
    for (const el of dtldElements) {
      el.setAttribute(DECORATED_ATTR, "1");
      const domain = el.getAttribute("data-dtld");
      if (!domain) continue;
      const matchedKey = matchVendorString(domain, shopList);
      if (!matchedKey) continue;
      detectedMatches.add(matchedKey);
      // Prefer the visible vendor-name display inside the card (aria-label="From X")
      const vendorEl = el.querySelector(ariaVendorSelector);
      const target = vendorEl && el.contains(vendorEl) ? vendorEl : el;
      injectBadge(target, matchedKey, shopList);
    }

    // Fallback: aria-label="From X" elements outside of any [data-dtld] container
    // (e.g. variant cards, alternate Shopping layouts).
    const ariaElements = document.querySelectorAll(
      `${ariaVendorSelector}:not([${DECORATED_ATTR}])`,
    );
    for (const el of ariaElements) {
      el.setAttribute(DECORATED_ATTR, "1");
      const label = el.getAttribute("aria-label") || "";
      const m = label.match(/^(?:From|Från|Fra)\s+(.+?)$/i);
      if (!m) continue;
      const matchedKey = matchVendorString(m[1], shopList);
      if (!matchedKey) continue;
      detectedMatches.add(matchedKey);
      injectBadge(el, matchedKey, shopList);
    }
  };

  // ===========================================================================
  // TUTORIAL — Coachmarks for the Tutorial steps the user hasn't completed yet
  // (in any order). Progress lives in storage.local; the background script owns
  // writes and mirrors them to the app. Closing a Coachmark completes its step.
  // ===========================================================================

  // Applies a pending Reset from the app first (capped: native messaging can be
  // slow), so a fresh start isn't coached from stale progress.
  const getTutorialProgress = async () => {
    try {
      await Promise.race([
        api.runtime.sendMessage({ type: "sync-reset" }),
        new Promise((resolve) => setTimeout(resolve, 1000)),
      ]);
      const r = await api.storage.local.get(["tutorialProgress"]);
      return r.tutorialProgress || {};
    } catch (e) {
      return {};
    }
  };

  const completeTutorialStep = async (step) => {
    // ponytail: always logs; gate on a dev build once the extension has a build step (Vite).
    console.info(`[EuroBonus Finder] tutorial step completed: ${step}`);
    try {
      await api.runtime.sendMessage({ type: "complete-tutorial-step", step });
    } catch (e) {}
  };

  // A known EuroBonus-partner origin to fall back to when results show no badge.
  const partnerHostFromShops = (shopList) => {
    const prefer = [
      "webhallen.com",
      `komplett.${market}`,
      `proshop.${market}`,
    ];
    for (const h of prefer) if (shopList[h]) return cleanHost(h);
    const first = Object.keys(shopList)[0];
    return first ? cleanHost(first) : null;
  };

  // Coachmark: an anchored popover for the Tutorial. Own Shadow DOM overlay (like the
  // banner) so host-page CSS can't reach it; position tracks a live getRect().
  // Self-guards on COACH_ROOT_ID so the Google MutationObserver can't duplicate it.
  const createCoachmark = ({
    getRect,
    title,
    body,
    ctaLabel,
    onCta,
    onClose,
    showGlyph,
  }) => {
    if (document.getElementById(COACH_ROOT_ID)) return null;

    const root = document.createElement("div");
    root.id = COACH_ROOT_ID;
    const shadow = root.attachShadow({ mode: "open" });
    attachShadowStyles(shadow);

    const card = document.createElement("div");
    card.className = "coach-card";
    const glyph = showGlyph
      ? `<span class="coach-eb">${EB_GLYPH_SVG}</span>`
      : "";
    card.innerHTML = `
      <span class="coach-arrow"></span>
      <button class="coach-close" type="button" aria-label="${t("close")}">✕</button>
      <p class="coach-title">${glyph}<span>${title}</span></p>
      <p class="coach-body">${body}</p>
      <div class="coach-actions">
        <button class="btn btn-default btn-sm coach-cta" type="button">${ctaLabel}</button>
      </div>`;
    shadow.appendChild(card);

    const arrow = card.querySelector(".coach-arrow");

    const reposition = () => {
      const rect = getRect();
      if (!rect) return;
      const m = 12;
      const cr = card.getBoundingClientRect();
      const cw = cr.width || 300;
      const ch = cr.height || 120;
      const vw = window.innerWidth;
      const vh = window.innerHeight;

      // Prefer below the anchor; flip above only if it would overflow the bottom.
      let placement = "bottom";
      let top = rect.bottom + 10;
      if (top + ch > vh - m && rect.top - 10 - ch > m) {
        placement = "top";
        top = rect.top - 10 - ch;
      }
      // Center on the anchor, clamped to the viewport; arrow tracks the anchor.
      const cx = rect.left + rect.width / 2;
      const left = Math.max(m, Math.min(cx - cw / 2, vw - cw - m));
      card.dataset.placement = placement;
      card.style.left = `${Math.round(left)}px`;
      card.style.top = `${Math.round(top)}px`;
      arrow.style.left = `${Math.round(Math.max(14, Math.min(cx - left, cw - 14)) - 6)}px`;
    };

    let raf = 0;
    const schedule = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(reposition);
    };

    document.documentElement.appendChild(root);

    let ro;
    const remove = () => {
      window.removeEventListener("scroll", schedule, true);
      window.removeEventListener("resize", schedule);
      if (ro) ro.disconnect();
      cancelAnimationFrame(raf);
      root.remove();
    };

    card.querySelector(".coach-cta").addEventListener("click", async () => {
      try {
        if (onCta) await onCta();
      } finally {
        remove();
      }
    });
    card.querySelector(".coach-close").addEventListener("click", () => {
      remove();
      if (onClose) onClose();
    });

    window.addEventListener("scroll", schedule, true);
    window.addEventListener("resize", schedule);
    if (typeof ResizeObserver === "function") {
      ro = new ResizeObserver(schedule);
      ro.observe(card);
    }

    // Measure once laid out (rect is valid even at opacity:0), then fade in.
    requestAnimationFrame(() => {
      reposition();
      requestAnimationFrame(() => card.classList.add("is-visible"));
    });

    return { remove };
  };

  // Visit the partner in the same tab so the Banner (and its Coachmark) appear
  // on the page we land on.
  const visitPartner = (host) => {
    if (host) window.location.href = "https://" + cleanHost(host);
  };

  const showBadgeCoachmark = (shopList) => {
    const badge = document.querySelector("." + BADGE_CLASS);
    if (!badge) return;
    const host = badge.dataset.ebHost || partnerHostFromShops(shopList);
    createCoachmark({
      getRect: () => badge.getBoundingClientRect(),
      title: t("coachSearchTitle"),
      body: t("coachSearchBody"),
      ctaLabel: t("coachSearchCta"),
      showGlyph: true,
      onCta: async () => {
        await completeTutorialStep("seenBadge");
        visitPartner(host);
      },
      onClose: () => completeTutorialStep("seenBadge"),
    });
    badge.scrollIntoView({ block: "center", behavior: "smooth" });
  };

  // No Badge showed up on the Tutorial card's search: point at a known partner
  // instead. Completes nothing — the user still hasn't seen a Badge.
  const showNoBadgeCoachmark = (shopList) => {
    const host = partnerHostFromShops(shopList);
    createCoachmark({
      getRect: () => ({
        left: window.innerWidth / 2,
        top: 72,
        right: window.innerWidth / 2,
        bottom: 72,
        width: 0,
        height: 0,
      }),
      title: t("coachEmptyTitle"),
      body: t("coachEmptyBody"),
      ctaLabel: t("coachSearchCta"),
      showGlyph: true,
      onCta: () => visitPartner(host),
    });
  };

  const showBannerCoachmark = () => {
    if (document.getElementById(COACH_ROOT_ID)) return;
    const bannerRoot = document.getElementById(ROOT_ID);
    const cta =
      bannerRoot &&
      bannerRoot.shadowRoot &&
      bannerRoot.shadowRoot.querySelector(".cta-btn");
    if (!cta) return;
    createCoachmark({
      getRect: () => cta.getBoundingClientRect(),
      title: t("coachBannerTitle"),
      body: t("coachBannerBody"),
      ctaLabel: t("coachBannerCta"),
      onCta: () => completeTutorialStep("visitedPartner"),
      onClose: () => completeTutorialStep("visitedPartner"),
    });
  };

  // On a Google results page, coach the first Badge while `seenBadge` is open —
  // polling briefly since Google hydrates cards async. With no Badge, only the
  // Tutorial card's own search falls back to the no-Badge Coachmark.
  const maybeShowSearchCoachmark = async (shopList) => {
    const progress = await getTutorialProgress();
    if (progress.seenBadge) return;

    let elapsed = 0;
    const STEP_MS = 400;
    const LIMIT_MS = 4000;
    const tick = () => {
      if (document.getElementById(COACH_ROOT_ID)) return;
      if (document.querySelector("." + BADGE_CLASS)) {
        showBadgeCoachmark(shopList);
      } else if (elapsed >= LIMIT_MS) {
        if (fromTutorialCard) showNoBadgeCoachmark(shopList);
      } else {
        elapsed += STEP_MS;
        setTimeout(tick, STEP_MS);
      }
    };
    tick();
  };

  const shops = await EBFeed.loadFeed(market);
  if (!shops) return;

  if (window.location.hostname.includes("google.")) {
    decorateGooglePartners(shops);
    let timer;
    const observer = new MutationObserver(() => {
      clearTimeout(timer);
      timer = setTimeout(() => decorateGooglePartners(shops), 200);
    });
    observer.observe(document.body, { childList: true, subtree: true });
    // Only a results page (not the consent interstitial / home) is coached.
    if (location.pathname.startsWith("/search"))
      await maybeShowSearchCoachmark(shops);
    return;
  }

  const matchedId = EBFeed.matchKey(window.location.href, shops);
  if (!matchedId) return;

  if (await handlePendingReturn(matchedId)) return;

  // While `visitedPartner` is open, show the Banner even if closed earlier this
  // session, and coach it.
  const coachBanner = !(await getTutorialProgress()).visitedPartner;
  if (!coachBanner) {
    try {
      if (sessionStorage.getItem(SESSION_KEY) === "true") return;
    } catch (e) {}
  }

  showTopBanner(matchedId, shops);
  if (coachBanner) showBannerCoachmark();
})();

function reportHostPermission(api, force = false) {
  // Ask the background script to ping the host app on every page load so it can
  // live-verify Safari's website-access grant (content scripts can't read
  // permissions). Fire-and-forget. `force` re-pings even when nothing changed.
  if (!api.runtime || !api.runtime.sendMessage) return;
  Promise.resolve(
    api.runtime.sendMessage({ type: "report-permissions", origin: location.origin, force })
  ).catch(() => {});
}

// See TEST_PAGE_HOST at the top of the file.
async function markTestPage(api) {
  let hasAllUrls = false;
  try {
    ({ hasAllUrls } = await api.runtime.sendMessage({ type: "get-permissions" }));
  } catch (e) {}
  document.documentElement.dataset.ebfinderAccess = hasAllUrls ? "all" : "partial";
}
