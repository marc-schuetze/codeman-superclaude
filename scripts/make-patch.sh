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

# Stable filenames per slot, in order. Add a slot here when adding a new
# commit to the superclaude-compat branch.
declare -a SLOT_NAMES=(
    "0001-discover-superclaude-sessions.patch"
    "0002-create-with-superclaude-naming.patch"
)

shopt -s nullglob
generated=("$ADDON_DIR/patches/"*.patch)
if (( ${#generated[@]} != ${#SLOT_NAMES[@]} )); then
    echo "warn: ${#generated[@]} generated patches but ${#SLOT_NAMES[@]} stable slots — keeping generated names"
else
    for i in "${!generated[@]}"; do
        mv "${generated[$i]}" "$ADDON_DIR/patches/${SLOT_NAMES[$i]}"
    done
fi

# Refresh the pinned upstream commit hash.
git rev-parse master > "$ADDON_DIR/CODEMAN_COMMIT"

echo "patches refreshed:"
ls -1 "$ADDON_DIR/patches/"
echo "CODEMAN_COMMIT pinned to $(cat "$ADDON_DIR/CODEMAN_COMMIT")"
