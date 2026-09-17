import { MARKETS, type DomainList, type Market, type UpstreamShop } from "./normalize.ts";

const API = "https://onlineshopping.loyaltykey.com/api";

async function getJson<T>(url: string): Promise<T> {
  const res = await fetch(url, {
    headers: { accept: "application/json", "user-agent": "eb-feed (+https://eurobonus.pompa.se)" },
  });
  // Unknown locales come back as an HTML 404 page, not JSON.
  if (!res.ok || !res.headers.get("content-type")?.includes("application/json")) {
    throw new Error(`${res.status} ${res.headers.get("content-type")} from ${url}`);
  }
  return (await res.json()) as T;
}

export async function fetchSources(market: Market) {
  const { locale } = MARKETS[market];
  const [language, country] = locale.split("-") as [string, string];
  const shopsUrl = new URL(`${API}/v1/shops`);
  shopsUrl.searchParams.set("filter[channel]", "SAS");
  shopsUrl.searchParams.set("filter[language]", language);
  shopsUrl.searchParams.set("filter[country]", country);
  // Without `amount` the API paginates at 32; `compressed` must be absent
  // (any value but "0" strips points and campaign fields).
  shopsUrl.searchParams.set("filter[amount]", "5000");

  const [list, shops] = await Promise.all([
    getJson<DomainList>(`${API}/browser-extension/sas/${locale}/shops`),
    getJson<{ data: UpstreamShop[] }>(shopsUrl.href),
  ]);
  return { list, shops: shops.data };
}
