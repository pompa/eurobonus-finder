#!/usr/bin/env bash
#
# Fail early on App Store field limits.
#
# `fastlane deliver` only discovers an over-long subtitle or a missing locale
# when it PATCHes App Store Connect, halfway through a release. This runs in a
# second, before the upload and before you commit:
#
#   scripts/check-store-metadata.sh
#
# Note the UTF-8 locale below: Apple counts CHARACTERS, and `wc -m` only agrees
# under a UTF-8 locale — otherwise every å/ä/ö/æ/ø counts twice and the Nordic
# metadata looks over-length. (Same trap as fastlane's UTF-8 warning.)

set -euo pipefail
export LC_ALL=en_US.UTF-8

cd "$(dirname "$0")/.."
root="fastlane/metadata"

# field:limit — fields not listed here are unlimited (URLs, description).
limits="name:30 subtitle:30 keywords:100 promotional_text:170 description:4000 release_notes:4000"
# Every locale needs these; a missing one silently leaves stale text in ASC.
required="name subtitle keywords description release_notes"

problems=0
locales=0

for dir in "$root"/*/; do
  locale="$(basename "$dir")"
  [ "$locale" = "review_information" ] && continue
  locales=$((locales + 1))

  for field in $required; do
    if [ ! -f "$dir$field.txt" ]; then
      echo "  $locale: missing $field.txt"
      problems=$((problems + 1))
    fi
  done

  for file in "$dir"*.txt; do
    field="$(basename "$file" .txt)"
    # Trailing newline is not part of the value; strip it before counting.
    chars=$(printf '%s' "$(cat "$file")" | wc -m | tr -d ' ')

    if [ "$chars" -eq 0 ]; then
      echo "  $locale/$field.txt: empty"
      problems=$((problems + 1))
      continue
    fi

    limit="$(echo "$limits" | tr ' ' '\n' | grep "^$field:" | cut -d: -f2 || true)"
    if [ -n "$limit" ] && [ "$chars" -gt "$limit" ]; then
      echo "  $locale/$field.txt: $chars chars > $limit"
      problems=$((problems + 1))
    fi
  done
done

if [ "$locales" -eq 0 ]; then
  echo "no locale folders under $root" >&2
  exit 1
fi

if [ "$problems" -gt 0 ]; then
  echo "App Store metadata: $problems problem(s)" >&2
  exit 1
fi

echo "metadata OK — $locales locales"
