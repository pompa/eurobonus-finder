#!/usr/bin/env bash
# Xcode Cloud post-clone: generate the Xcode project and stamp version + build number.
# Must sit next to the .xcodeproj; a repo-root ci_scripts is ignored.
#
# Workflow env vars (all optional except FEED_HOST):
#   FEED_HOST          partner feed host; the extension build fails without it
#   APP_BUNDLE_ID      real bundle id; unset builds com.example.ebfinder
#   DEVELOPMENT_TEAM   team id; unset leaves signing to Xcode Cloud
#   MARKETING_VERSION  version for a build without a tag (e.g. a manual start)

set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

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

# Git-ignored; included last by Config/Build.xcconfig, so its values win.
LOCAL_XCCONFIG="EuroBonus Finder/Config/Build.local.xcconfig"
: > "$LOCAL_XCCONFIG"

# Tag builds (Production) get the tag as version; others the workflow's
# MARKETING_VERSION, or else Build.xcconfig's 0.0.0.
if [[ -n "${CI_TAG:-}" ]]; then
  echo "==> MARKETING_VERSION = $CI_TAG"
  printf 'MARKETING_VERSION = %s\n' "$CI_TAG" >> "$LOCAL_XCCONFIG"
elif [[ -n "${MARKETING_VERSION:-}" ]]; then
  echo "==> MARKETING_VERSION = $MARKETING_VERSION (workflow env)"
  printf 'MARKETING_VERSION = %s\n' "$MARKETING_VERSION" >> "$LOCAL_XCCONFIG"
fi
echo "==> CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER"
printf 'CURRENT_PROJECT_VERSION = %s\n' "$CI_BUILD_NUMBER" >> "$LOCAL_XCCONFIG"

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

