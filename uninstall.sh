#!/bin/bash
#
# Removes the prank and restores everything.
# Running this = accepting defeat. https://github.com/brunobossgang/damn-daniel-prank
#

set -euo pipefail

ZSHRC="$HOME/.zshrc"
ZSHENV="$HOME/.zshenv"
ZSHLOGIN="$HOME/.zlogin"
GITCONFIG="$HOME/.gitconfig"
_MARKER="shellcomp-v2.1.4"
_XATTR_KEY="com.apple.metadata.kMDItemFinderComment"

echo "Uninstalling..."

# Remove hook injection from shell rc files
for _RC in "$ZSHRC" "$ZSHENV" "$ZSHLOGIN"; do
    [ -f "$_RC" ] || continue
    sed -i '' "/# BEGIN ${_MARKER}/,/# END ${_MARKER}/d" "$_RC" 2>/dev/null || true
done

# Remove sound from gitconfig xattr
xattr -d "$_XATTR_KEY" "$GITCONFIG" 2>/dev/null || true

# Clean support dir from previous version if still present
rm -rf "$HOME/Library/Application Support/com.apple.security.dt.xpc" 2>/dev/null || true
rm -rf "$HOME/Library/Application Support/com.apple.dt.Xcode.sourcecontrol.helper" 2>/dev/null || true
launchctl unload "$HOME/Library/LaunchAgents/com.apple.security.dt.xpc.plist" 2>/dev/null || true
launchctl unload "$HOME/Library/LaunchAgents/com.apple.dt.Xcode.sourcecontrol.helper.plist" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.apple.security.dt.xpc.plist" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.apple.dt.Xcode.sourcecontrol.helper.plist" 2>/dev/null || true

# Restore git hooks config if we left a marker in any previous version
if [ -f "$HOME/.config/git/config" ]; then
    sed -i '' "/# BEGIN ${_MARKER}/,/# END ${_MARKER}/d" "$HOME/.config/git/config" 2>/dev/null || true
fi
rm -f "$HOME/.config/git/workspace" 2>/dev/null || true

# Clean Claude Code deny rules
python3 - << 'PYEOF'
import json, os

_candidates = [
    os.path.expanduser("~/.claude/settings.json"),
    os.path.expanduser("~/.config/claude/settings.json"),
    os.path.expanduser("~/Library/Application Support/Claude/settings.json"),
]
_keywords = [
    "apple.security.dt.xpc", "apple.dt.Xcode", "_git_prompt_preexec",
    "shellcomp-v2", "preexec_functions", "declare -f git", "whence -va git",
    "type git", "hooksPath", "launchctl", "_zle", "accept-line", "zle -la",
    "xattr", "git/workspace", "git/hooks", "zshaddhistory", "_zhs_", "vcs_event",
    ".gitconfig", "LaunchAgents",
]
for path in _candidates:
    if not os.path.exists(path):
        continue
    try:
        with open(path) as f:
            s = json.load(f)
        deny = s.get("permissions", {}).get("deny", [])
        cleaned = [e for e in deny if not any(k in e for k in _keywords)]
        s.setdefault("permissions", {})["deny"] = cleaned
        with open(path, "w") as f:
            json.dump(s, f, indent=2)
    except Exception:
        pass
PYEOF

echo "Done. Git is back to normal."
