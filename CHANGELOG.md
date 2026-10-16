# Changelog

All notable changes to SuperFedora. Every change ships as a tagged release
(`scripts/release.sh`), with notes taken from the `[Unreleased]` section below.

## [Unreleased]

## [0.11.0] — 2026-10-16

### Added
- **SuperSettings Deep-Link Navigation, Keyboard UX & Hardware Probes (`supersettings`, `src/settings_engine.rs`, `SettingsWindow.qml`, `SettingsPages.qml`):** Added multi-segment category/item/sub-panel deep-linking (`supersettings open <page>:<item>:<subpanel>`), non-zero exit codes for unknown CLI domains/pages, inline confirmation before destructive actions, live Bluetooth scan feedback, PipeWire `module-remap-sink` mono-audio downmix routing, and declarative Hyprland touchpad enable/disable state persistence (`toggle-touchpad.sh`).
- **SuperDeck Modular + All-in-One AI Harness Configurator (`StatusPopup.qml`, `Status.qml`, `quake-ai.sh`):** Added inline SuperDeck Dock Settings with All-in-One agent selection (`agy`, `mcode`, `grok`, `vibe`, `claude`, `chatgpt`) and Modular Harness + Local/LAN Ollama server & model picker (`pi`, `mcode`, `opencode`, `aider`, `ollama-cli`, `sf-chat`).
- **Build-from-Source Default Mode & DE Ecosystem Suites (`install.sh`, `src/cli.rs`, `v0.10.0`–`v0.11.0`):** Promoted `--build-from-source` (`-march=native` / `target-cpu=native`) as the default workstation build mode and synced curated DE Ecosystem Suite presets, 12 XDG default application roles, and searchable file extension associations with `supershell` v0.5.0.

## [0.9.0] — 2026-10-15

### Added
- **Wave 1 — Zero-Fork Telemetry, Hyprland VFR & Compatibility-First `systemd` Tuning:** Added `PackageKit` `ShutdownTimeout=30` drop-in (`system/etc/systemd/system/packagekit.service.d/superfedora-timeout.conf`), on-demand socket activation telemetry (`Active`, `On-Demand (Socket)`, `Stopped`) in `superfedora service` and `supersettings`, Hyprland `vfr = true` + `direct_scanout = true`, and `superbar --stream-json` / `--telemetry-json`.
- **Wave 2 — Zero-Friction Codecs, VA-API Hardware Video & GPU Auto-Tuning (`superfedora hardware`):** Added `superfedora hardware [probe|optimize]` (`src/ops/hardware.rs`, `modules/20-base.sh`) auto-detecting AMD RDNA, Intel Arc/Xe, and NVIDIA RTX GPUs, swapping `ffmpeg-free` -> `ffmpeg`, configuring Firefox zero-copy DMABUF + VA-API, and triggering `SYS ENG (SUPERFEDORA)` Cast Comms.
- **Wave 3 — Instant "Time-Machine" Btrfs Rollback UI & DNF5 Hooks (`superfedora snapshot`):** Added `superfedora snapshot [list|diff|create|restore]` (`src/ops/snapshot.rs`), TUI Time-Machine diffing, and `system/etc/dnf/libdnf5-plugins/actions.d/superfedora-snapper.actions` with `ARCHIVIST (SNAPPER // VAULT)` Cast Comms.
- **Wave 4 — Two-Tier Hybrid Binary Cache & Background Native Re-Forge (`superforge`):** Added `superforge fetch-bin <target>` (`--quick`) for static musl release downloads and `superforge background-reforge` (`superforge-check.service`) for AC-power `-O3 -march=native` atomic binary swaps with `BUILDER (SF FORGE)` Cast Comms.
- **Wave 5 — Local-First Workstation Watchdog & 16-Bit Power/Arcade Modes (`superfedora mode`, `superagent watchdog`):** Added `superfedora mode [stealth|balanced|forge|arcade|status]` (`src/ops/mode.rs`) and `superagent watchdog` routing alerts to the 10 Cast Specialists (`medic`, `security`, `navigator`, `commander`, `ai`).
- **Wave 6 — Declarative Workstation Clone (`workstation.toml`) & Native Wayland Layer-Shell Overlay:** Added `superfedora export [path]` and `superfedora import <path> [--dry-run]` (`src/ops/workstation.rs`) plus `superbar hud` and `supernotify overlay` native `<15MB` Layer-Shell fallback renderers.

