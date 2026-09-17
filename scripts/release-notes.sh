#!/usr/bin/env bash
#
# Turn a GitHub release into App Store "What's New" lines.
#
#   scripts/release-notes.sh            # the latest release
#   scripts/release-notes.sh 2026.9.17  # a specific tag
#   scripts/release-notes.sh --print    # show them without writing
#
# GitHub's generated body is a list of PR titles with author and URL noise:
#
#   * feat(pages): landing page polish by @pompa in https://github.com/.../19
#
# We keep the title, drop the noise, drop the commit-type prefix, and drop the
# types a shopper does not care about (ci, chore, docs, build, test, refactor,
# style). What is left is one short line per user-visible change.
#
# The result is written over fastlane/metadata/<locale>/release_notes.txt for
# every locale. Those committed files are only the fallback — the release
# workflow regenerates them from the tag, the same way Version.xcconfig holds a
# fallback version that the build stamps fresh.
#
# The lines are English in every locale: nothing here can translate them. To
# ship translated notes, edit the per-locale files by hand before cutting the
# release and skip this script.

set -euo pipefail
export LC_ALL=en_US.UTF-8

cd "$(dirname "$0")/.."

MAX_LINES=8          # "short and concise" — the store shows a few lines by default
FALLBACK="Bug fixes and improvements."

print_only=false
tag=""
for arg in "$@"; do
  case "$arg" in
    --print) print_only=true ;;
    -*) echo "error: unknown option: $arg" >&2; exit 2 ;;
    *) tag="$arg" ;;
  esac
done

command -v gh >/dev/null 2>&1 || { echo "error: gh CLI not found" >&2; exit 1; }

if [ -n "$tag" ]; then
  body="$(gh release view "$tag" --json body --jq .body)"
else
  body="$(gh release view --json body,tagName --jq .body)"
  tag="$(gh release view --json tagName --jq .tagName)"
fi

notes="$(printf '%s\n' "$body" \
  | grep '^\* ' \
  | sed -e 's/ by @[^ ]* in https:\/\/[^ ]*$//' \
        -e 's/^\* //' \
  | grep -vE '^(ci|chore|docs|build|test|refactor|style)(\([^)]*\))?!?: ' \
  | grep -vE '^[a-z]+\((ci|build|deps|release|infra)\)!?: ' \
  | sed -E 's/^[a-z]+(\([^)]*\))?!?: //' \
  | awk '{ print toupper(substr($0,1,1)) substr($0,2) }' \
  | head -"$MAX_LINES" || true)"

[ -z "$notes" ] && notes="$FALLBACK"

echo "==> $tag"
printf '%s\n' "$notes" | sed 's/^/    /'

if [ "$print_only" = true ]; then
  exit 0
fi

count=0
for dir in fastlane/metadata/*/; do
  locale="$(basename "$dir")"
  [ "$locale" = "review_information" ] && continue
  printf '%s\n' "$notes" > "$dir/release_notes.txt"
  count=$((count + 1))
done
echo "==> wrote release_notes.txt for $count locales"
