#!/usr/bin/env bash
# scripts/next-version.test.sh — prints "ok" or the first wrong version.
set -euo pipefail
next="$(dirname "$0")/next-version.sh"

check() { # expected, month, tags...
  local got
  got="$(printf '%s\n' "${@:3}" | "$next" "$2")"
  [[ "$got" == "$1" ]] || { echo "FAIL: expected $1, got $got"; exit 1; }
}

check 2026.10.0  2026.10                                          # month's first release
check 2026.10.0  2026.10 2026.9.18 v2026.9.17 2026.1.0            # other months don't count
check 2026.10.3  2026.10 2026.10.0 2026.10.2 2026.10.1            # one past the highest
check 2026.10.11 2026.10 2026.10.9 2026.10.10                     # numeric, not text, order
check 2026.1.0   2026.1  2026.10.4 2026.11.2                      # 2026.1 is not 2026.10
check 2026.10.2  2026.10 $'abc\trefs/tags/2026.10.1' $'abc\trefs/tags/2026.10.1^{}'  # ls-remote lines
echo ok
