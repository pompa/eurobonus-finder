import { expect, test } from "vite-plus/test";
import { buildKeys, contentHash, isoDate, normalize, type UpstreamShop } from "../src/normalize.ts";

const shop = (uuid: string, extra: Partial<UpstreamShop> = {}): UpstreamShop => ({
  uuid,
  name: uuid,
  slug: uuid,
  commission_type: "variable",
  points: 25,
  points_campaign: 0,
  has_campaign: 0,
  campaign_ends_date: null,
  ...extra,
});

test("keys drop www, locale and landing-page paths", () => {
  const keys = buildKeys({
    "www.bjornborg.com/se": "bb",
    "Nelly.com/se": "nelly",
    "www.adlibris.com/se": "ad",
    "www.adlibris.com/sv": "ad",
    "example.no/shop/frontpage.html": "ex",
  });
  expect(Object.fromEntries(keys)).toEqual({
    "bjornborg.com": "bb",
    "nelly.com": "nelly",
    "adlibris.com": "ad",
    "example.no": "ex",
  });
});

test("different shops on one host keep non-locale paths", () => {
  const keys = buildKeys({ "www.bokus.com": "bokus", "www.bokus.com/play": "play" });
  expect(Object.fromEntries(keys)).toEqual({ "bokus.com": "bokus", "bokus.com/play": "play" });
});

test("duplicate shops on one host prefer the locale-specific entry", () => {
  const logged: object[] = [];
  const keys = buildKeys({ "www.jlindeberg.com": "a", "www.jlindeberg.com/sv-se": "b" }, (m) =>
    logged.push(m),
  );
  expect(Object.fromEntries(keys)).toEqual({ "jlindeberg.com": "b" });
  expect(logged).toHaveLength(1);
});

test("dates normalize to ISO", () => {
  expect(isoDate("2026-09-20")).toBe("2026-09-20");
  expect(isoDate("20.09.2026")).toBe("2026-09-20");
  expect(isoDate("om 2 dagar")).toBeNull();
  expect(isoDate(null)).toBeNull();
});

test("normalize builds campaign entries and skips unknown shops", () => {
  const feed = normalize(
    "no",
    { "www.bjornborg.com/se": "bb", "gone.no": "missing" },
    [
      shop("bb", {
        name: "Björn Borg",
        slug: "bjorn-borg",
        points_campaign: 50,
        has_campaign: 1,
        campaign_ends_date: "20.09.2026",
      }),
    ],
    "2026-09-17T03:00:00.000Z",
  );
  expect(feed).toEqual({
    schema: 1,
    market: "no",
    locale: "nb-NO",
    currency: "NOK",
    generatedAt: "2026-09-17T03:00:00.000Z",
    data: {
      "bjornborg.com": {
        id: "bb",
        name: "Björn Borg",
        type: "variable",
        points: 25,
        campaign: true,
        campaignPoints: 50,
        campaignEnds: "2026-09-20",
        url: "https://onlineshopping.flysas.com/nb-NO/butikker/bjorn-borg/bb",
      },
    },
  });
});

test("hash ignores generatedAt", async () => {
  const a = normalize("se", { "a.se": "a" }, [shop("a")], "2026-01-01T00:00:00Z");
  const b = normalize("se", { "a.se": "a" }, [shop("a")], "2026-01-02T00:00:00Z");
  const c = normalize("se", { "a.se": "a" }, [shop("a", { points: 30 })], "2026-01-02T00:00:00Z");
  expect(await contentHash(a)).toBe(await contentHash(b));
  expect(await contentHash(a)).not.toBe(await contentHash(c));
});

test("shops missing from the domain list get their override domain", () => {
  const logged: object[] = [];
  const feed = normalize(
    "se",
    { "cdon.se": "cdon" },
    [shop("cdon"), shop("amz", { slug: "amazon" }), shop("x", { slug: "unknown-shop" })],
    "2026-09-17T03:00:00.000Z",
    (m) => logged.push(m),
  );
  expect(Object.keys(feed.data)).toEqual(["amazon.se", "cdon.se"]);
  expect(logged).toEqual([{ event: "no_domain", market: "se", slug: "unknown-shop", uuid: "x" }]);
});
