#!/usr/bin/env bash
#
# cut-release.sh — cut a TestFlight release.
#
# Publishes a GitHub Release whose CalVer tag (YYYY.MM.PATCH, no "v" prefix) is
# the start condition for the Production workflow in Xcode Cloud. Xcode Cloud
# then archives, signs, and uploads the build to TestFlight. Push the store
# listing separately with `fastlane metadata` (see fastlane/README.md).
#
# The tag is the version: ci_post_clone.sh stamps it into MARKETING_VERSION,
# and Xcode Cloud's $CI_BUILD_NUMBER becomes the build number. PATCH counts the
# month's releases from 0 — see scripts/next-version.sh.
#
# Usage:
#   scripts/cut-release.sh            # tag the tip of main as the next version
#   scripts/cut-release.sh 2026.7.1   # use an explicit version
#   scripts/cut-release.sh -y         # skip the confirmation prompt
#
# Requires the GitHub CLI (`gh`), authenticated. Everything goes over HTTPS (the
# GitHub API, and `git ls-remote` for tags) — no SSH, no `git push`.

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
  Cut a release: publish a GitHub Release whose CalVer tag triggers the
  Production workflow in Xcode Cloud (archive -> sign -> TestFlight).

  VERSION   explicit version, e.g. 2026.7.1 (default: next YYYY.MM.PATCH)
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

if [ -z "$version" ]; then
  version="$(git ls-remote --tags "https://github.com/$REPO.git" | "$(dirname "$0")/next-version.sh")"
fi
tag="$version"

if gh api "repos/$REPO/git/ref/tags/$tag" >/dev/null 2>&1; then
  echo "error: $tag already exists" >&2
  exit 1
fi

# Tag the tip of main on the remote, so we always release the merged state
# regardless of the local checkout.
target="$(gh api "repos/$REPO/commits/$BRANCH" --jq .sha)"

echo "Release : $tag"
echo "Repo    : $REPO"
echo "Commit  : ${target:0:12} (tip of $BRANCH)"
echo "Effect  : triggers the Xcode Cloud Production build -> external TestFlight"

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
