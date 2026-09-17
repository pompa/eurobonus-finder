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

Screenshots are captured against the Simulator and **kept out of the repo** —
they are ~12 MB per locale and regenerate in minutes.

```bash
scripts/screenshots.sh en-US              # both devices
scripts/screenshots.sh sv --only iphone
```

The script boots the simulator, installs the app, sets Apple's 9:41 status bar,
opens the partner site, and pauses before each shot so you can set the screen
up; Enter captures it at the right size and filename.

Two things it cannot do for you, both once per simulator:

- **Turn the extension on** — Settings → Apps → Safari → Extensions → EuroBonus
  Finder → Allow, then Permissions → Other Websites → Allow. A tap will *not*
  flip a switch in the Simulator; drag across it.
- **Set the device language** for a non-English banner shot — the extension
  follows Safari, not the app's launch arguments.

Then upload from the same machine:

```bash
APP_BUNDLE_ID=... ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_P8="$(base64 -i key.p8)" \
  fastlane metadata
```

The lane uploads screenshots when they are on disk and skips them when they are
not — so CI pushes text only, and a local run pushes both.

`en-US` is the complete set; the other locales are the same loop with the
language switched, and can land one at a time.
