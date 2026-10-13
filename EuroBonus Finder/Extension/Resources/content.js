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
  const HINT_ROOT_ID = "ebfinder-hint-root";

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

    // Landed on the origin itself: nothing to replace, but it is a return.
    if (normalizeUrl(currentUrl) === normalizeUrl(pending.originalUrl)) {
      try {
        await api.storage.local.remove([key]);
      } catch (e) {}
      await stampTutorial("returned");
      return false;
    }

    const returnUrl = buildReturnUrl(pending.originalUrl, currentUrl);
    try {
      await api.storage.local.remove([key]);
    } catch (e) {}
    // The done dialog shows on the page we replace to (see showDoneDialog).
    await stampTutorial("returned");
    location.replace(returnUrl);
    return true;
  };

  // Button material: "flat" (HIG fills) or "glass" (Liquid Glass) — a class on
  // each surface, see styles.css.
  const BUTTON_STYLE = "flat";

  // Shadow-DOM surfaces (banner, coachmark) pull styles.css (tokens, primitives,
  // banner + coachmark) — NOT the popup stylesheet — so host pages
  // only download the CSS the injected UI actually uses.
  const SHADOW_STYLESHEETS = ["styles.css"];
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
    container.className = `banner ${BUTTON_STYLE}`;

    // Campaign: strike the regular points, then the campaign points in red.
    const campaign = !!(data.campaign && data.campaignPoints);
    const oldPoints = campaign
      ? `<s class="points-old">${EBFeed.formatPoints(data.points)}</s> `
      : "";
    const pointsSpan = `${oldPoints}<span class="points-highlight${campaign ? " is-campaign" : ""}">${t("points", { count: EBFeed.effectivePoints(data) })}</span>`;
    const desc = t("earn", {
      points: pointsSpan,
      suffix: EBFeed.suffix(data, market),
    });

    container.innerHTML = `
      <button class="btn btn-icon btn-sm btn-ghost tap banner-close" type="button" aria-label="${t("close")}">${XMARK}</button>
      <span class="eb-glyph">${ebIcon(40)}</span>
      <div class="banner-body">
        <div class="banner-title">${data.name || ""}</div>
        <div class="banner-desc">${desc}</div>
      </div>
      <a href="${data.url}" class="btn btn-primary btn-sm tap cta-btn">${t("activate")}</a>`;
    shadow.appendChild(container);

    // Same tab, so the SAS Shopping return lands back here. Persist first: a
    // storage write racing the unload could be lost.
    const ctaLink = shadow.querySelector(".cta-btn");
    if (ctaLink) {
      ctaLink.addEventListener("click", async (e) => {
        e.preventDefault();
        removeHint();
        await Promise.all([
          storePendingReturn(window.location.href, key),
          stampTutorial("activateTapped"),
        ]);
        window.location.href = data.url;
      });
    }

    const closeBtn = shadow.querySelector(".banner-close");
    if (closeBtn) {
      closeBtn.addEventListener("click", () => {
        removeHint();
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

    const bannerEl = banner.shadowRoot.querySelector(".banner");
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

  // Button glyphs — the standard Unicode characters (xmark / checkmark /
  // arrow.forward) in the system font, with our own SVG as backup when the
  // font has no glyph for them (detected against the .notdef width once).
  const GLYPH_FONT = "17px -apple-system, system-ui, sans-serif";
  const hasGlyph = (char) => {
    try {
      const ctx = document.createElement("canvas").getContext("2d");
      ctx.font = GLYPH_FONT;
      return ctx.measureText(char).width !== ctx.measureText("\ue000").width;
    } catch (e) {
      return false;
    }
  };
  const glyph = (char, svg) =>
    hasGlyph(char)
      ? `<span class="glyph" aria-hidden="true">${char}</span>`
      : `<span class="glyph" aria-hidden="true">${svg}</span>`;
  const XMARK = glyph(
    "\u00d7",
    '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M3.5 3.5l9 9M12.5 3.5l-9 9"/></svg>',
  );
  const CHECKMARK = glyph(
    "\u2713",
    '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 8.5l3.5 3.5 7.5-8"/></svg>',
  );
  const ARROW_FORWARD = glyph(
    "\u2192",
    '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 8h11M9 3.5 13.5 8 9 12.5"/></svg>',
  );

  // EB icon — the extension's own app icon PNG (flat artwork, reads well
  // small). One 128px asset serves the badge, banner and coachmark; the
  // manifest lists images/ as web-accessible so host pages may load it.
  const EB_ICON_URL = api.runtime.getURL("images/icon-128.png");
  const ebIcon = (size) =>
    `<img src="${EB_ICON_URL}" alt="" width="${size}" height="${size}" draggable="false" style="display:block;width:${size}px;height:${size}px">`;

  // The badge lives in Google's DOM (no shadow root): inline !important keeps
  // host-page CSS from disturbing its box. The span keeps an 18px layout box
  // so Google's rows don't reflow; the 20px icon is absolutely centred on it
  // and simply overflows.
  const BADGE_STYLE = [
    "display:inline-block !important",
    "width:18px !important",
    "height:18px !important",
    "overflow:visible !important",
    "vertical-align:middle !important",
    "background:transparent !important",
    "margin:0 0 0 6px !important",
    "padding:0 !important",
    "border:0 !important",
    "line-height:0 !important",
    "cursor:pointer !important",
    "user-select:none !important",
    "position:relative !important",
    "z-index:2147483646 !important",
    "opacity:1 !important",
  ].join(";");
  const BADGE_IMG_STYLE =
    "position:absolute !important;top:50% !important;left:50% !important;translate:-50% -50% !important;" +
    "display:block !important;width:20px !important;height:20px !important;max-width:none !important;border-radius:4px !important";

  const injectBadge = (target, matchedKey, shopList) => {
    const entry = shopList[matchedKey];
    if (!target || !target.parentNode) return;
    if (target.classList && target.classList.contains(BADGE_CLASS)) return;
    const next = target.nextElementSibling;
    if (next && next.classList && next.classList.contains(BADGE_CLASS)) return;

    const badge = document.createElement("span");
    badge.className = BADGE_CLASS;
    badge.dataset.ebHost = EBFeed.hostOfKey(matchedKey);
    badge.innerHTML = ebIcon(20);
    badge.firstChild.style.cssText = BADGE_IMG_STYLE;
    badge.title = t("badgeTitle", {
      name: entry.name,
      points: t("points", { count: EBFeed.effectivePoints(entry) }),
      suffix: EBFeed.suffix(entry, market),
    });
    badge.setAttribute("role", "link");
    badge.setAttribute("aria-label", t("badgeAria"));
    badge.setAttribute("tabindex", "0");
    badge.style.cssText = BADGE_STYLE;

    // To the partner site (same tab), where the Banner takes over.
    const activate = async (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (typeof e.stopImmediatePropagation === "function")
        e.stopImmediatePropagation();
      removeHint();
      await stampTutorial("badgeTapped");
      visitPartner(badge.dataset.ebHost);
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
  // TUTORIAL — coaches, in order: the Badge (Google), the Banner (partner
  // site), the Shop button (SAS Online Shopping), then a done dialog back on
  // the partner site. Progress is one `tutorial` object of stamps (see
  // background.js); a step is stamped by the real tap, never by closing a
  // Coachmark — closing swaps it for a Hint pointing at the thing to tap.
  // Tutorial mode is on until `finished` or `dismissed`.
  // ===========================================================================

  // Applies a pending Reset from the app first (capped: native messaging can be
  // slow), so a fresh start isn't coached from stale progress.
  const getTutorial = async () => {
    try {
      await Promise.race([
        api.runtime.sendMessage({ type: "sync-reset" }),
        new Promise((resolve) => setTimeout(resolve, 1000)),
      ]);
      const r = await api.storage.local.get(["tutorial"]);
      return r.tutorial || {};
    } catch (e) {
      return {};
    }
  };
  const tutorialActive = (tutorial) => !(tutorial.finished || tutorial.dismissed);

  const stampTutorial = async (step) => {
    // ponytail: always logs; gate on a dev build once the extension has a build step (Vite).
    console.info(`[EuroBonus Finder] tutorial: ${step}`);
    try {
      await api.runtime.sendMessage({ type: "stamp-tutorial", step });
    } catch (e) {}
  };

  // Calls onFound once `find()` returns something: now, or on the first DOM
  // mutation where it does (Google and SAS both hydrate async). No polling; one
  // observer, gone when found or after limitMs.
  const waitFor = (find, onFound, limitMs = 10000) => {
    const found = find();
    if (found) return onFound(found);
    let timer;
    const observer = new MutationObserver(() => {
      const el = find();
      if (!el) return;
      observer.disconnect();
      clearTimeout(timer);
      onFound(el);
    });
    observer.observe(document.documentElement, { childList: true, subtree: true, attributes: true });
    timer = setTimeout(() => observer.disconnect(), limitMs);
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

  const TUTORIAL_STEP_COUNT = 4;

  // Anchor for the unanchored Coachmarks (no-Badge, done): whole page blurred.
  const centerRect = () => ({
    left: window.innerWidth / 2,
    top: 72,
    right: window.innerWidth / 2,
    bottom: 72,
    width: 0,
    height: 0,
  });

  // Coachmark: an anchored popover for the Tutorial on a blurred overlay with a
  // rounded spotlight cut around the anchor. Own Shadow DOM (like the banner) so
  // host-page CSS can't reach it; position + spotlight track a live getRect().
  // Self-guards on COACH_ROOT_ID so the Google MutationObserver can't duplicate it.
  // `hint`: the same card stripped to one line — no overlay, glyph, title,
  // close or footer — that points at the thing the user should tap next.
  const createCoachmark = ({
    getRect,
    step,
    title,
    body,
    caption,
    ctaLabel,
    onCta,
    onClose,
    showGlyph,
    hideSkip,
    hint,
  }) => {
    const rootId = hint ? HINT_ROOT_ID : COACH_ROOT_ID;
    if (document.getElementById(rootId)) return null;

    const root = document.createElement("div");
    root.id = rootId;
    const shadow = root.attachShadow({ mode: "open" });
    attachShadowStyles(shadow);

    const overlay = document.createElement("div");
    overlay.className = "coach-overlay";
    if (!hint) shadow.appendChild(overlay);

    const card = document.createElement("div");
    card.className = `coach-card ${BUTTON_STYLE}${hint ? " coach-hint" : ""}`;
    const glyph = showGlyph ? `<span class="eb-glyph coach-glyph">${ebIcon(56)}</span>` : "";
    const dots = Array.from({ length: TUTORIAL_STEP_COUNT }, (_, i) => {
      const cls = i + 1 === step ? "is-active" : i + 1 < step ? "is-done" : "";
      return `<i class="${cls}"></i>`;
    }).join("");
    card.innerHTML = hint
      ? `<span class="coach-arrow"></span><p class="coach-body">${body}</p>`
      : `
      <span class="coach-arrow"></span>
      <button class="btn btn-icon btn-sm btn-secondary tap coach-close" type="button" aria-label="${t("close")}">${XMARK}</button>
      ${glyph}
      <p class="coach-title">${title}</p>
      <p class="coach-body">${body}</p>
      ${caption ? `<p class="coach-caption">${caption}</p>` : ""}
      <div class="coach-footer">
        <span class="coach-dots" aria-hidden="true">${dots}</span>
        ${hideSkip ? "" : `<button class="btn btn-ghost coach-skip" type="button">${t("coachSkip")}</button>`}
        <button class="btn btn-primary coach-cta" type="button">${ctaLabel}</button>
      </div>`;
    shadow.appendChild(card);

    const arrow = card.querySelector(".coach-arrow");

    const reposition = () => {
      const rect = getRect();
      if (!rect) return;
      const m = 12; // matches --gutter in styles.css
      // Layout size (offset*), not getBoundingClientRect(): the hidden card is
      // scaled 0.95, which would skew centring by a few px.
      const cw = card.offsetWidth || 300;
      const ch = card.offsetHeight || 120;
      const vw = window.innerWidth;
      const vh = window.innerHeight;

      // Spotlight = anchor + padding; the card sits off the spotlight's edge
      // with room for the arrow tip (a rotated 14px square protrudes ~10px)
      // plus a visible gap, so nothing touches.
      const pad = rect.width ? 6 : 0;
      const gap = pad + 10 + 8;

      // Prefer below the anchor; flip above only if it would overflow the bottom.
      let placement = "bottom";
      let top = rect.bottom + gap;
      if (top + ch > vh - m && rect.top - gap - ch > m) {
        placement = "top";
        top = rect.top - gap - ch;
      }
      // Center on the anchor, clamped to the viewport. The arrow's centre
      // tracks the anchor's centre (CSS translates it by -50%), kept clear of
      // the card's 24px rounded corners.
      const cx = rect.left + rect.width / 2;
      const left = Math.max(m, Math.min(cx - cw / 2, vw - cw - m));
      card.dataset.placement = placement;
      card.style.left = `${Math.round(left)}px`;
      card.style.top = `${Math.round(top)}px`;
      const inset = hint ? 20 : 34; // corner radius + arrow half-diagonal
      arrow.style.left = `${Math.round(Math.max(inset, Math.min(cx - left, cw - inset)))}px`;
      if (hint) return;

      // Spotlight: an evenodd path punches a rounded, padded hole around the
      // anchor (a zero-size rect = no hole, the whole page blurs).
      const x1 = rect.left - pad, y1 = rect.top - pad;
      const x2 = rect.right + pad, y2 = rect.bottom + pad;
      const r = Math.min(10, (x2 - x1) / 2, (y2 - y1) / 2);
      const arc = `A${r} ${r} 0 0 1`;
      overlay.style.clipPath =
        `path(evenodd, "M0 0H${vw}V${vh}H0Z` +
        `M${x1 + r} ${y1}H${x2 - r}${arc} ${x2} ${y1 + r}V${y2 - r}${arc} ${x2 - r} ${y2}` +
        `H${x1 + r}${arc} ${x1} ${y2 - r}V${y1 + r}${arc} ${x1 + r} ${y1}Z")`;
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
      // Fade out, then tear down once the transition finishes.
      overlay.classList.remove("is-visible");
      card.classList.remove("is-visible");
      let done = false;
      const cleanup = () => {
        if (done) return;
        done = true;
        root.remove();
      };
      card.addEventListener("transitionend", cleanup, { once: true });
      setTimeout(cleanup, 400);
    };

    if (!hint) {
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
      const skip = card.querySelector(".coach-skip");
      if (skip)
        skip.addEventListener("click", () => {
          remove();
          stampTutorial("dismissed");
        });
    }

    window.addEventListener("scroll", schedule, true);
    window.addEventListener("resize", schedule);
    if (typeof ResizeObserver === "function") {
      ro = new ResizeObserver(schedule);
      ro.observe(card);
    }

    // Measure once laid out (rect is valid even at opacity:0), then fade in.
    requestAnimationFrame(() => {
      reposition();
      requestAnimationFrame(() => {
        overlay.classList.add("is-visible");
        card.classList.add("is-visible");
      });
    });

    return { remove };
  };

  // One Hint at a time; the tap it asks for (or the banner closing) removes it.
  let currentHint = null;
  const showHint = (getRect, text) => {
    removeHint();
    currentHint = createCoachmark({ hint: true, getRect, body: text });
  };
  const removeHint = () => {
    if (currentHint) currentHint.remove();
    currentHint = null;
  };

  // Visit the partner in the same tab so the Banner (and its Coachmark) appear
  // on the page we land on.
  const visitPartner = (host) => {
    if (host) window.location.href = "https://" + cleanHost(host);
  };

  // Step 1: the Badge. Closing points a Hint at it; tapping it stamps `badgeTapped`.
  const showBadgeCoachmark = (badge) => {
    const icon = badge.firstElementChild || badge;
    const getRect = () => icon.getBoundingClientRect();
    const hint = () => showHint(getRect, t("hintBadge"));
    createCoachmark({
      getRect,
      step: 1,
      title: t("coachSearchTitle"),
      body: t("coachSearchBody"),
      ctaLabel: t("coachGotIt"),
      showGlyph: true,
      onCta: hint,
      onClose: hint,
    });
    // inline: "center" also centers it inside Google's horizontal product carousel.
    badge.scrollIntoView({ block: "center", inline: "center", behavior: "smooth" });
  };

  // No Badge showed up on the Tutorial card's search: point at a known partner
  // instead. Stamps nothing — the user still hasn't tapped a Badge.
  const showNoBadgeCoachmark = (shopList) => {
    const host = partnerHostFromShops(shopList);
    createCoachmark({
      getRect: centerRect,
      step: 1,
      title: t("coachEmptyTitle"),
      body: t("coachEmptyBody"),
      ctaLabel: t("coachSearchCta") + ARROW_FORWARD,
      showGlyph: true,
      onCta: () => visitPartner(host),
    });
  };

  // Step 2: the Banner. Closing points a Hint at Activate; tapping it stamps `activateTapped`.
  const showBannerCoachmark = () => {
    const bannerRoot = document.getElementById(ROOT_ID);
    const shadow = bannerRoot && bannerRoot.shadowRoot;
    const banner = shadow && shadow.querySelector(".banner");
    const cta = shadow && shadow.querySelector(".cta-btn");
    if (!banner || !cta) return;
    const hint = () => showHint(() => cta.getBoundingClientRect(), t("hintActivate"));
    createCoachmark({
      getRect: () => banner.getBoundingClientRect(),
      step: 2,
      title: t("coachBannerTitle"),
      body: t("coachBannerBody"),
      caption: t("coachCookieCaption"),
      ctaLabel: t("coachGotIt"),
      onCta: hint,
      onClose: hint,
    });
  };

  // Step 4: back on the partner site after the SAS Shopping return.
  const showDoneDialog = () => {
    createCoachmark({
      getRect: centerRect,
      step: 4,
      title: t("coachDoneTitle"),
      body: t("coachDoneBody"),
      ctaLabel: CHECKMARK + t("coachDoneCta"),
      showGlyph: true,
      hideSkip: true,
      onCta: () => stampTutorial("finished"),
      onClose: () => stampTutorial("finished"),
    });
  };

  // On a Google results page, coach the first Badge while `badgeTapped` is open.
  // With no Badge, only the Tutorial card's own search falls back to the no-Badge Coachmark.
  const maybeShowSearchCoachmark = async (shopList) => {
    const tutorial = await getTutorial();
    if (!tutorialActive(tutorial) || tutorial.badgeTapped) return;
    let found = false;
    waitFor(
      () => document.querySelector("." + BADGE_CLASS),
      (badge) => {
        found = true;
        showBadgeCoachmark(badge);
      },
      4000,
    );
    if (fromTutorialCard)
      setTimeout(() => {
        if (!found) showNoBadgeCoachmark(shopList);
      }, 4000);
  };

  // Step 3: SAS Online Shopping's shop page, reached from the Banner (a fresh
  // pending return for this shop's uuid, which ends the URL). Logged out (no
  // TOKEN cookie): Coachmark, then a Hint that Shop now logs in; the site sends
  // them back here afterwards. Logged in: just the Hint. Waits for the shop
  // button to hydrate and CookieScript's consent banner to close.
  const SAS_HOST = "onlineshopping.flysas.com";
  const SAS_SHOP_BUTTON = "section.info-section div.info-wrapper button.button";
  const maybeCoachSasShopPage = async (shopList) => {
    const uuid = location.pathname.split("/").filter(Boolean).pop();
    const key = Object.keys(shopList).find((k) => (shopList[k].url || "").endsWith("/" + uuid));
    if (!key) return;
    const stored = await api.storage.local.get([`${PENDING_KEY_PREFIX}${key}`]);
    const pending = stored[`${PENDING_KEY_PREFIX}${key}`];
    if (!pending || Date.now() - pending.timestamp > PENDING_TTL_MS) return;
    const tutorial = await getTutorial();
    if (!tutorialActive(tutorial) || tutorial.returned) return;

    const loggedIn = /(?:^|;\s*)TOKEN=/.test(document.cookie);
    const consentOpen = () => !!document.getElementById("cookiescript_injected");
    waitFor(
      () => !consentOpen() && document.querySelector(SAS_SHOP_BUTTON),
      (button) => {
        const getRect = () => (document.querySelector(SAS_SHOP_BUTTON) || button).getBoundingClientRect();
        const hint = () => showHint(getRect, t(loggedIn ? "hintShop" : "hintShopLogin"));
        if (loggedIn) return hint();
        createCoachmark({
          getRect,
          step: 3,
          title: t("coachSasTitle"),
          body: t("coachSasBody"),
          caption: t("coachCookieCaption"),
          ctaLabel: t("coachGotIt"),
          onCta: hint,
          onClose: hint,
        });
      },
      60000,
    );
    // Consent answered but no button after 10s (markup changed): coach
    // unanchored so the text still lands. Consent still open: the observer
    // above keeps waiting, so nothing covers the consent banner.
    setTimeout(() => {
      if (consentOpen() || document.getElementById(COACH_ROOT_ID) || document.getElementById(HINT_ROOT_ID)) return;
      createCoachmark({
        getRect: centerRect,
        step: 3,
        title: t("coachSasTitle"),
        body: t("coachSasBody"),
        caption: t("coachCookieCaption"),
        ctaLabel: t("coachGotIt"),
        showGlyph: true,
      });
    }, 10000);
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

  if (window.location.hostname === SAS_HOST) {
    await maybeCoachSasShopPage(shops);
    return;
  }

  const matchedId = EBFeed.matchKey(window.location.href, shops);
  if (!matchedId) return;

  if (await handlePendingReturn(matchedId)) return;

  const tutorial = await getTutorial();
  const active = tutorialActive(tutorial);
  if (active && tutorial.returned && !tutorial.finished) showDoneDialog();
  // While `activateTapped` is open, show the Banner even if closed earlier this
  // session, and coach it.
  const coachBanner = active && !tutorial.activateTapped;
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
