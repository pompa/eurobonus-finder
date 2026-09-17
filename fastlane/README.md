# App Store listing

The listing lives here and is uploaded by `fastlane deliver` — nothing is typed
into the App Store Connect web form.

```
metadata/<locale>/*.txt       the listing text — committed
metadata/review_information/  notes for Apple's reviewer — committed
screenshots/<locale>/*.png    NOT committed (gitignored); captured locally
```

Locales: `en-US`, `sv`, `da`, `no`, `fi` — the languages the app itself ships.

## Changing the text

Edit the `.txt` files, then:

```bash
scripts/check-store-metadata.sh
```

It catches the things Apple rejects an upload for — a subtitle over 30
characters, keywords over 100, a locale missing a file.

The [App Store metadata workflow](../.github/workflows/app-store-metadata.yml)
runs that check and uploads on every CalVer tag, and can be re-run by hand from
the Actions tab for a typo fix.

## Shipping a build

Xcode Cloud is not set up on this account, so builds are archived and uploaded
from a developer machine:

```bash
APP_BUNDLE_ID=... ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_P8="$(base64 -i key.p8)" \
  fastlane release version:2026.9.18 build:1
```

It fetches App Store provisioning profiles, switches the Release configuration
to manual signing, archives, exports and uploads. Bump `build:` for another
upload of the same version — App Store Connect rejects a repeated build number.

**Manual signing is deliberate.** Under automatic signing Xcode signs an
*archive* for development and only re-signs at export, and creating a
development profile needs at least one registered device — which a release
machine has none of ("Your team has no devices from which to generate a
provisioning profile"). App Store profiles need no devices.

### One-time Developer Portal setup

The App Store Connect API has no App Groups endpoint, so this part cannot be
scripted. At [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list/applicationGroup):

1. **Identifiers → App Groups** → register `group.<APP_BUNDLE_ID>`.
2. **Identifiers → App IDs → `<APP_BUNDLE_ID>`** → enable **App Groups** →
   Edit → tick that group → Save.
3. Repeat for `<APP_BUNDLE_ID>.extension`.

Both targets declare the group in their `.entitlements`, so without this the
profiles omit the entitlement and codesign fails.

## Versions

The release tag is the version, everywhere: `cut-release.sh` tags `2026.9.17`,
`ci_post_clone.sh` stamps that into `MARKETING_VERSION` (and so into the
extension's `manifest.json`), and this workflow passes the same string as
`APP_STORE_VERSION` so the listing lands on the matching App Store version
rather than whichever one happens to be editable.

A second release on the same day is tagged `2026.9.17-2`; the suffix is
stripped for the version itself, since `CFBundleShortVersionString` must be one
to three integers and the build number already makes same-day builds unique.

## Release notes

`release_notes.txt` ("What's New") is generated from the GitHub release, so the
changelog is written once:

```bash
scripts/release-notes.sh --print      # preview the latest release
scripts/release-notes.sh 2026.9.17    # write it to every locale
```

It keeps the PR titles, drops the `by @user in <url>` noise, and drops what a
shopper does not care about — `chore`, `docs`, `refactor`, and anything scoped
to `ci`/`build`/`deps`. The release workflow runs it before uploading, so the
committed files are only a fallback.

The lines are English in every locale; nothing in the pipeline can translate
them. To ship translated notes, edit the per-locale files by hand and don't run
this script for that release.

Note that **version 1.0 has no "What's New" field** — App Store Connect only
shows it from the first update onward, so release notes start mattering at 1.1.

## Screenshots

Screenshots are **kept out of the repo** (gitignored) — megabytes that
regenerate in minutes.

### The app screens — automated

```bash
fastlane screenshots
```

[`Snapfile`](Snapfile) holds the devices and languages; `snapshot` re-runs the
UI test in [`EuroBonus Finder/UITests/ScreenshotTests.swift`](../EuroBonus%20Finder/UITests/ScreenshotTests.swift)
for every combination — 2 devices x 5 languages — and files the results under
`screenshots/<language>/`. Adding a language is one line in the Snapfile.

It also sets Apple's 9:41 status bar (`override_status_bar`) and reinstalls the
app each run, so no stray clock or half-drawn screen reaches the store.

**Enable the extension on each simulator before the first run** (steps below).
Otherwise the settings screenshot shows "Extension: Off" with a warning icon —
accurate, but not what you want in the App Store. Enabling it is a Safari
setting that survives `reinstall_app`, so it is a once-per-simulator job, and
it is the same step the banner shot needs anyway.

The test finds the onboarding button by the accessibility identifier
`onboarding.cta`, never by its title — the titles are localized. It starts the
app past onboarding for the settings shot by passing `-hasCompletedOnboarding
YES`, which lands in `UserDefaults` and so in the app's `@AppStorage` without
any test-only code in the app.

### The Safari banner — by hand

The banner shot is the product, and no UI test can take it: it needs the
extension enabled in Settings and a real partner site in Safari. Per simulator,
once:

1. Settings → Apps → Safari → Extensions → EuroBonus Finder → Allow, then
   Permissions → Other Websites → Allow. **A tap will not flip a switch in the
   Simulator — drag across it.**
2. For a non-English shot, set the *device* language (General → Language &
   Region). The extension follows Safari, not the app's launch arguments.

Then:

```bash
DEVICE=$(xcrun simctl list devices available | sed -n 's/^ *iPhone 17 Pro Max (\([0-9A-F-]*\)) (.*/\1/p' | head -1)
xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryState charged \
  --batteryLevel 100 --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4
xcrun simctl openurl "$DEVICE" https://www.adidas.se/
# dismiss the site's cookie wall, then relaunch Safari so the status bar has no
# "< Settings" back affordance left over from whatever opened it:
xcrun simctl terminate "$DEVICE" com.apple.mobilesafari
xcrun simctl launch "$DEVICE" com.apple.mobilesafari
xcrun simctl io "$DEVICE" screenshot "fastlane/screenshots/en-US/iPhone 17 Pro Max-0_banner.png"
```

Match snapshot's naming — `<Device Name>-<order>_<name>.png`, spaces and all,
exactly as the files it writes are named — so the shot sorts before
`1_welcome` and lands in the right App Store device slot.

On iPhone the banner renders its **compact** form (short title, "Earn"): the
`@container (max-width: 720px)` rule in `content.css` drops the points line at
any phone width. The iPad shot is the one showing the full "Earn 25 points per
100 kr". Both are honest; that is the real product at each width.

### Uploading

```bash
APP_BUNDLE_ID=... ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_P8="$(base64 -i key.p8)" \
  fastlane metadata
```

The lane uploads screenshots when they are on disk and skips them when they are
not — so CI pushes text only, and a local run pushes both.

**Known issue:** every screenshot uploads twice and needs a manual dedupe in
App Store Connect. deliver verifies its upload against localization objects it
cached *before* uploading, so each fresh screenshot looks missing, it retries,
and the set lands again. Reproduces every run, unaffected by
`overwrite_screenshots`; deliver's `sync_screenshots` beta path avoids the loop
but crashes on its own processing check and fails the whole lane.
