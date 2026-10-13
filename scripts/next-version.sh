#!/usr/bin/env bash
#
# Print the next release version, CalVer YYYY.MM.PATCH: this UTC month, and a
# PATCH one past the month's highest release tag (0 for its first release).
# MM is CalVer's short month — 2026.9.0, never 2026.09.0 — because App Store
# versions are plain integers.
#
# Reads tags on stdin, as plain names or `git ls-remote --tags` lines:
#
#   git ls-remote --tags https://github.com/pompa/eurobonus-finder.git | scripts/next-version.sh
#
# An optional YYYY.M argument stands in for this month (scripts/next-version.test.sh).

set -euo pipefail

month="${1:-$(date -u +%Y).$((10#$(date -u +%m)))}"
last="$(sed 's|.*refs/tags/||' | grep -E "^${month//./\\.}\.[0-9]+$" | cut -d. -f3 | sort -n | tail -1 || true)"
echo "$month.$((${last:--1} + 1))"
