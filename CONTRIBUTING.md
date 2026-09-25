# Contributing

The project is in early alpha. Open a GitHub issue for bugs, and before
starting a PR so we can discuss the change first.

## Set up

1. `brew install xcodegen`
2. Create `EuroBonus Finder/Config/Build.local.xcconfig` (git-ignored). It
   overrides the placeholders in `Config/Build.xcconfig`:

   ```
   FEED_HOST = feed.example.com
   DEVELOPMENT_TEAM = YOURTEAMID
   APP_BUNDLE_ID = com.yourcompany.ebfinder
   ```

   `FEED_HOST` is required — the build fails with a hint without it (see
   [Partner feed](#partner-feed)). The signing lines are only needed to run on
   a physical device; the simulator needs no signing.

3. ```sh
   cd "EuroBonus Finder"
   xcodegen generate
   open "EuroBonus Finder.xcodeproj"
   ```

Re-run `xcodegen generate` after pulling changes to `project.yml`. The
`.xcodeproj` is generated, never committed, so it cannot cause a merge conflict.

`APP_BUNDLE_ID` is the single root: the extension is `$(APP_BUNDLE_ID).extension`
and the app group is `group.$(APP_BUNDLE_ID)`.

## Release

1. `scripts/cut-release.sh` — publishes a GitHub Release tagged with today's
   CalVer date (`2026.9.18`, no `v` prefix).
2. The tag triggers the Xcode Cloud build, which archives and uploads it.
3. Push the store listing with `fastlane metadata` (see
   [`fastlane/README.md`](fastlane/README.md)).
4. Attach the build and press **Submit for Review** in App Store Connect.

The tag is the version — it becomes `MARKETING_VERSION`, the extension's
`manifest.json` version and the App Store version. Nothing to bump, no release
commits. `Config/Version.xcconfig` only holds a fallback for local builds.

## Store listing

Listing text, review notes and screenshots live in [`fastlane/`](fastlane) and
upload with `fastlane` — never typed into the App Store Connect web form. See
[`fastlane/README.md`](fastlane/README.md).

## Partner feed

The extension never calls SAS directly. A Cloudflare Worker in
[`workers/eb-feed`](workers/eb-feed) fetches the public partner data nightly and
publishes one JSON file per market to an R2 bucket. Its
[README](workers/eb-feed/README.md) covers running your own copy.

## Website

[eurobonus.pompa.se](https://eurobonus.pompa.se) is generated from `README.md`,
`README.sv.md`, `PRIVACY.md` and `PRIVACY.sv.md` — edit those, not HTML, and
keep the language pairs in sync. The page shell is `docs/template.html`; the
[Pages workflow](.github/workflows/pages.yml) rebuilds on push to `main`.

Preview locally:

```sh
node scripts/build-site.mjs --serve
```
