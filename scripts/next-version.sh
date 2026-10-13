#!/usr/bin/env bash
# Next release version, YYYY.M.PATCH: this UTC month, PATCH = month's highest tag + 1, or 0.
# Usage: git ls-remote --tags <repo-url> | scripts/next-version.sh
set -euo pipefail

month="$(date -u +%Y).$((10#$(date -u +%m)))"
last="$(sed 's|.*refs/tags/||' | grep -E "^${month//./\\.}\.[0-9]+$" | cut -d. -f3 | sort -n | tail -1 || true)"
echo "$month.$((${last:--1} + 1))"
