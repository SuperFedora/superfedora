# Development Toolchains & Utilities Inventory

This document details the software development toolchains, runtimes, package managers, and core system utilities installed and configured on **Fedora Linux 44**.

---

## 1. Quick Reference Matrix

| Tool / Runtime | Version | Origin / Source | Binary Path | Configuration Path |
| :--- | :--- | :--- | :--- | :--- |
| **Rustup / Rustc / Cargo** | Rustc 1.99.0 | `https://sh.rustup.rs` | `~/.cargo/bin/rustup`, `cargo` | `~/.cargo/config.toml`, `env` |
| **uv / uvx** | 0.11.26 | `https://astral.sh/uv/install.sh` | `~/.local/bin/uv` | `~/.config/uv/` |
| **Git** | 2.56.0 | Fedora official repo | `/usr/bin/git` | `~/.gitconfig` |
| **GitHub CLI (gh)** | 2.97.0 | Fedora official repo | `/usr/bin/gh` | `~/.config/gh/` |
| **Node.js & npm** | npm 12.2.0 | Fedora repo / npm update | `/usr/bin/node`, `/usr/bin/npm` | `~/.npm/`, `~/.npmrc` |
| **kitty** | 0.49.2 / 0.47.1 | `sw.kovidgoyal.net` / DNF | `~/.local/bin/kitty` | `~/.config/kitty/` |
| **btop** | 1.4.7 | Fedora official repo | `/usr/bin/btop` | `~/.config/btop/` |
| **fastfetch** | 2.68.1 | Fedora official repo | `/usr/bin/fastfetch` | `~/.config/fastfetch/` |
| **Tailscale** | 1.104.1 | `tailscale.repo` | `/usr/bin/tailscale` | `/var/lib/tailscale/` |
| **Synology Drive** | Desktop Client | Synology Direct Package | `/opt/Synology/SynologyDrive/` | `~/.SynologyDrive/` |

---

## 2. Deep Dive: Development Toolchains

### 2.1 Rust Toolchain (`rustup`, `cargo`, `rustc`)
- **Management System**: Managed via `rustup` in `~/.cargo/bin`.
- **Active Compiler**: `rustc 1.99.0 (b940084d7 2026-09-28)`
- **Cargo Version**: `cargo 1.99.0 (5f94df478 2026-08-27)`
- **Installed Targets**:
  - `x86_64-unknown-linux-gnu` (default dynamically linked host target)
  - `x86_64-unknown-linux-musl` (statically linked binary target, essential for standalone RPM/Deb binary packages and containers)
- **Installed Cargo Extensions**:
  - `cargo-binstall`: Fast binary installer for crate binaries bypassing compilation.
  - `cargo-deb`: Automated Debian package (`.deb`) generator from Cargo metadata.
  - `cargo-generate-rpm`: Automated RPM package (`.rpm`) builder for Fedora/RHEL packaging.
- **Environment Integration**:
  Included in `~/.bashrc`:
  ```bash
  . "$HOME/.cargo/env"
  export PATH="$HOME/.cargo/bin:$PATH"
  ```
- **Provisioning / Setup Command**:
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  rustup target add x86_64-unknown-linux-musl
  cargo install cargo-binstall cargo-deb cargo-generate-rpm
  ```

---

### 2.2 Python Environment & Astral `uv`
- **Utility**: `uv` and `uvx` (written in Rust, replacement for pip, pipx, poetry, and virtualenv).
- **Current Version**: `uv 0.11.26`
- **Installation Method**:
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
- **Operational Integration**:
  Powers isolated tool environments such as Mistral AI's `vibe` suite in `~/.local/share/uv/tools/`.

---

### 2.3 Version Control: Git & GitHub CLI
- **Git Package**: `git 2.56.0` (installed via `sudo dnf install git`)
  - Configured identity:
    ```bash
    git config --global user.name "Your Name"
    git config --global user.email "your.email@example.com"
    ```
- **GitHub CLI**: `gh 2.97.0` (installed via `sudo dnf install gh`)
  - Authenticated via `gh auth login`.

---

### 2.4 JavaScript: Node.js & npm
- **Packages**: `nodejs` and `npm`
- **Setup Command**:
  ```bash
  sudo dnf install -y nodejs
  sudo npm install -g npm@12.2.0
  ```

---

## 3. System Utilities & Daemons

### 3.1 Terminals
- **kitty**:
  - Default terminal emulator specified in desktop environments (`TERMINAL=kitty`).
  - Application bundle in `~/.local/kitty.app` symlinked to `~/.local/bin/kitty` (version `0.49.2`).
  - Native Fedora package also available (`kitty-0.47.1-1.fc44.x86_64`).
- **foot**:
  - Lightweight pure-Wayland terminal emulator.
  - Can be toggled on/off via `sudo dnf install foot` / `sudo dnf rm foot`.

### 3.2 System Monitoring: btop & fastfetch
- **btop (v1.4.7)**: Configured with Intel GPU monitoring and responsive ncurses TUI.
  ```bash
  sudo dnf install -y btop
  ```
- **fastfetch (v2.68.1)**: Ultra-fast hardware and OS summary generator.
  ```bash
  sudo dnf install -y fastfetch
  ```

### 3.3 Networking & Storage: Tailscale & Synology Drive
- **Tailscale (v1.104.1)**:
  - WireGuard mesh VPN daemon connected to tailnet.
  - Installed via official Tailscale repository.
  - Service management:
    ```bash
    sudo systemctl enable --now tailscaled
    sudo tailscale up
    ```
- **Synology Drive**:
  - Continuous synchronization and backup daemon.
  - Installed under `/opt/Synology/SynologyDrive`.
  - Autostart desktop entry configured for background sync.
