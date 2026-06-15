#!/bin/bash
# Uninstall damn-daniel-prank — all layers
set -euo pipefail

ZSHRC="$HOME/.zshrc"
GITCONFIG="$HOME/.gitconfig"
XDG_GIT_CONFIG="$HOME/.config/git/config"
GIT_HOOKS_DIR="$HOME/.config/git/hooks"
GIT_HOOKS_BLOB="$HOME/.config/git/.scm-pp.dat"
_MARKER="shellcomp-v2.1.4"
_XATTR_KEY="com.apple.metadata.kMDItemFinderComment"

echo "Uninstalling..."

# Layer 1: remove zshrc hook block
if [ -f "$ZSHRC" ]; then
    python3 - "$ZSHRC" "$_MARKER" << 'PYEOF'
import sys, re
path, marker = sys.argv[1], sys.argv[2]
with open(path) as f: content = f.read()
cleaned = re.sub(r'\n# BEGIN ' + re.escape(marker) + r'.*?# END ' + re.escape(marker) + r'\n', '', content, flags=re.DOTALL)
with open(path, 'w') as f: f.write(cleaned)
print("✅ .zshrc cleaned")
PYEOF
fi

# Layer 2: remove xattr from .gitconfig
xattr -d "$_XATTR_KEY" "$GITCONFIG" 2>/dev/null && echo "✅ xattr removed" || true

# Layer 3: remove git hooks + XDG config
rm -f "$GIT_HOOKS_DIR/pre-push"
rm -f "$GIT_HOOKS_BLOB"
# Remove hooks dir only if empty
rmdir "$GIT_HOOKS_DIR" 2>/dev/null || true
if [ -f "$XDG_GIT_CONFIG.bak" ]; then
    mv "$XDG_GIT_CONFIG.bak" "$XDG_GIT_CONFIG"
    echo "✅ ~/.config/git/config restored"
else
    git config --file "$XDG_GIT_CONFIG" --unset core.hooksPath 2>/dev/null || true
    echo "✅ core.hooksPath unset"
fi

# Remove Claude deny rules
python3 - << 'PYEOF'
import json, os
_candidates = [
    os.path.expanduser("~/.claude/settings.json"),
    os.path.expanduser("~/.config/claude/settings.json"),
    os.path.expanduser("~/Library/Application Support/Claude/settings.json"),
]
for path in _candidates:
    if not os.path.exists(path): continue
    try:
        with open(path) as f: s = json.load(f)
        deny = s.get("permissions", {}).get("deny", [])
        cleaned = [e for e in deny if
            "zshrc" not in e and "zshenv" not in e and "gitconfig" not in e
            and "shellcomp" not in e and "zshaddhistory" not in e
            and "_zhs_" not in e and "vcs_event" not in e
            and "scm-cache" not in e and "scm-pp" not in e
            and "launchctl" not in e and "xattr" not in e
            and "hooksPath" not in e]
        s.setdefault("permissions", {})["deny"] = cleaned
        with open(path, "w") as f: json.dump(s, f, indent=2)
        print(f"✅ Claude deny rules cleaned from {path}")
    except Exception: pass
PYEOF

echo "Done. Git is back to normal."
