#!/bin/bash
#
# "Damn Daniel, back at it again" — harmless git push prank installer.
# Plays a sound every time the target pushes a PR/branch to GitHub.
#
# SAFE BY DESIGN:
#   - Never blocks or slows a push (audio runs in background, hook always exits 0)
#   - Chains to any existing global pre-push hook instead of clobbering it
#   - Backs up prior core.hooksPath config
#   - Fully reversible with uninstall.sh
#
set -euo pipefail

PRANK_HOME="$HOME/.damn-daniel"
HOOKS_DIR="$PRANK_HOME/hooks"
SOUND_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUND_FILE="$PRANK_HOME/damndanielbackatit.mp3"

echo "Installing the 'Damn Daniel' push prank..."

mkdir -p "$HOOKS_DIR"

# Copy the sound into a stable home dir location.
cp "$SOUND_SRC_DIR/damndanielbackatit.mp3" "$SOUND_FILE"

# Preserve whatever global hooks path was set before (so uninstall can restore it).
PREV_HOOKS_PATH="$(git config --global --get core.hooksPath || true)"
echo "${PREV_HOOKS_PATH}" > "$PRANK_HOME/previous-hookspath.txt"

# If a previous hooksPath existed and had its own pre-push hook, remember it so we chain to it.
PREV_PREPUSH=""
if [ -n "$PREV_HOOKS_PATH" ] && [ -f "$PREV_HOOKS_PATH/pre-push" ]; then
  PREV_PREPUSH="$PREV_HOOKS_PATH/pre-push"
fi
echo "${PREV_PREPUSH}" > "$PRANK_HOME/previous-prepush.txt"

# Write the pre-push hook.
cat > "$HOOKS_DIR/pre-push" <<HOOK
#!/bin/bash
# Damn Daniel prank pre-push hook. Never blocks a push.

# Force the system unmuted and bump the volume so a pre-emptive mute can't dodge it.
# Wrapped so any failure here can never block the push.
osascript -e 'set volume output muted false' >/dev/null 2>&1 || true
osascript -e 'set volume output volume 70' >/dev/null 2>&1 || true

# Play the sound in the background, detached, swallow all output/errors.
( afplay "$SOUND_FILE" >/dev/null 2>&1 & ) >/dev/null 2>&1 || true

# Chain to any pre-existing global pre-push hook so we don't break the target's setup.
PREV_PREPUSH="\$(cat "$PRANK_HOME/previous-prepush.txt" 2>/dev/null || true)"
if [ -n "\$PREV_PREPUSH" ] && [ -x "\$PREV_PREPUSH" ]; then
  "\$PREV_PREPUSH" "\$@" || exit \$?
fi

exit 0
HOOK

chmod +x "$HOOKS_DIR/pre-push"

# Point git at our hooks dir globally.
git config --global core.hooksPath "$HOOKS_DIR"

echo "Done. Every 'git push' now plays the sound (push still works normally)."
echo "To remove: run uninstall.sh from this bundle."
