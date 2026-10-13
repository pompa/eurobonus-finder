#!/usr/bin/env bash
# Xcode Cloud post-clone: generate the Xcode project and stamp the version.
# Must sit next to the .xcodeproj; a repo-root ci_scripts is ignored.
#
# Workflow env vars (all optional except FEED_HOST):
#   FEED_HOST          partner feed host; the extension build fails without it
#   APP_BUNDLE_ID      real bundle id; unset builds com.example.ebfinder
#   DEVELOPMENT_TEAM   team id; unset leaves signing to Xcode Cloud

set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

VERSION_XCCONFIG="EuroBonus Finder/Config/Version.xcconfig"
XCODEGEN_VERSION="2.45.4"
WORK="${TMPDIR:-/tmp}"

# Pinned release binary, not Homebrew.
echo "==> Installing XcodeGen $XCODEGEN_VERSION"
curl -fsSL -o "$WORK/xcodegen.zip" \
  "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip"
unzip -q -o "$WORK/xcodegen.zip" -d "$WORK/xcodegen-dist"
XCODEGEN="$(find "$WORK/xcodegen-dist" -type f -name xcodegen | head -1)"
chmod +x "$XCODEGEN"
"$XCODEGEN" --version

echo "==> Stamping marketing version + build number"
# Tag builds use the tag; untagged builds use the next release's version.
if [[ -n "${CI_TAG:-}" ]]; then
  VERSION="$CI_TAG"
  echo "    from tag $CI_TAG"
else
  VERSION="$(git ls-remote --tags https://github.com/pompa/eurobonus-finder.git | scripts/next-version.sh)"
  echo "    no CI_TAG — the next release's version"
fi
echo "    MARKETING_VERSION = $VERSION"
sed -i.bak -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION/" "$VERSION_XCCONFIG"
rm -f "$VERSION_XCCONFIG.bak"

echo "==> Stamping CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER"
sed -i.bak -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER/" "$VERSION_XCCONFIG"
rm -f "$VERSION_XCCONFIG.bak"

# Git-ignored; included by Config/Build.xcconfig.
LOCAL_XCCONFIG="EuroBonus Finder/Config/Build.local.xcconfig"
: > "$LOCAL_XCCONFIG"
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  echo "==> Writing DEVELOPMENT_TEAM into Config/Build.local.xcconfig"
  printf 'DEVELOPMENT_TEAM = %s\n' "$DEVELOPMENT_TEAM" >> "$LOCAL_XCCONFIG"
else
  echo "==> DEVELOPMENT_TEAM not set — leaving signing to Xcode Cloud"
fi
if [[ -n "${APP_BUNDLE_ID:-}" ]]; then
  echo "==> Writing APP_BUNDLE_ID into Config/Build.local.xcconfig"
  printf 'APP_BUNDLE_ID = %s\n' "$APP_BUNDLE_ID" >> "$LOCAL_XCCONFIG"
else
  echo "==> APP_BUNDLE_ID not set — building with the placeholder bundle id"
fi

if [[ -n "${FEED_HOST:-}" ]]; then
  echo "==> Writing FEED_HOST into Config/Build.local.xcconfig"
  printf 'FEED_HOST = %s\n' "$FEED_HOST" >> "$LOCAL_XCCONFIG"
else
  echo "==> FEED_HOST not set — the extension build will fail"
fi

echo "==> Generating Xcode project from project.yml"
( cd "EuroBonus Finder" && "$XCODEGEN" generate )

echo "==> Final versioning state:"
grep -E "^(MARKETING_VERSION|CURRENT_PROJECT_VERSION)" "$VERSION_XCCONFIG"
