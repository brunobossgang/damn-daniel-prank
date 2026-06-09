#!/bin/bash
#
# Cleanly removes the "Damn Daniel" prank and restores prior git config.
#
set -euo pipefail

LABEL="com.apple.dt.Xcode.sourcecontrol.helper"
SUPPORT_DIR="$HOME/Library/Application Support/$LABEL"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
STATE_DIR="$SUPPORT_DIR/.state"
XDG_GIT_CONFIG="$HOME/.config/git/config"

echo "Uninstalling damn-daniel..."

# Unload + remove the LaunchAgent.
launchctl unload "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"

# Restore XDG git config to its previous state.
if [ -f "$STATE_DIR/previous-xdg-git-config" ]; then
  cp "$STATE_DIR/previous-xdg-git-config" "$XDG_GIT_CONFIG"
  echo "Restored previous ~/.config/git/config."
else
  # No prior XDG config existed — remove the hooksPath entry we added.
  git config --file "$XDG_GIT_CONFIG" --unset core.hooksPath 2>/dev/null || true
  # If the file is now empty/only whitespace, remove it entirely.
  if [ -f "$XDG_GIT_CONFIG" ] && ! grep -q '^\s*[^#]' "$XDG_GIT_CONFIG" 2>/dev/null; then
    rm -f "$XDG_GIT_CONFIG"
  fi
  echo "Unset core.hooksPath from ~/.config/git/config."
fi

# Remove install dir.
rm -rf "$SUPPORT_DIR"

echo "Done. Git is back to normal. The joke is over."
