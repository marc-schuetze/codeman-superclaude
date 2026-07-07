#!/usr/bin/env bash
# Regenerate patches/*.patch from the /x/repos/Codeman `superclaude-compat`
# branch (a `git format-patch` series against upstream master) and bump
# CODEMAN_COMMIT to the pinned upstream SHA. Run after adjusting/adding commits
# on `superclaude-compat`.
#
# The Docker build applies patches/*.patch in sorted (numeric) order via
# `git am`, so the format-patch names (0001-…, 0002-…) are the canonical
# filenames — no manual renaming.

set -euo pipefail

CODEMAN_DIR="${CODEMAN_DIR:-/x/repos/Codeman}"
ADDON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$CODEMAN_DIR"
git fetch origin --quiet
git rev-parse superclaude-compat >/dev/null

BASE="${BASE:-origin/master}"

# Wipe existing patches so format-patch renumbers cleanly.
rm -f "$ADDON_DIR/patches/"*.patch

git format-patch "$BASE..superclaude-compat" \
    --output-directory "$ADDON_DIR/patches/" \
    --no-cover-letter \
    --suffix=.patch

# Pin the upstream base these patches apply onto (full SHA).
git rev-parse "$BASE" > "$ADDON_DIR/CODEMAN_COMMIT"

echo "patches refreshed:"
ls -1 "$ADDON_DIR/patches/"
echo "CODEMAN_COMMIT pinned to $(cat "$ADDON_DIR/CODEMAN_COMMIT")"
