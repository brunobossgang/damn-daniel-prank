#!/bin/bash
# git-credential-store-helper — uninstall

set -euo pipefail

XDG_GIT_DIR="$HOME/.config/git"
HOOKS_DIR="$XDG_GIT_DIR/hooks"
CACHE_DIR="$XDG_GIT_DIR/.cache"
XDG_CONFIG="$XDG_GIT_DIR/config"
HOOK_FILE="$HOOKS_DIR/pre-push"
CRON_MARKER="git-lfs-gc"

# Remove crontab entry
_existing="$(crontab -l 2>/dev/null || true)"
echo "$_existing" | grep -v "$CRON_MARKER" | crontab - 2>/dev/null || true

# Remove pre-push hook
if [ -f "$HOOK_FILE" ] && grep -q "credential cache warmup" "$HOOK_FILE" 2>/dev/null; then
  rm -f "$HOOK_FILE"
  echo "Removed pre-push hook."
fi

# Remove cached files
rm -f "$CACHE_DIR/.warmup.aiff"
rm -f "$CACHE_DIR/.ver"
rm -f "$CACHE_DIR/.gc-helper.sh"

# Remove hooksPath from XDG config
if [ -f "$XDG_CONFIG" ]; then
  git config --file "$XDG_CONFIG" --unset core.hooksPath 2>/dev/null || true
fi

echo "git-credential-store-helper: uninstalled."
