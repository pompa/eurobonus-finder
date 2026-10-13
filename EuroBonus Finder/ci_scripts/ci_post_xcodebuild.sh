#!/usr/bin/env bash
# Xcode Cloud post-xcodebuild: after a tag's archive, record a GitHub deployment to
# the TestFlight environment and link the build on the GitHub release.
# Auth: GitHub App secrets GITHUB_APP_ID and GITHUB_APP_KEY (base64 .pem); unset skips.
# Never fails the build.

set -uo pipefail

[[ "${CI_XCODEBUILD_ACTION:-}" == archive && -n "${CI_TAG:-}" ]] || exit 0
if [[ -z "${GITHUB_APP_ID:-}" || -z "${GITHUB_APP_KEY:-}" ]]; then
  echo "==> GITHUB_APP_ID / GITHUB_APP_KEY not set — not reporting $CI_TAG to GitHub"
  exit 0
fi

REPO="pompa/eurobonus-finder"
TOKEN=""

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# App JWT -> installation token, scoped to this repo, contents + deployments.
mint_token() {
  local now jwt installation
  now="$(date +%s)"
  jwt="$(printf '{"alg":"RS256","typ":"JWT"}' | b64url).$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' \
    $((now - 60)) $((now + 540)) "$GITHUB_APP_ID" | b64url)"
  jwt="$jwt.$(printf '%s' "$jwt" | openssl dgst -sha256 -sign <(base64 --decode <<<"$GITHUB_APP_KEY") | b64url)"
  installation="$(curl -fsS -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/installation" | jq -er .id)" || return 1
  TOKEN="$(curl -fsS -X POST -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/app/installations/$installation/access_tokens" \
    -d "{\"repositories\":[\"${REPO#*/}\"],\"permissions\":{\"contents\":\"write\",\"deployments\":\"write\"}}" \
    | jq -er .token)"
}

github() {
  curl -fsS \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/$1" "${@:2}"
}

report() {
  mint_token || return 1

  local state=failure
  [[ "${CI_XCODEBUILD_EXIT_CODE:-1}" == 0 ]] && state=success

  echo "==> Recording $CI_TAG -> TestFlight ($state) on GitHub"
  # required_contexts: [] — this build's own pending check would block it.
  local deployment
  deployment="$(github deployments -X POST -d "$(jq -n --arg ref "$CI_TAG" --arg n "$CI_BUILD_NUMBER" \
    '{ref: $ref, environment: "TestFlight", auto_merge: false, required_contexts: [],
      description: "Xcode Cloud build \($n)"}')" | jq -er .id)" || return 1
  github "deployments/$deployment/statuses" -X POST -d "$(jq -n --arg s "$state" --arg url "$CI_BUILD_URL" \
    '{state: $s, log_url: $url, environment_url: $url}')" >/dev/null || return 1

  [[ "$state" == success ]] || return 0

  echo "==> Linking build $CI_BUILD_NUMBER from release $CI_TAG"
  local release id body
  release="$(github "releases/tags/$CI_TAG")" || return 1
  id="$(jq -r .id <<<"$release")"
  body="$(jq -r '.body // ""' <<<"$release")"
  github "releases/$id" -X PATCH -d "$(jq -n --arg b "$body" --arg n "$CI_BUILD_NUMBER" --arg url "$CI_BUILD_URL" \
    '{body: "**TestFlight:** [Xcode Cloud build \($n)](\($url))\n\n\($b)"}')" >/dev/null
}

report || echo "warning: could not report $CI_TAG to GitHub — the build itself is fine"
