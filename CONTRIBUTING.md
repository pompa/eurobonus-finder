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

- The version **is the release tag**. `scripts/cut-release.sh` tags the CalVer
  date, Xcode Cloud passes it as `$CI_TAG`, and the app, the extension manifest
  and the App Store listing all take their version from that one string. A
  build with no tag falls back to today's UTC date. Add Xcode Cloud's **build
  number** (`CFBundleVersion`) and both are stamped at build time by
  [`EB Finder/ci_scripts/ci_post_clone.sh`](EB%20Finder/ci_scripts/ci_post_clone.sh) — no tags, no
  version bumps, no release commits.
- The extension's `manifest.json` version is **derived from `MARKETING_VERSION`**
  by the "Stamp manifest version" Xcode build phase (defined in `project.yml`),
  so the app and extension always share one version — on local builds too. The
  committed `manifest.json` carries only a `0.0.0` placeholder.
- Xcode Cloud builds when you **cut a release** — `scripts/cut-release.sh`
  publishes a GitHub Release tagged with the CalVer date (e.g. `2026.6.5`, no
  `v` prefix) and the build uploads to TestFlight. Merging to `main` does not
  build.
- The **store listing** ships from the repo too — see below. The same tag that
  triggers the build also pushes the localized metadata and screenshots.
- "Releasing" is the final human step: promote the build and press **Submit for
  Review** in App Store Connect whenever you choose.

## Store listing

The App Store listing is version-controlled in [`fastlane/`](fastlane) and
uploaded by [`fastlane deliver`](https://docs.fastlane.tools/actions/deliver/) —
no typing into the App Store Connect web form. Full details:
[`fastlane/README.md`](fastlane/README.md).

- **Text** lives in `fastlane/metadata/<locale>/*.txt` — `en-US`, `sv`, `da`,
  `no`, `fi`, matching the languages the app itself ships. Edit the files, not
  the website.
- **Screenshots** are **not** committed — they are megabytes that regenerate in
  minutes. `fastlane screenshots` runs a UI test across every device and
  language in `fastlane/Snapfile`; the Safari banner shot is captured by hand
  (a UI test cannot enable the extension). Upload them with a local
  `fastlane metadata` run.
- **Review notes** for Apple's reviewer are in `fastlane/review_notes.txt` (a
  Safari extension needs turning on before a reviewer can see anything). The
  reviewer *contact* details are PII and stay out of the repo — they come from
  the `ASC_REVIEW_*` secrets, and review information is left untouched when
  they are unset.
- **"What's New"** is generated from the GitHub release by
  `scripts/release-notes.sh`; the committed `release_notes.txt` files are only
  a fallback.

Check the field limits before you commit — App Store subtitles cap at 30
characters, keywords at 100:

```sh
scripts/check-store-metadata.sh
```

The [App Store metadata workflow](.github/workflows/app-store-metadata.yml)
runs that check and then `fastlane metadata` on every CalVer tag, and can be
re-run by hand from the Actions tab for a typo fix. CI uploads the **text
only** — the lane uploads screenshots when they are on disk and skips them when
they are not, so CI can never wipe the live set. It needs four repository
secrets: `APP_BUNDLE_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8` (the
base64 of the App Store Connect API `.p8` key).

The lane deliberately **does not** submit for review — it keeps the listing
current and leaves the submit button to you (`submit_for_review:` in
[`fastlane/Fastfile`](fastlane/Fastfile)).

`MARKETING_VERSION` in
[`EB Finder/Config/Version.xcconfig`](EB%20Finder/Config/Version.xcconfig) is only
the fallback for local builds; shipped builds are stamped fresh from the date.
