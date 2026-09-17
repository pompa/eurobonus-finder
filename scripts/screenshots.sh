#!/usr/bin/env bash
#
# Capture App Store screenshots from the iOS Simulator.
#
#   scripts/screenshots.sh en-US            # both devices
#   scripts/screenshots.sh sv --only iphone
#
# The script does everything fiddly — boot, install, the 9:41 status bar, the
# app language, opening the partner site — and pauses before each shot so you
# can set the screen up in the Simulator window. Press Enter to capture; the
# file lands in fastlane/screenshots/<locale>/ with the right name, and the
# pixel size is checked against the App Store slot.
#
# Screenshots are NOT committed (see .gitignore). Capture them here, then
# `fastlane metadata` uploads whatever is on disk.

set -euo pipefail

IPHONE="iPhone 17 Pro Max"   # 6.9" slot — 1320x2868
IPAD="iPad Pro 13-inch (M5)" # 13"  slot — 2064x2752
SITE="https://www.adidas.se/"  # a EuroBonus partner with a recognisable brand
SCHEME="EB Finder"
DERIVED="${TMPDIR:-/tmp}/ebf-screenshots"

locale="${1:-}"
only="both"
[ $# -gt 0 ] && shift
while [ $# -gt 0 ]; do
  case "$1" in
    --only) only="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$locale" ]; then
  cat >&2 <<'USAGE'
Usage: scripts/screenshots.sh <locale> [--only iphone|ipad]
  locale   App Store locale folder: en-US, sv, da, no, fi
USAGE
  exit 2
fi

cd "$(dirname "$0")/.."
out="fastlane/screenshots/$locale"
mkdir -p "$out"

# App Store locale -> the language the app should run in.
case "$locale" in
  en-US) lang=en ;;
  *)     lang="$locale" ;;
esac

udid_of() {
  xcrun simctl list devices available \
    | sed -n "s/^ *$1 (\([0-9A-F-]*\)) (.*/\1/p" | head -1
}

# --- build ------------------------------------------------------------------
app="$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)"
if [ -z "$app" ]; then
  echo "==> Building for the simulator (first run; cached afterwards)"
  ( cd "EB Finder" && xcodegen generate >/dev/null )
  xcodebuild -project "EB Finder/EB Finder.xcodeproj" -scheme "$SCHEME" \
    -configuration Debug -sdk iphonesimulator \
    -destination "platform=iOS Simulator,name=$IPHONE" \
    -derivedDataPath "$DERIVED" build >/dev/null
  app="$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' | head -1)"
fi
bundle="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")"
echo "==> App: $app ($bundle)"

capture() { # capture <udid> <file> <expected-w> <expected-h>
  xcrun simctl io "$1" screenshot "$2" >/dev/null 2>&1
  local got
  got="$(sips -g pixelWidth -g pixelHeight "$2" | awk '/pixel/{printf "%s", $2" "}')"
  if [ "$got" != "$3 $4 " ]; then
    echo "    !! $2 is ${got}px, the App Store slot wants $3x$4 — wrong device?" >&2
  else
    echo "    saved $2"
  fi
}

shoot() { # shoot <udid> <w> <h> <file> <instruction>
  printf '  %s\n     [Enter] capture   [s] skip > ' "$5"
  read -r answer
  [ "$answer" = "s" ] && { echo "    skipped"; return; }
  capture "$1" "$4" "$2" "$3"
}

run_device() { # run_device <name> <tag> <w> <h> <settings-shot?>
  local name="$1" tag="$2" w="$3" h="$4" with_settings="$5"
  local udid; udid="$(udid_of "$name")"
  if [ -z "$udid" ]; then
    echo "!! no available simulator named '$name' — check 'xcrun simctl list devices'" >&2
    return 1
  fi

  echo
  echo "=== $name ($locale) ==="
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl install "$udid" "$app"
  # Apple's 9:41 status bar: no stray clock or half-empty battery in the store.
  xcrun simctl status_bar "$udid" override --time "9:41" \
    --batteryState charged --batteryLevel 100 \
    --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4
  open -a "$(xcode-select -p)/Applications/Simulator.app" 2>/dev/null \
    || open -a Simulator 2>/dev/null \
    || echo "  (couldn't open the Simulator window — open it yourself to tap)"

  echo
  echo "  The banner shot needs the extension ON, once per simulator:"
  echo "    Settings > Apps > Safari > Extensions > EuroBonus Finder > Allow,"
  echo "    then Permissions > Other Websites > Allow."
  echo "  NOTE: a tap will NOT flip a switch in the Simulator — DRAG across it."
  [ "$lang" != "en" ] && echo "  For $lang, also set the DEVICE language (General > Language & Region):"
  [ "$lang" != "en" ] && echo "    the extension follows Safari, not the app's launch arguments."

  # Terminate + relaunch so Safari has no "< Settings" back affordance in the
  # status bar from whatever opened it.
  xcrun simctl terminate "$udid" com.apple.mobilesafari 2>/dev/null || true
  xcrun simctl openurl "$udid" "$SITE"
  sleep 4
  xcrun simctl terminate "$udid" com.apple.mobilesafari 2>/dev/null || true
  xcrun simctl launch "$udid" com.apple.mobilesafari >/dev/null
  sleep 3
  shoot "$udid" "$w" "$h" "$out/0_${tag}_banner.png" \
    "Safari on the partner site. Dismiss the cookie wall, scroll to a calm part of the page; the EB bar stays pinned at the top."

  xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
  xcrun simctl launch "$udid" "$bundle" -AppleLanguages "($lang)" >/dev/null
  sleep 3
  shoot "$udid" "$w" "$h" "$out/1_${tag}_welcome.png" \
    "App, onboarding welcome. (Already past it? Settings > Reset onboarding.)"
  shoot "$udid" "$w" "$h" "$out/2_${tag}_region.png" \
    "Tap Get Started -> the 'Choose your region' screen."

  if [ "$with_settings" = "yes" ]; then
    shoot "$udid" "$w" "$h" "$out/3_${tag}_settings.png" \
      "Finish onboarding -> the app's settings screen (Extension: On)."
  fi

  xcrun simctl status_bar "$udid" clear
}

if [ "$only" = "both" ] || [ "$only" = "iphone" ]; then
  run_device "$IPHONE" "iPhone69" 1320 2868 yes
fi
if [ "$only" = "both" ] || [ "$only" = "ipad" ]; then
  run_device "$IPAD" "iPad13" 2064 2752 no
fi

echo
echo "Done. $(find "$out" -name '*.png' | wc -l | tr -d ' ') screenshots in $out"
echo "Upload with:  fastlane metadata"
