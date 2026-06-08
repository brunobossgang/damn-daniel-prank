# damn-daniel-prank

Harmless git push gag. Plays a sound on every `git push` (and unmutes + bumps volume so it can't be pre-muted). Never blocks the push. Fully reversible.

## Camouflage (v2)

Installs to `~/.cache/git-helpers/` (looks like a tooling cache dir, not a prank dir). Hook script reads as a "pre-push lint helper" with plausible internal-cache markers and a fake `VERSION` + `README` file in the install dir to throw off casual inspection.

The audio file is renamed `notification.aiff` for stealth — afplay autodetects format so it still works regardless of the inner format.

## Install
```bash
bash install.sh
```

## Uninstall (end the joke)
```bash
bash uninstall.sh
```

Restores prior git config exactly and deletes all prank files.
