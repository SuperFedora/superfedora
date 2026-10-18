#!/usr/bin/env bash
# ==============================================================================
# install-dotfiles.sh — deploy SuperFedora desktop configs into a home directory
# ==============================================================================
# Copies everything under dotfiles/ into $HOME, mirroring the layout
# (dotfiles/.config/hypr/... -> ~/.config/hypr/...). Real copies, no symlinks:
# the result is exactly what an installed system looks like.
#
# Any existing file that differs is backed up first to
#   ~/.config/superfedora/backups/<timestamp>/<relative path>
#
# Usage:
#   superfedora dotfiles            deploy, then reload a running session
#   superfedora dotfiles --check    report drift between repo and $HOME
#                                          (exit 1 if anything differs)
#   superfedora dotfiles --no-reload  deploy without touching the session
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
SRC="$REPO_DIR/dotfiles"
if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
else
    TARGET_USER="$(id -un)"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-$HOME}"
STATE_DIR="$TARGET_HOME/.config/superfedora"
VERSION="$(tr -d '[:space:]' < "$REPO_DIR/VERSION" 2>/dev/null || echo unknown)"

MODE="deploy"
RELOAD=1
for arg in "$@"; do
    case "$arg" in
        --check) MODE="check" ;;
        --no-reload) RELOAD=0 ;;
        -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

[[ -d "$SRC" ]] || { echo "error: $SRC not found" >&2; exit 1; }

mapfile -d '' FILES < <(cd "$SRC" && find . -type f -print0 | sort -z)

same_file() {
    if command -v cmp >/dev/null 2>&1; then
        cmp -s "$1" "$2"
    else
        [[ "$(sha256sum "$1" | cut -d' ' -f1)" == "$(sha256sum "$2" | cut -d' ' -f1)" ]]
    fi
}

# ------------------------------------------------------------------------------
# --check: show what differs between the repo and the live home directory
# ------------------------------------------------------------------------------
if [[ "$MODE" == "check" ]]; then
    drift=0
    for rel in "${FILES[@]}"; do
        rel="${rel#./}"
        live="$TARGET_HOME/$rel"
        if [[ ! -e "$live" ]]; then
            echo "missing   ~/$rel"; drift=1
        elif ! same_file "$SRC/$rel" "$live"; then
            if [[ -f "$STATE_DIR/theme.env" || -f "$STATE_DIR/defaults.env" ]]; then
                case "$rel" in
                    .config/hypr/hyprpaper.conf|.config/hypr/hyprlock.conf|.config/hypr/hyprqt6engine.conf|.config/hypr/conf/looknfeel.conf|.config/quickshell/Theme.qml|.config/fuzzel/fuzzel.ini|.config/kitty/kitty.conf|.config/gtk-3.0/settings.ini|.config/gtk-4.0/settings.ini|.config/mimeapps.list)
                        continue ;;
                esac
            fi
            echo "modified  ~/$rel"; drift=1
        fi
    done
    # Files that exist live inside managed directories but not in the repo
    for dir in .config/hypr .config/quickshell .config/fuzzel .config/kitty .config/xdg-desktop-portal; do
        [[ -d "$TARGET_HOME/$dir" ]] || continue
        while IFS= read -r -d '' f; do
            rel="${f#"$TARGET_HOME"/}"
            case "$rel" in *.bak|*~|.config/hypr/.current-wallpaper) continue ;; esac
            [[ -e "$SRC/$rel" ]] || { echo "untracked ~/$rel"; drift=1; }
        done < <(find "$TARGET_HOME/$dir" -type f -print0)
    done
    if [[ $drift -eq 0 ]]; then
        echo "In sync with SuperFedora v$VERSION"
    fi
    exit $drift
fi

# ------------------------------------------------------------------------------
# deploy
# ------------------------------------------------------------------------------
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$STATE_DIR/backups/$STAMP"
changed=0
shell_changed=0
units_changed=0

