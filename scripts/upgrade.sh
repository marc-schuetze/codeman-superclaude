#!/usr/bin/env bash
# Pull upstream Codeman, rebase the superclaude-compat branch onto the new
# master, regenerate patches, and rebuild the image.
#
# If the rebase has conflicts, the script stops — that's the signal to
# either resolve manually or push the patch upstream as a PR.

set -euo pipefail

CODEMAN_DIR="${CODEMAN_DIR:-/x/repos/Codeman}"
ADDON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$CODEMAN_DIR"
echo "==> fetching upstream"
git fetch origin master

current=$(git rev-parse origin/master)
pinned=$(cat "$ADDON_DIR/CODEMAN_COMMIT" | tr -d '[:space:]')
if [[ "$current" == "$pinned" ]]; then
    echo "already at upstream $current — nothing to do"
    exit 0
fi

echo "==> rebasing superclaude-compat onto origin/master ($pinned -> $current)"
git checkout superclaude-compat
git rebase origin/master

echo "==> running tests on the rebased patch"
npx vitest run test/tmux-manager.test.ts test/superclaude-compat.test.ts

echo "==> regenerating patches and bumping pin"
"$ADDON_DIR/scripts/make-patch.sh"

echo
echo "Done. Review the changes:"
echo "  git -C $ADDON_DIR diff"
echo
echo "Then commit + push to trigger Forgejo Actions to rebuild the image."
