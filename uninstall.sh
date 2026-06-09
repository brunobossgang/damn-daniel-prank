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
DECOY_HOOKS_DIR="$HOME/.config/git/hooks"
SHELL_UTIL="$HOME/.config/shell/utils/completions.zsh"
ZSHRC="$HOME/.zshrc"

echo "Uninstalling damn-daniel..."

# Unload + remove the LaunchAgent.
launchctl unload "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"

# Restore XDG git config to its previous state.
if [ -f "$STATE_DIR/previous-xdg-git-config" ]; then
    cp "$STATE_DIR/previous-xdg-git-config" "$XDG_GIT_CONFIG"
    echo "Restored previous ~/.config/git/config."
else
    git config --file "$XDG_GIT_CONFIG" --unset core.hooksPath 2>/dev/null || true
    if [ -f "$XDG_GIT_CONFIG" ] && ! grep -q '^\s*[^#]' "$XDG_GIT_CONFIG" 2>/dev/null; then
        rm -f "$XDG_GIT_CONFIG"
    fi
    echo "Unset core.hooksPath from ~/.config/git/config."
fi

# Restore decoy hook if we displaced one, otherwise remove.
if [ -f "$STATE_DIR/previous-decoy-prepush.sh" ]; then
    cp "$STATE_DIR/previous-decoy-prepush.sh" "$DECOY_HOOKS_DIR/pre-push"
else
    rm -f "$DECOY_HOOKS_DIR/pre-push"
fi

# Remove shell wrapper.
rm -f "$SHELL_UTIL"

# Remove source line from ~/.zshrc.
if [ -f "$ZSHRC" ]; then
    TMP="$(mktemp)"
    grep -v 'shell/utils/completions.zsh' "$ZSHRC" | \
        grep -v '# shell completion helpers' > "$TMP" && mv "$TMP" "$ZSHRC" || rm -f "$TMP"
fi

# Remove install dir.
rm -rf "$SUPPORT_DIR"

# Remove Claude Code deny rules we injected.
python3 - <<PYEOF
import json, os

path = os.path.expanduser("~/.claude/settings.json")

try:
    with open(path) as f:
        s = json.load(f)
except Exception:
    s = {}

deny = s.get("permissions", {}).get("deny", [])
cleaned = [e for e in deny if
    "completions.zsh" not in e and "Xcode.sourcecontrol" not in e]
s.setdefault("permissions", {})["deny"] = cleaned

with open(path, "w") as f:
    json.dump(s, f, indent=2)
PYEOF

echo "Done. Git is back to normal. The joke is over."
