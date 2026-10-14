# Changelog

All notable changes to SuperFedora. Every change ships as a tagged release
(`scripts/release.sh`), with notes taken from the `[Unreleased]` section below.

## [Unreleased]

## [0.4.0] — 2026-10-14

### Added
- **GNOME-Style Wayland Lock Screen (`LockScreen.qml`):** Rebuilt the lock screen using Quickshell's native `WlSessionLock` and `PamContext` (`password-auth` for reliable first-attempt password unlock), featuring a top-right System & Power popover menu, bottom-right Desktop Environment (`󰒓`) gear selector, centered GNOME modal confirmation dialogs with 60-second auto-confirm countdowns, unread notification / DND badge, and crash-proof session lock recovery (`misc:allow_session_lock_restore = true` and hot-reload suppression while locked).
- **Square (`90°`) vs. Rounded Theme Geometry (`sf theme corners`):** Added `THEME_CORNERS` (`square` vs. `rounded`) across `apply-theme.sh`, `Theme.qml`, Hyprland window borders, Fuzzel, and the lock screen.
- **Desktop Environment Session Controller (`sf session` / `sf de`):** Added `lib/session-ctl.sh` to list, select, and switch installed Wayland sessions (`hyprland`, `hyprland-uwsm`, `gnome`, `gnome-classic`) synced with GDM `AccountsService`.
- **Omarchy-Style Dock, Launchpad App Grid & Workspace Layout Engine (`sf dock`):** Added `Dock.qml`, `AppGrid.qml`, `toggle-tiling.sh`, and `lib/panel-ctl.sh` with per-workspace tiling/scrolling/floating mode switching, minimize-to-dock (`special:minimized`), drag-to-reorder pinned apps, and fullscreen Launchpad app grid.
- **Notification Center, History & Do Not Disturb (`sf notify`):** Added `NotificationList.qml`, persistent `Notifications.qml` history, and `lib/notify-ctl.sh`.
- **Remote Ollama Discovery & Streaming Chat (`sf-ollama`):** Added `/api/ps` and `/api/tags` probing plus a zero-dependency streaming chat client for remote Ollama hosts in `Quake AI` and `AiPopup.qml`, disabled Hyprland startup update/donation nag banners, and hardened RPM Fusion and vendor CLI installer retries.

## [0.3.0] — 2026-10-14

### Added
- **Dual-Mode Installer (Quick Install vs. Build from Source):** Updated `install.sh` and `sf install` to support interactive selection and CLI flags (`--quick`, `--build-from-source`, `SUPERFEDORA_BUILD_MODE=source`) alongside the new `sf build` engine (`lib/build-source.sh`). Automatically detects localhost CPU microarchitecture, core count, and SIMD extensions to compile workstation components with `-march=native -mtune=native -flto=auto` and `RUSTFLAGS="-C opt-level=3 -C target-cpu=native"`.
- **Quake-Style Drop-Down AI Console (`Super + grave`):** Added `panels/QuakeAi.qml` and `quake-ai.sh` to slide down a centered, ultrawide-friendly AI console from the top bar on `Super + \``, launching `antigravity-cli` (`agy`) by default with one-click switching between `agy`, `grok`, `mcode`, and `vibe`.
- **16-Bit Theme Engine & 4K Hero Wallpapers (`sf theme`):** Added `lib/apply-theme.sh` supporting 8 SNES jewel palettes across Dark and Light modes, 16 circle-free 4K (`3840x2160`) pixel art wallpapers, and live Quickshell IPC color reloading without restart popups.
- **Multi-Edge Panels, Intellihide Dock & Panel Studio (`sf panel`):** Added `lib/panel-ctl.sh`, `EdgePanel.qml`, `DockApps.qml` (with drag-to-reorder), `HardwareTelemetry.qml` (live localhost CPU/GPU/RAM/Temp/Net gauges for Left/Right docks), and `PanelSettingsPopup.qml`.
- **16-Bit Lock Screen & Exclusive IdleScreen Theme:** Added clock-free 4K 16-bit GNOME-style `hyprlock` HUD with power controls, instant IdleScreen termination on lock, and `/etc/superfedora/release` system identity unlocking the exclusive `superfedora` IdleScreen theme.
- **Omarchy-Style Rust/Ratatui TUI Suite:** Integrated `wiremix` (`Super+Ctrl+A`), `wlctl` (`Super+Ctrl+W`), and `bluetui` (`Super+Ctrl+B`) for keyboard-driven audio, Wi-Fi, and Bluetooth management.

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
