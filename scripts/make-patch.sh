#!/usr/bin/env bash
# Regenerate patches/0001-*.patch from /x/repos/Codeman superclaude-compat
# branch (against upstream master). Run after adjusting the patch content
# in the working copy and committing on superclaude-compat.

set -euo pipefail

CODEMAN_DIR="${CODEMAN_DIR:-/x/repos/Codeman}"
ADDON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$CODEMAN_DIR"
git rev-parse master >/dev/null
git rev-parse superclaude-compat >/dev/null

# Wipe existing patches so format-patch can renumber cleanly.
rm -f "$ADDON_DIR/patches/"*.patch

git format-patch master..superclaude-compat \
    --output-directory "$ADDON_DIR/patches/" \
    --suffix=.patch

# Force a stable filename for the single-patch case.
shopt -s nullglob
patches=("$ADDON_DIR/patches/"*.patch)
if (( ${#patches[@]} == 1 )); then
    mv "${patches[0]}" "$ADDON_DIR/patches/0001-discover-superclaude-sessions.patch"
fi

# Refresh the pinned upstream commit hash.
git rev-parse master | head -c 12 > "$ADDON_DIR/CODEMAN_COMMIT"
echo >> "$ADDON_DIR/CODEMAN_COMMIT"

echo "patches refreshed:"
ls -1 "$ADDON_DIR/patches/"
echo "CODEMAN_COMMIT pinned to $(cat "$ADDON_DIR/CODEMAN_COMMIT")"
