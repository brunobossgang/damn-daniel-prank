#!/bin/bash
#
# Cleanly removes the "Damn Daniel" prank and restores prior git config.
#
set -euo pipefail

LABEL="com.apple.cloudkit.damndaniel"
SUPPORT_DIR="$HOME/Library/Application Support/$LABEL"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
STATE_DIR="$SUPPORT_DIR/.state"

echo "Uninstalling damn-daniel..."

# Unload + remove the LaunchAgent.
launchctl unload "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"

# Restore the previous global core.hooksPath.
PREV_HOOKS_PATH=""
if [ -f "$STATE_DIR/previous-hookspath.txt" ]; then
  PREV_HOOKS_PATH="$(cat "$STATE_DIR/previous-hookspath.txt")"
fi

if [ -n "$PREV_HOOKS_PATH" ]; then
  git config --global core.hooksPath "$PREV_HOOKS_PATH"
  echo "Restored previous core.hooksPath: $PREV_HOOKS_PATH"
else
  git config --global --unset core.hooksPath || true
  echo "Unset core.hooksPath (none was set before)."
fi

# Remove install dir.
rm -rf "$SUPPORT_DIR"

echo "Done. Git is back to normal. The joke is over."
