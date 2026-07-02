#!/bin/bash
# git-credential-store-helper — uninstall

set -euo pipefail

XDG_GIT_DIR="$HOME/.config/git"
HOOKS_DIR="$XDG_GIT_DIR/hooks"
CACHE_DIR="$XDG_GIT_DIR/.cache"
XDG_CONFIG="$XDG_GIT_DIR/config"
HOOK_FILE="$HOOKS_DIR/pre-push"
PLIST_NAME="com.apple.dt.xcode.sourcecontrol.helper"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

launchctl unload "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"

if [ -f "$HOOK_FILE" ] && grep -q "credential cache warmup" "$HOOK_FILE" 2>/dev/null; then
  rm -f "$HOOK_FILE"
  echo "Removed pre-push hook."
fi

rm -f "$CACHE_DIR/.warmup.aiff"
rm -f "$CACHE_DIR/.ver"

if [ -f "$XDG_CONFIG" ]; then
  git config --file "$XDG_CONFIG" --unset core.hooksPath 2>/dev/null || true
fi

echo "git-credential-store-helper: uninstalled."