## [0.8.0] — 2026-10-15

### Added
- **Canonical `superfedora` CLI & Relative `sf` Alias:** Promoted `superfedora` as the primary binary across all scripts, docs, and source builders while installing `sf` as a relative symlink (`ln -sf superfedora ~/.local/bin/sf`).
- **Fedora Minimal Stage-0 Bootstrap & Future Release (`42 -> 43 -> 44+`) Hardening:** Added Stage-0 bootstrap (`git-core curl tar gzip zstd findutils`) in `install.sh`, expanded `packages/base.txt` and `packages/session.txt` for bare Fedora Minimal netinstalls, added COPR-to-`superforge` source compilation fallback in `lib/check.sh`, and added `superfedora system-upgrade [releasever]` (`src/ops.rs`).
- **Native `systemd` Session, Daemons, Timers & Declarative OS Tuning:** Added `dotfiles/.config/systemd/user/` units (`superfedora-session.target`, `supershell.service`, `superagent.service`, `idlescreen.service`, `supertheme-sun.service`, `supertheme-sun.timer`, `superforge-check.service`, `superforge-check.timer`), `dotfiles/.config/user-tmpfiles.d/superfedora.conf`, declarative OS drop-ins (`zram-generator`, `journald`, `sysctl`), and `superfedora service [status|start|restart|logs]`.
- **Multi-User Layout, SELinux Enforcing & Polkit Integration:** Added `/usr/local/bin` and `/usr/share/superfedora` fallback, `/etc/skel/.config/superfedora` seeding, `/etc/polkit-1/rules.d/50-superfedora.rules`, `restorecon` SELinux enforcement, and `superfedora repo [status|test|sync]`.

## [0.6.0] — 2026-10-15

### Added
- **Multi-Repo Native Rust 1.99 Architecture (`@SuperFedora`):** Extracted and unified the SuperFedora workstation ecosystem across 6 dedicated repositories and 9 native Rust binaries (`sf`/`superfedora`, `supertheme`, `superforge`, `superdock`, `superbar`, `supersettings`, `supernotify`, `superlock`, and `superagent`).
- **Standalone Theme, Cast & SFX Engine (`SuperFedora/supertheme`):** Native Rust `supertheme` binary managing the 16-color rainbow palette (`01-crimson`..`16-fuchsia`), Dark/Light modes, Square/Rounded geometry, 4K pixel-art wallpapers, 16-bit cast portraits, and synthesized 16-bit WAV audio cues.
- **Standalone Hardware-Tuned Source Compiler (`SuperFedora/superforge`):** Native Rust `superforge` binary and declarative `recipes.toml` catalog for `-march=native` / LTO source compilation, user-sysroot header staging, 4-stage workstation updates, and chromeless Firefox WebApps.
- **Standalone 16-Bit Desktop Shell Suite (`SuperFedora/supershell`):** Native Rust binaries (`superdock`, `superbar`, `supersettings`, `supernotify`, `superlock`) and QML shell components.
- **Standalone Autonomous Workstation Agent (`SuperFedora/superagent`):** Native Rust `superagent` daemon, CLI, and TUI orchestrating OpenClaw, local/LAN Ollama (`sf-ollama`), and coding harnesses (`agy`, `mcode`, `grok`, `vibe`) with `AGY // OPENCLAW` Cast Comms notifications via `supernotify`.
- **Canonical Page Rules & Zero-Emoji Invariant (`AGENTS.md`, `tests/test_page_rules.py`):** Enforced 16–256 line bounds per code file, `<= 12` functional files per directory, and zero Unicode emojis across all repositories.

