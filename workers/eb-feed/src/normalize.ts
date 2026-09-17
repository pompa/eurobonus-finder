// Turns the two upstream SAS/Loyalty Key responses for one market into the
// feed the extension reads: one flat map keyed by what the extension matches on.

export const MARKETS = {
  se: { locale: "sv-SE", currency: "SEK", shopPath: "sv-SE/butiker" },
  no: { locale: "nb-NO", currency: "NOK", shopPath: "nb-NO/butikker" },
  dk: { locale: "da-DK", currency: "DKK", shopPath: "da-DK/butikker" },
  // Finland only exists upstream in English (fi-FI returns an empty list).
  fi: { locale: "en-FI", currency: "EUR", shopPath: "fi/shops" },
} as const;

export type Market = keyof typeof MARKETS;

/** `/api/browser-extension/sas/{locale}/shops`: domain (+ optional path) → shop uuid. */
export type DomainList = Record<string, string>;

/** The subset of `/api/v1/shops` fields we use. */
export interface UpstreamShop {
  uuid: string;
  name: string;
  slug: string;
  commission_type: string;
  points: number;
  points_campaign: number | null;
  has_campaign: number | boolean;
  campaign_ends_date: string | null;
}

export interface FeedEntry {
  id: string;
  name: string;
  type: "variable" | "fixed";
  points: number;
  campaign: boolean;
  campaignPoints: number | null;
  campaignEnds: string | null;
  url: string;
}

export interface Feed {
  schema: 1;
  market: Market;
  locale: string;
  currency: string;
  generatedAt: string;
  data: Record<string, FeedEntry>;
}

/**
 * Shops listed in the market's shop list but missing from upstream's domain
 * list (SAS's own extension doesn't match them either). Keyed by shop slug.
 * `no_domain` in the logs flags new gaps to add here.
 */
export const EXTRA_DOMAINS: Record<Market, Record<string, string[]>> = {
  se: { amazon: ["amazon.se"], electrolux: ["electrolux.se"] },
  no: { electrolux: ["electrolux.no"], sistie: ["sistie.no"] },
  // Saxo Boghandel shares saxo.com with Saxo Premium (upstream maps it to Premium).
  dk: { electrolux: ["electrolux.dk"], "saxo-boghandel": [] },
  fi: { "jd-sports-dk": ["jdsports.fi"] },
};

const LOCALE_SEGMENT =
  /^(se|no|dk|fi|sv|nb|nn|nor|da|en|eu|sweden|norway|denmark|finland|[a-z]{2}[-_][a-z]{2})$/;

/** "2026-09-20" or "20.09.2026" → "2026-09-20". */
export function isoDate(value: string | null): string | null {
  if (!value) return null;
  const iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  if (iso) return `${iso[1]}-${iso[2]}-${iso[3]}`;
  const eu = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(value);
  return eu ? `${eu[3]}-${eu[2]}-${eu[1]}` : null;
}

function toEntry(market: Market, shop: UpstreamShop): FeedEntry {
  const campaign = Boolean(shop.has_campaign);
  return {
    id: shop.uuid,
    name: shop.name,
    type: shop.commission_type === "fixed" ? "fixed" : "variable",
    points: shop.points,
    campaign,
    campaignPoints: campaign ? shop.points_campaign : null,
    campaignEnds: campaign ? isoDate(shop.campaign_ends_date) : null,
    url: `https://onlineshopping.flysas.com/${MARKETS[market].shopPath}/${shop.slug}/${shop.uuid}`,
  };
}

interface Candidate {
  host: string;
  segment: string; // first path segment, "" when none
  uuid: string;
}

/**
 * Keys are `host` or `host/firstSegment` (lowercase, no `www.`). The market
 * is already chosen by the file, so paths are dropped unless two different
 * shops share a host — then a non-locale path (bokus.com/play) keeps its own key.
 */
export function buildKeys(list: DomainList, log: (msg: object) => void = () => {}) {
  const byHost = new Map<string, Candidate[]>();
  for (const [raw, uuid] of Object.entries(list)) {
    const [hostPart = "", ...segments] = raw.trim().toLowerCase().split("/");
    const host = hostPart.replace(/^www\./, "").replace(/\.$/, "");
    if (!host) continue;
    const group = byHost.get(host) ?? [];
    group.push({ host, segment: segments.find(Boolean) ?? "", uuid });
    byHost.set(host, group);
  }

  const keys = new Map<string, string>();
  const claim = (key: string, candidates: Candidate[]) => {
    const uuids = [...new Set(candidates.map((c) => c.uuid))].sort();
    if (uuids.length > 1) log({ event: "duplicate_key", key, uuids });
    // Prefer a candidate whose path was locale-specific: it's the market's own entry.
    const preferred = candidates.find((c) => c.segment !== "") ?? candidates[0]!;
    keys.set(key, uuids.length > 1 ? preferred.uuid : uuids[0]!);
  };

  for (const [host, group] of byHost) {
    if (new Set(group.map((c) => c.uuid)).size === 1) {
      claim(host, group);
      continue;
    }
    const hostLevel = group.filter((c) => c.segment === "" || LOCALE_SEGMENT.test(c.segment));
    if (hostLevel.length) claim(host, hostLevel);
    const bySegment = Map.groupBy(
      group.filter((c) => !hostLevel.includes(c)),
      (c) => c.segment,
    );
    for (const [segment, candidates] of bySegment) claim(`${host}/${segment}`, candidates);
  }
  return keys;
}

export function normalize(
  market: Market,
  list: DomainList,
  shops: UpstreamShop[],
  generatedAt: string,
  log: (msg: object) => void = () => {},
): Feed {
  const byUuid = new Map(shops.map((s) => [s.uuid, s]));
  const listed = new Set(Object.values(list));
  const extra = EXTRA_DOMAINS[market];
  const merged: DomainList = { ...list };
  for (const shop of shops) {
    if (listed.has(shop.uuid)) continue;
    const domains = extra[shop.slug];
    if (!domains) log({ event: "no_domain", market, slug: shop.slug, uuid: shop.uuid });
    for (const domain of domains ?? []) merged[domain] ??= shop.uuid;
  }
  const data: Record<string, FeedEntry> = {};
  const keys = buildKeys(merged, log);
  for (const key of [...keys.keys()].sort()) {
    const shop = byUuid.get(keys.get(key)!);
    if (shop) data[key] = toEntry(market, shop);
    else log({ event: "missing_shop", market, key, uuid: keys.get(key) });
  }
  const { locale, currency } = MARKETS[market];
  return { schema: 1, market, locale, currency, generatedAt, data };
}

/** Hash of everything except `generatedAt`, so unchanged data isn't republished. */
export async function contentHash(feed: Feed): Promise<string> {
  const { generatedAt: _, ...content } = feed;
  const bytes = new TextEncoder().encode(JSON.stringify(content));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
