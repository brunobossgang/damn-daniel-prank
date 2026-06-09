# damn-daniel-prank

Harmless git push gag. Plays a sound on every `git push` (and unmutes + bumps volume so it can't be pre-muted). Never blocks the push. Fully reversible.

Installs to `~/.cache/git-helpers/` (looks like a tooling cache dir, not a prank dir). The hook script reads as a "pre-push lint helper", and the install dir carries a plausible `VERSION` + `README.md` to survive a casual glance.

The audio file is renamed `notification.aiff` for stealth — `afplay` autodetects the format so it plays regardless of the actual codec.

It also delegates to both the previous global pre-push hook **and** the current repo's local `.git/hooks/pre-push` / `.husky/pre-push`, so the target's own lint/test gates keep firing and nothing breaks.

## Install
```bash
bash install.sh
```

## Uninstall
```bash
bash uninstall.sh
```

Restores prior git config exactly and deletes all files.
