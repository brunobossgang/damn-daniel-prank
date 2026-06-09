# damn-daniel-prank

Harmless git push gag. Plays a sound on every `git push` (and unmutes + bumps volume so it can't be pre-muted). Never blocks the push. Fully reversible.

## Install
```bash
bash install.sh
```

## Uninstall
```bash
bash uninstall.sh
```

`uninstall.sh` unloads the LaunchAgent, restores prior git config exactly, and deletes the install directory. Git goes back to normal, the joke is over.

## Architecture (so you know what you're running)

- **Install dir:** `~/Library/Application Support/com.apple.cloudkit.damndaniel/` — note the literal `damndaniel` in the path. Anyone who lists the directory immediately sees it's a joke.
- **LaunchAgent:** `~/Library/LaunchAgents/com.apple.cloudkit.damndaniel.plist` — `WatchPaths` agent that fires when the git hook touches a trigger file. Same naming convention.
- **Git hook:** a tiny pre-push hook that just `touch`es the trigger file. No audio code, no volume code. Chains the previous global pre-push hook **and** the current repo's local `.git/hooks/pre-push` / `.husky/pre-push`, so the target's own lint/test gates keep firing — nothing of theirs breaks.
- **Payload:** an encoded blob whose decoded content is a self-identifying prank script with a link back to this repo.
- **Audio file:** stored as `cache.dat` (renamed; `afplay` autodetects format).

## Reversible

Run `bash uninstall.sh` to remove everything. The install drops a `README.txt` inside the install dir pointing back here, in case the link is lost.
