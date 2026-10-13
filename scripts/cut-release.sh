#!/usr/bin/env bash
# Tag the tip of main as the next release; the tag starts the Xcode Cloud Production workflow.
# Usage: scripts/cut-release.sh [VERSION] [-y]

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

# Default: YYYY.M.PATCH, PATCH = this month's highest tag + 1, or 0.
if [ -z "$version" ]; then
  month="$(date -u +%Y).$((10#$(date -u +%m)))"
  last="$(git ls-remote --tags "https://github.com/$REPO.git" | sed 's|.*refs/tags/||' \
    | grep -E "^${month//./\\.}\.[0-9]+$" | cut -d. -f3 | sort -n | tail -1 || true)"
  version="$month.$((${last:--1} + 1))"
fi
tag="$version"

if gh api "repos/$REPO/git/ref/tags/$tag" >/dev/null 2>&1; then
  echo "error: $tag already exists" >&2
  exit 1
fi

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

# CI builds use the committed version, so move main to the next one.
next="${tag%.*}.$((${tag##*.} + 1))"
file="repos/$REPO/contents/EuroBonus%20Finder/Config/Version.xcconfig"
gh api -X PUT "$file" \
  -f branch="$BRANCH" \
  -f message="chore(release): $next is next" \
  -f sha="$(gh api "$file?ref=$BRANCH" --jq .sha)" \
  -f content="$(gh api -H "Accept: application/vnd.github.raw" "$file?ref=$BRANCH" \
    | sed -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $next/" | base64)" >/dev/null
echo "Bumped Version.xcconfig on $BRANCH to $next."

echo
echo "Cut $tag. Xcode Cloud is building it; the archive will upload to TestFlight."
echo "  Build status : https://github.com/$REPO/commits/$BRANCH"
echo "  TestFlight   : App Store Connect -> your app -> TestFlight"
