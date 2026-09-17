// Builds the website (eurobonus.pompa.se) from the markdown in the repo, so the
// page and the repo never drift apart. One page per document per language:
//
//   README.md      → _site/index.html
//   README.sv.md   → _site/sv/index.html
//   PRIVACY.md     → _site/privacy/index.html      (the App Store privacy URL)
//   PRIVACY.sv.md  → _site/sv/privacy/index.html
//
// Markdown is rendered by GitHub's own API, so the site matches github.com. The
// page shell (styles, meta tags, analytics) is docs/template.html; everything
// else in docs/ (icons, badges, CNAME) is copied as-is.
//
// Usage: node scripts/build-site.mjs  (GITHUB_TOKEN optional; avoids rate limits)

import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";

const REPO = "pompa/eurobonus-finder";
const SITE = "https://eurobonus.pompa.se";
const OUT = "_site";
// `doc` groups the translations of one document: the language switch and the
// hreflang alternates link between siblings, not across every page on the site.
const PAGES = [
  { doc: "home", lang: "en", ogLocale: "en_US", readme: "README.md", path: "/" },
  { doc: "home", lang: "sv", ogLocale: "sv_SE", readme: "README.sv.md", path: "/sv/" },
  { doc: "privacy", lang: "en", ogLocale: "en_US", readme: "PRIVACY.md", path: "/privacy/" },
  { doc: "privacy", lang: "sv", ogLocale: "sv_SE", readme: "PRIVACY.sv.md", path: "/sv/privacy/" },
];
const pathOf = Object.fromEntries(PAGES.map((p) => [p.readme, p.path]));

async function renderMarkdown(text) {
  const res = await fetch("https://api.github.com/markdown", {
    method: "POST",
    headers: {
      accept: "application/vnd.github+json",
      "content-type": "application/json",
      ...(process.env.GITHUB_TOKEN && { authorization: `Bearer ${process.env.GITHUB_TOKEN}` }),
    },
    body: JSON.stringify({ text, mode: "markdown" }),
  });
  if (!res.ok) throw new Error(`GitHub markdown API: ${res.status} ${await res.text()}`);
  return res.text();
}

// README paths are repo-relative: images live in docs/ (the site root), the
// READMEs are pages on the site, and everything else points at GitHub.
function rewriteLinks(html) {
  return html
    .replace(/(src|href)="docs\/([^"]+)"/g, '$1="/$2"')
    .replace(/href="(?!https?:|mailto:|#|\/)([^"]+)"/g, (_, target) =>
      `href="${pathOf[target] ?? `https://github.com/${REPO}/blob/main/${target}`}"`,
    );
}

const text = (html) => html.replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim();
const attr = (s) => s.replace(/&/g, "&amp;").replace(/"/g, "&quot;");

const template = await readFile("docs/template.html", "utf8");
await rm(OUT, { recursive: true, force: true });
await cp("docs", OUT, { recursive: true, filter: (src) => !src.endsWith("template.html") });

for (const page of PAGES) {
  const siblings = PAGES.filter((p) => p.doc === page.doc);
  let html = rewriteLinks(await renderMarkdown(await readFile(page.readme, "utf8")));
  // The "Website" badge links to this very site — drop it here.
  html = html.replace(/<a href="https:\/\/eurobonus\.pompa\.se\/?"[^>]*>.*?<\/a>\s*/s, "");
  // Everything before the first section heading is the hero.
  const split = html.indexOf("<h2");
  html = `<header class="hero">${html.slice(0, split)}</header>\n${html.slice(split)}`;

  const title = text(html.match(/<h1[^>]*>(.*?)<\/h1>/s)[1]);
  // First paragraph after the title that isn't just links (language switch, badges).
  const description = [...html.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/g)]
    .map((m) => m[1])
    .find((p) => text(p.replace(/<a[\s\S]*?<\/a>/g, "")).length > 20);
  const vars = {
    lang: page.lang,
    ogLocale: page.ogLocale,
    title: attr(title),
    description: attr(text(description)),
    url: SITE + page.path,
    alternates: siblings.map((p) => `<link rel="alternate" hreflang="${p.lang}" href="${SITE + p.path}" />`).join("\n    "),
    langSwitch: siblings.map(
      (p) => `<a href="${p.path}" hreflang="${p.lang}"${p === page ? ' aria-current="page"' : ""}>${p.lang.toUpperCase()}</a>`,
    ).join(""),
    content: html,
  };
  const out = template.replace(/\{\{(\w+)\}\}/g, (_, key) => vars[key]);
  await mkdir(OUT + page.path, { recursive: true });
  await writeFile(`${OUT}${page.path}index.html`, out);
  console.log(`${page.readme} → ${OUT}${page.path}index.html`);
}
