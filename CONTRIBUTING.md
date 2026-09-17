# Contributing

A proper contributor guide is coming. The project is still in early alpha and
the workflow is being figured out as we go.

In the meantime:

- **Bug reports and feedback** — open a GitHub issue.
- **Code contributions** — open a GitHub issue first so we can discuss the
  change before you spend time on a PR.

## Building the app

The Xcode project is **generated** from [`EB Finder/project.yml`](EB%20Finder/project.yml)
with [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `EB Finder.xcodeproj` is
not committed, so it can never cause a merge conflict.

```sh
brew install xcodegen          # once
cd "EB Finder"
xcodegen generate              # writes EB Finder.xcodeproj (git-ignored)
open "EB Finder.xcodeproj"
```

Re-run `xcodegen generate` from the `EB Finder/` folder whenever you pull changes
that touch `project.yml`. Versions are automatic — see [Releases](#releases)
below; [`EB Finder/Config/Version.xcconfig`](EB%20Finder/Config/Version.xcconfig)
only holds the local fallback.

The project ships **without a signing identity and with a placeholder bundle id**
(`com.example.ebfinder`) so anyone can build it. To run on a **physical device**,
drop your Apple Developer team and your own bundle id into a git-ignored
`EB Finder/Config/Signing.local.xcconfig`:

```
DEVELOPMENT_TEAM = YOURTEAMID
APP_BUNDLE_ID = com.yourcompany.ebfinder
```

`APP_BUNDLE_ID` is the single root: the extension is `$(APP_BUNDLE_ID).extension`
and the shared app group is `group.$(APP_BUNDLE_ID)`.

Simulator builds need no signing. (Xcode Cloud injects its own signing, and
`APP_BUNDLE_ID` via a workflow environment variable, for releases.)

Every build needs the host serving the partner feed. It's kept out of the repo,
so add it to a git-ignored `EB Finder/Config/Feed.local.xcconfig`:

```
FEED_HOST = feed.example.com
```

The build fails with a hint if it's missing. See [Partner feed](#partner-feed).

## Partner feed

The extension doesn't call SAS directly. A Cloudflare Worker in
[`workers/eb-feed`](workers/eb-feed) fetches the public partner data nightly and
publishes one JSON file per market to an R2 bucket. See its
[README](workers/eb-feed/README.md) to develop it or run your own copy.

## Website

[eurobonus.pompa.se](https://eurobonus.pompa.se) is generated from `README.md`
(English) and `README.sv.md` (Swedish) — edit those, not HTML. Keep both READMEs
in sync. The page shell (styles, meta tags, analytics) is `docs/template.html`;
the [Pages workflow](.github/workflows/pages.yml) rebuilds on push to `main`.

Preview locally:

```sh
node scripts/build-site.mjs && python3 -m http.server -d _site
```

## Releases

There's nothing to manage — **versions are calendar-based and fully automatic**:

- The version is the **UTC build date** (`CFBundleShortVersionString`, e.g.
  `2026.6.4`) plus Xcode Cloud's **build number** (`CFBundleVersion`). Both are
  stamped at build time by
  [`EB Finder/ci_scripts/ci_post_clone.sh`](EB%20Finder/ci_scripts/ci_post_clone.sh) — no tags, no
  version bumps, no release commits.
- The extension's `manifest.json` version is **derived from `MARKETING_VERSION`**
  by the "Stamp manifest version" Xcode build phase (defined in `project.yml`),
  so the app and extension always share one version — on local builds too. The
  committed `manifest.json` carries only a `0.0.0` placeholder.
- Xcode Cloud builds when you **cut a release** — push a `v*` tag (e.g.
  `gh release create v2026.6.5 --generate-notes`) and the build uploads to
  TestFlight. Merging to `main` does not build.
- "Releasing" is just promoting a build to TestFlight or the App Store from App
  Store Connect whenever you choose — the repo plays no part in shipping.

`MARKETING_VERSION` in
[`EB Finder/Config/Version.xcconfig`](EB%20Finder/Config/Version.xcconfig) is only
the fallback for local builds; shipped builds are stamped fresh from the date.
