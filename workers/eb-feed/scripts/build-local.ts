// Fetches and normalizes every market into ./out/ without touching R2.
// The deployed Workflow (src/index.ts) runs the same code and uploads the result.
import { mkdir, writeFile } from "node:fs/promises";
import { MARKETS, contentHash, normalize, type Market } from "../src/normalize.ts";
import { fetchSources } from "../src/upstream.ts";

await mkdir("out", { recursive: true });
for (const market of Object.keys(MARKETS) as Market[]) {
  const { list, shops } = await fetchSources(market);
  const feed = normalize(market, list, shops, new Date().toISOString(), (msg) => console.warn(msg));
  await writeFile(`out/${market}.json`, JSON.stringify(feed));
  console.log(market, Object.keys(feed.data).length, "entries", await contentHash(feed));
}
