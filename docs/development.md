# Development & releases

SuperFedora is developed on a running install, and the repo is the source of truth.

1. Edit the repo.
2. Apply it as an install would: `bin/superfedora install --only <module>`, or `bin/superfedora dotfiles` for configs.
3. Check it on the desktop.
4. Note the change in `CHANGELOG.md` under `[Unreleased]`, then run `scripts/release.sh <patch|minor|major> "summary"`. This bumps `VERSION`, regenerates `docs/keybindings.md`, commits, tags, pushes and publishes the GitHub release. The web installer always serves the latest release.

`release.sh` refuses to publish while the live desktop configs differ from `dotfiles/` (`bin/superfedora dotfiles --check` lists the differences).

CI lints every push and runs a full install, then a second idempotency run, in a clean Fedora container.
