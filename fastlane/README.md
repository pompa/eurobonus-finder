# App Store listing

```
metadata/<locale>/*.txt    listing text — committed
review_notes.txt           notes for Apple's reviewer — committed
screenshots/<locale>/      NOT committed, captured locally
Snapfile                   devices + languages for screenshots
```

Locales: `en-US`, `sv`, `da`, `no`, `fi`.

## Change the listing text

1. Edit the `.txt` files under `metadata/`.
2. `scripts/check-store-metadata.sh` — catches the limits Apple rejects for
   (subtitle 30 chars, keywords 100, a missing file).
3. Commit, then `fastlane metadata` to upload.

## Capture screenshots

1. **Once per simulator**, in Settings → Apps → Safari → Extensions → EuroBonus
   Finder: turn it on, then Permissions → Other Websites → Allow.
   *A tap will not flip a switch in the Simulator — drag across it.*
2. `fastlane screenshots` — runs a UI test for every device and language in the
   Snapfile and writes `screenshots/<language>/`.
3. Capture the three Safari shots by hand (no UI test can drive Safari or the
   Settings app). Name them so they sort first and match snapshot's convention,
   `<Device Name>-<order>_<name>.png`:
   - `0_banner` — a partner site, e.g. `https://www.adidas.se/`
   - `4_search` — `https://www.google.com/search?q=adidas&hl=en`
   - `5_popup` — the extension popup on a search page
4. `fastlane metadata` to upload.

For a non-English banner or search shot, set the **device** language too — the
extension follows Safari, not the app's launch arguments:

```bash
xcrun simctl spawn "$DEVICE" defaults write -g AppleLanguages -array sv
xcrun simctl shutdown "$DEVICE" && xcrun simctl boot "$DEVICE"
```

**Known issue:** every screenshot uploads twice and needs a manual dedupe in
App Store Connect. deliver verifies its upload against localizations it cached
*before* uploading, so each one looks missing, it retries, and the set lands
again.

## Versions

Xcode Cloud builds on a release tag, and the tag is the version everywhere:
`cut-release.sh` tags `2026.9.18` and `ci_post_clone.sh` stamps it into
`MARKETING_VERSION` and the extension's `manifest.json`. Set
`APP_STORE_VERSION` to that same tag when uploading the listing and it lands on
the matching version instead of whichever is editable. A same-day
`2026.9.18-2` tag drops the suffix.

"What's New" is generated from the GitHub release by
`scripts/release-notes.sh`; the committed `release_notes.txt` files are a
fallback. Version 1.0 has no "What's New" field — notes start at the first
update.

## Secrets

`APP_BUNDLE_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (base64 of the
`.p8`). Optionally `ASC_REVIEW_FIRST_NAME`, `ASC_REVIEW_LAST_NAME`,
`ASC_REVIEW_EMAIL`, `ASC_REVIEW_PHONE` — review contact details are PII and stay
out of the repo; unset, review information is left untouched.

The lane never submits for review.
