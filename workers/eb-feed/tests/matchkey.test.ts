import { readFileSync } from "node:fs";
import { expect, test } from "vite-plus/test";

// feed.js ships to the extension as a plain script, so run it and read the global.
const src = readFileSync(
  new URL("../../../EuroBonus Finder/Extension/Resources/feed.js", import.meta.url),
  "utf8",
);
new Function(src)();
const { matchKey } = (globalThis as unknown as { EBFeed: any }).EBFeed;

const data = { "pnjakt.se": {}, "bokus.com": {}, "bokus.com/play": {}, "shop.example.se": {} };

test("any subdomain falls back to the partner's apex domain", () => {
  expect(matchKey("https://shop.pnjakt.se/produkt/1", data)).toBe("pnjakt.se");
  expect(matchKey("https://www.pnjakt.se/", data)).toBe("pnjakt.se");
  expect(matchKey("https://a.b.pnjakt.se/", data)).toBe("pnjakt.se");
  // Its own key wins over the apex, and path keys still beat the bare host.
  expect(matchKey("https://shop.example.se/", data)).toBe("shop.example.se");
  expect(matchKey("https://www.bokus.com/play/x", data)).toBe("bokus.com/play");
  expect(matchKey("https://shop.bokus.com/play/x", data)).toBe("bokus.com/play");
  expect(matchKey("https://notapartner.se/", data)).toBe(null);
  expect(matchKey("not a url", data)).toBe(null);
});
