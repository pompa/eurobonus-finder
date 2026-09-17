#!/usr/bin/env bash
#
# cut-release.sh — cut a TestFlight release.
#
# Publishes a GitHub Release whose tag (matching v*) is the start condition for
# the "EB Finder | Releases" Xcode Cloud workflow. Xcode Cloud then archives,
# signs, and uploads the build to TestFlight.
#
# The tag only TRIGGERS the build and is a human-readable marker — it does NOT
# set the app version. The version is stamped at build time by
# EB Finder/ci_scripts/ci_post_clone.sh (marketing = UTC build date YYYY.M.D,
# build number = $CI_BUILD_NUMBER).
#
# Usage:
#   scripts/cut-release.sh            # tag the tip of main as vYYYY.M.D (UTC)
#   scripts/cut-release.sh 2026.7.1   # use an explicit version
#   scripts/cut-release.sh -y         # skip the confirmation prompt
#
# Requires the GitHub CLI (`gh`), authenticated. Everything goes over the GitHub
# API (HTTPS) — no `git push`, so it's unaffected by local SSH setup.

set -euo pipefail

REPO="pompa/eurobonus-finder"
BRANCH="main"

assume_yes=false
version=""
for arg in "$@"; do
  case "$arg" in
    -y|--yes) assume_yes=true ;;
    -h|--help)
      cat >&2 <<'USAGE'
Usage: scripts/cut-release.sh [VERSION] [-y]
  Cut a TestFlight release: publish a GitHub Release whose v* tag triggers the
  "EB Finder | Releases" Xcode Cloud workflow (archive -> sign -> TestFlight).

  VERSION   explicit version, e.g. 2026.7.1 (default: UTC date YYYY.M.D)
  -y,--yes  skip the confirmation prompt
USAGE
      exit 0 ;;
    -*) echo "error: unknown option: $arg" >&2; exit 2 ;;
    *)  version="$arg" ;;
  esac
done

command -v gh >/dev/null 2>&1 || {
  echo "error: gh CLI not found — install from https://cli.github.com" >&2
  exit 1
}

# Calendar version = UTC date with no leading zeros (matches ci_post_clone.sh).
# 10# forces base-10 so a leading-zero month/day (08, 09) doesn't trip bash.
if [ -z "$version" ]; then
  version="$(date -u +%Y).$((10#$(date -u +%m))).$((10#$(date -u +%d)))"
fi
base_tag="v$version"
tag="$base_tag"

tag_exists() { gh api "repos/$REPO/git/ref/tags/$1" >/dev/null 2>&1; }

# A second release on the same calendar day would collide on the tag name; append
# a numeric suffix so each release stays unique and readable. (The build number
# still disambiguates the actual build, and the app version stays calendar-based.)
if tag_exists "$tag"; then
  n=2
  while tag_exists "${base_tag}-${n}"; do n=$((n + 1)); done
  tag="${base_tag}-${n}"
  echo "note: $base_tag already exists — cutting $tag instead"
fi

# Tag the tip of main on the remote, so we always release the merged state
# regardless of the local checkout.
target="$(gh api "repos/$REPO/commits/$BRANCH" --jq .sha)"

echo "Release : $tag"
echo "Repo    : $REPO"
echo "Commit  : ${target:0:12} (tip of $BRANCH)"
echo "Effect  : triggers the 'EB Finder | Releases' Xcode Cloud build -> TestFlight"

if [ "$assume_yes" != true ]; then
  printf "Cut this release? [y/N] "
  read -r reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "aborted."; exit 0 ;;
  esac
fi

gh release create "$tag" \
  --repo "$REPO" \
  --target "$target" \
  --title "$tag" \
  --generate-notes

echo
echo "Cut $tag. Xcode Cloud is building it; the archive will upload to TestFlight."
echo "  Build status : https://github.com/$REPO/commits/$BRANCH"
echo "  TestFlight   : App Store Connect -> your app -> TestFlight"