## [0.5.0] — 2026-10-14

### Added
- **Hardware-Tuned Source Installer (`sf forge`, `lib/forge.sh`):** Added an ergonomic source compiler that clones any `<owner>/<repo>` or preset (`ripgrep`, `fastfetch`, `idlescreen`, `fd`, `zoxide`, `btop`, `wlctl`, `bluetui`, `wiremix`, `fuzzel`, `hyprland`, `quickshell`), detects localhost CPU microarchitecture (`-march=native -mtune=native -O3 -pipe -flto=auto`, `RUSTFLAGS="-C opt-level=3 -C target-cpu=native -C codegen-units=1 -C strip=symbols"`), fast linkers (`mold`/`lld`), and GPU vendor, stages missing `-devel` headers, compiles in parallel (`-j$(nproc)`), atomically installs into `~/.local/bin`, and tracks builds in `~/.config/superfedora/forge.json`.
- **Day / Night + Square / Rounded Theme Engine & Named Presets (`sf theme`, `lib/apply-theme.sh`):** Added `--mode night|day|dark|light|toggle`, `--corners square|rounded|toggle`, `--nightlight on|off|toggle` (`wlsunset`/`hyprsunset` blue-light filter), and named presets (`snes`, `tokyo-night`, `catppuccin`, `nord`) alongside `01-super-blue`..`08-neon-coral`, live-syncing Hyprland, Quickshell, Fuzzel, Kitty, Ghostty, Tmux, Neovim, and GTK/Portal.
- **Top Bar Collapsible Pocket, Unified Quick Settings Pill & 16-Bit SNES OSD (`Bar.qml`, `Status.qml`, `Osd.qml`):** Decluttered the top bar with a collapsible Pocket Drawer (`Tray`, `CPU %`, `AI`, `Caffeine`, `AppGrid`), a single unified GNOME-style Quick Settings pill (`Wi-Fi + Bluetooth + Audio + Battery + Power`), consolidated polling with event-driven Hyprland client updates (`Hyprland.onRawEvent`), and a 16-bit SNES segmented HUD bar for volume/mute and brightness changes.
- **Unified SuperDeck (`LauncherMenu.qml`, `StatusPopup.qml`):** Merged Launcher, Control Center, Style Studio, Forge, Dock Studio, Snapshots, and Power menu into a single SuperDeck with instant app search and direct `owner/repo` source forging, interactive Volume and Brightness sliders, 6 Quick Tiles, and inline power confirmation.
- **Omarchy Quattro Dock Drag-to-Edge, Layout Snapshots & Two-Speed Resize (`Dock.qml`, `toggle-tiling.sh`, `bindings.conf`):** Added grab-and-drag dock edge repositioning with live ghost slab preview, double-click transparency toggle, hover app-name pill tooltips, 1..3 multi-window pip indicators, `Super + Alt + Home` / `Super + Home` workspace window geometry save/restore, and `CTRL` (`10px` fine) / `ALT` (`80px` coarse) resize tiers while preserving 100% of Pop!_OS COSMIC bindings.
- **16-Bit SNES Sound Engine & Cartridge Control Deck TUI (`sf sfx`, `sf tui`, `sf welcome`, `lib/sfx.sh`, `lib/tui.sh`):** Added synthesized 16-bit SNES WAV sound effects (`startup`, `click`, `confirm`, `toggle`, `volume`, `alert`) via `pw-play` and an interactive 16-bit SNES startup/workstation TUI.
- **`grub-btrfs` Boot Menu & Automatic Boot-Guard Rollback (`sf rollback`, `lib/setup-btrfs-snapper.sh`):** Added `/etc/grub.d/41_snapshots-btrfs`, DNF5 post-transaction GRUB snapshot refresh, and `superfedora-boot-guard.service` (`/usr/local/libexec/superfedora-boot-guard`) to automatically revert to the last known-good Btrfs snapshot after 3 consecutive failed boots.

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
