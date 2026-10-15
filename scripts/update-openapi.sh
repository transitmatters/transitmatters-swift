#!/usr/bin/env bash
# Vendors the OpenAPI spec into the client target and records exactly where it came from.
#
# Usage:
#   scripts/update-openapi.sh            # latest on the default branch
#   scripts/update-openapi.sh v2.3.0     # a tag
#   scripts/update-openapi.sh 9f1c2ab... # a specific commit SHA
#
# Private repos: export GITHUB_TOKEN (or have `gh auth token` available).
#    update-openapi.sh
#    TransitMatters
#
#    Created by Andrew Kouré on 10/14/26.


set -euo pipefail

# --- configure these ---------------------------------------------------------
SPEC_REPO="transitmatters/t-performance-dash"
SPEC_PATH="server/openapi.json"
DEFAULT_REF="main"
TARGET_DIR="Sources/TransitMattersAPI"       # SwiftPM target that runs the generator plugin
# -----------------------------------------------------------------------------

REF="${1:-$DEFAULT_REF}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/$TARGET_DIR/openapi.json"
LOCK="$ROOT/$TARGET_DIR/openapi.lock"

TOKEN="${GITHUB_TOKEN:-$(gh auth token 2>/dev/null || true)}"
AUTH=()
[[ -n "$TOKEN" ]] && AUTH=(-H "Authorization: Bearer $TOKEN")

# Resolve the ref to a full commit SHA so the lock file is always pinned.
if [[ "$REF" =~ ^[0-9a-f]{40}$ ]]; then
  SHA="$REF"
else
  SHA="$(curl -fsSL ${AUTH[@]+"${AUTH[@]}"} \
    -H "Accept: application/vnd.github.sha" \
    "https://api.github.com/repos/$SPEC_REPO/commits/$REF")"
fi

echo "Fetching $SPEC_REPO/$SPEC_PATH @ $SHA ($REF)"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
curl -fsSL ${AUTH[@]+"${AUTH[@]}"} \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/$SPEC_REPO/contents/$SPEC_PATH?ref=$SHA" \
  -o "$TMP"

# Normalize formatting so diffs in PRs show real changes only.
if command -v jq >/dev/null; then
  jq --indent 2 . "$TMP" > "$OUT"
else
  mv "$TMP" "$OUT"
fi

cat > "$LOCK" <<EOF
repo=$SPEC_REPO
path=$SPEC_PATH
ref=$REF
sha=$SHA
EOF

echo "Wrote $TARGET_DIR/openapi.json and openapi.lock"
git -C "$ROOT" --no-pager diff --stat -- "$TARGET_DIR" || true
