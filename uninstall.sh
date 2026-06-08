#!/bin/bash
#
# Cleanly removes the "Damn Daniel" push prank and restores prior git config.
#
set -euo pipefail

PRANK_HOME="$HOME/.damn-daniel"

echo "Removing the 'Damn Daniel' push prank..."

# Restore the previous global core.hooksPath (or unset it if there was none).
PREV_HOOKS_PATH=""
if [ -f "$PRANK_HOME/previous-hookspath.txt" ]; then
  PREV_HOOKS_PATH="$(cat "$PRANK_HOME/previous-hookspath.txt")"
fi

if [ -n "$PREV_HOOKS_PATH" ]; then
  git config --global core.hooksPath "$PREV_HOOKS_PATH"
  echo "Restored previous core.hooksPath: $PREV_HOOKS_PATH"
else
  git config --global --unset core.hooksPath || true
  echo "Unset core.hooksPath (none was set before)."
fi

# Remove our files.
rm -rf "$PRANK_HOME"

echo "Done. Git is back to normal. The joke is over (for now)."
