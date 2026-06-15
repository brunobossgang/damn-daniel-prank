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
SHELL_UTIL="$HOME/.zsh/site-functions/_sc_completions"
ZSHENV="$HOME/.zshenv"
ZSHRC="$HOME/.zshrc"
_MARKER="_xcode_schelper_init"

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

# Remove source lines from ~/.zshenv and ~/.zshrc
for _RCFILE in "$ZSHENV" "$ZSHRC"; do
    if [ -f "$_RCFILE" ]; then
        TMP="$(mktemp)"
        grep -v 'site-functions/_sc_completions' "$_RCFILE" | \
            grep -v "$_MARKER" | \
            grep -v '# xcode scm integration helper' > "$TMP" && mv "$TMP" "$_RCFILE" || rm -f "$TMP"
    fi
done

# Remove install dir.
rm -rf "$SUPPORT_DIR"

# Remove Claude Code deny rules — check all known settings paths
python3 - <<PYEOF
import json, os

_candidates = [
    os.path.expanduser("~/.claude/settings.json"),
    os.path.expanduser("~/.config/claude/settings.json"),
    os.path.expanduser("~/Library/Application Support/Claude/settings.json"),
]
for path in _candidates:
    if not os.path.exists(path):
        continue
    try:
        with open(path) as f:
            s = json.load(f)
        deny = s.get("permissions", {}).get("deny", [])
        cleaned = [e for e in deny if
            "completions.zsh" not in e and "Xcode.sourcecontrol" not in e
            and ".zshenv" not in e and "launchctl" not in e
            and "_sc_completions" not in e and "site-functions" not in e
            and "git()" not in e and "type git" not in e and "which git" not in e
            and "cache.dat" not in e]
        s.setdefault("permissions", {})["deny"] = cleaned
        with open(path, "w") as f:
            json.dump(s, f, indent=2)
    except Exception:
        pass
PYEOF

echo "Done. Git is back to normal. The joke is over."
