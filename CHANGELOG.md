# Changelog

All notable changes to SuperFedora. Every change ships as a tagged release
(`scripts/release.sh`), with notes taken from the `[Unreleased]` section below.

## [Unreleased]

## [0.2.0] — 2026-10-13

### Added
- **`sf` CLI Symlink:** Created `sf` command symlink alongside `superfedora` for concise terminal ergonomics.
- **Installer Help & Passthrough:** Added `-h` and `--help` CLI flags to `install.sh` and enabled argument forwarding (`--dry-run`, `--only`, `--skip`, `--verbose`) directly to `superfedora install`.

## [0.1.0] — 2026-10-13

Initial release of SuperFedora under the `@SuperFedora` organization.

### Features
- **Web Installer:** `curl -fsSL https://superfedora.github.io/install.sh | bash`
- **Modular CLI:** `superfedora` command with `install`, `status`, `update`, `dotfiles`, `rollback`, and `modules`.
- **Minimal Fedora Support:** Automated detection and idempotent installation of base system essentials (NetworkManager, PipeWire, Bluetooth, tuned, VA-API codecs, fonts).
- **Session & Display:** Login via `greetd` + `tuigreet`, launching `hyprland` through `uwsm` systemd session.
- **Desktop Suite:** Hyprland, Quickshell status bar, Pop!_OS COSMIC-aligned keybindings, IdleScreen screensaver.
- **Snapshots & Rollbacks:** Baseline Btrfs snapshotting and automated rollback via `superfedora rollback`.
- **CI/CD:** Automated ShellCheck, bash syntax verification, package linting, and Fedora 44 container install tests.