for rel in "${FILES[@]}"; do
    rel="${rel#./}"
    dst="$TARGET_HOME/$rel"
    if [[ -e "$dst" ]] && same_file "$SRC/$rel" "$dst"; then
        continue
    fi
    if [[ "$rel" == ".config/mimeapps.list" && -f "$dst" && -f "$STATE_DIR/defaults.env" ]]; then
        continue
    fi
    if [[ -e "$dst" ]]; then
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a "$dst" "$BACKUP/$rel"
    fi
    mkdir -p "$(dirname "$dst")"
    install -m "$(stat -c %a "$SRC/$rel")" "$SRC/$rel" "$dst"
    echo "  installed ~/$rel"
    changed=$((changed + 1))
    [[ "$rel" == .config/quickshell/* ]] && shell_changed=1
    [[ "$rel" == .config/systemd/user/* || "$rel" == .config/user-tmpfiles.d/* ]] && units_changed=1
done

for dir in .config/quickshell .config/hypr/conf .config/hypr/scripts .config/systemd/user .config/user-tmpfiles.d .config/xdg-desktop-portal; do
    [[ -d "$TARGET_HOME/$dir" ]] || continue
    while IFS= read -r -d '' f; do
        rel="${f#"$TARGET_HOME"/}"
        case "$rel" in *.bak|*~|.config/hypr/.current-wallpaper) continue ;; esac
        if [[ ! -e "$SRC/$rel" ]]; then
            mkdir -p "$BACKUP/$(dirname "$rel")"
            mv "$f" "$BACKUP/$rel"
            echo "  removed   ~/$rel"
            changed=$((changed + 1))
            [[ "$rel" == .config/quickshell/* ]] && shell_changed=1
            [[ "$rel" == .config/systemd/user/* || "$rel" == .config/user-tmpfiles.d/* ]] && units_changed=1
        fi
    done < <(find "$TARGET_HOME/$dir" -maxdepth 2 -type f -print0)
done
for obs in .local/share/applications/superfedora-settings.desktop .local/share/applications/superdock.desktop .local/bin/sf-ollama .local/bin/sf; do
    if [[ ( -e "$TARGET_HOME/$obs" || -L "$TARGET_HOME/$obs" ) && ! -e "$SRC/$obs" ]]; then
        mkdir -p "$BACKUP/$(dirname "$obs")"
        mv "$TARGET_HOME/$obs" "$BACKUP/$obs"
        echo "  removed   ~/$obs"
        changed=$((changed + 1))
    fi
done

if [[ -f "$STATE_DIR/theme.env" && -x "$REPO_DIR/lib/apply-theme.sh" && $EUID -ne 0 ]]; then
    "$REPO_DIR/lib/apply-theme.sh" reload || true
fi

if [[ $units_changed -eq 1 ]]; then
    if [[ $EUID -eq 0 && "$TARGET_USER" != root ]]; then
        uid="$(id -u "$TARGET_USER")"
        [[ -d "/run/user/$uid" ]] && sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/$uid" sh -c 'systemd-tmpfiles --user --create 2>/dev/null || true; systemctl --user daemon-reload 2>/dev/null || true; systemctl --user enable superfedora-session.target supershell.service idlescreen.service 2>/dev/null || true; systemctl --user enable --now supertheme-sun.timer superforge-check.timer 2>/dev/null || true' || true
    else
        systemd-tmpfiles --user --create 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable superfedora-session.target supershell.service idlescreen.service 2>/dev/null || true
        systemctl --user enable --now supertheme-sun.timer superforge-check.timer 2>/dev/null || true
    fi
    echo "systemd user units & tmpfiles reloaded"
fi

mkdir -p "$STATE_DIR" "$TARGET_HOME/.cache/thumbnails"/{normal,large,x-large,xx-large}
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$TARGET_HOME/.local/share/applications" 2>/dev/null || true
echo "$VERSION" > "$STATE_DIR/version"
if [[ $EUID -eq 0 && "$TARGET_USER" != root ]]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$STATE_DIR" "$TARGET_HOME/.config" "$TARGET_HOME/.cache/thumbnails"
    [[ -d "$TARGET_HOME/.local/bin" ]] && chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/bin"
    [[ -d "$TARGET_HOME/.local/share/applications" ]] && chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/share/applications"
fi

echo "SuperFedora v$VERSION dotfiles: $changed file(s) updated"
[[ -d "$BACKUP" ]] && echo "Previous versions backed up to $BACKUP"

# ------------------------------------------------------------------------------
# Reload a running Hyprland session so changes take effect immediately
# ------------------------------------------------------------------------------
target_rt="${XDG_RUNTIME_DIR:-/run/user/$(id -u "$TARGET_USER")}"
[[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -d "$target_rt/hypr" ]] && HYPRLAND_INSTANCE_SIGNATURE="$(find "$target_rt/hypr" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | head -n1 || true)" && export HYPRLAND_INSTANCE_SIGNATURE
if [[ $RELOAD -eq 1 && $changed -gt 0 && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null; then
    hyprctl reload >/dev/null
    errs="$(hyprctl configerrors 2>/dev/null | sed '/^\s*$/d')"
    if [[ -n "$errs" ]]; then
        echo "Hyprland config errors:" >&2
        echo "$errs" >&2
        exit 1
    fi
    echo "Hyprland reloaded (no config errors)"
    if [[ $shell_changed -eq 1 ]] && [ ! -f "$target_rt/superfedora.locked" ] && command -v qs >/dev/null && { pgrep -x quickshell >/dev/null || pgrep -x qs >/dev/null; }; then
        qs ipc call theme reload >/dev/null 2>&1 || true
        qs ipc call status refresh >/dev/null 2>&1 || true
        echo "Quickshell state refreshed via IPC"
    fi
fi
