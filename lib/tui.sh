#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# tui.sh — 16-Bit SNES Startup Control Deck & Btrfs Snapshot Rollback TUI
# ==============================================================================
# Usage:
#   sf tui [status|banner|rollback]     Launch 16-bit SNES Control Deck TUI
#   sf welcome                          Launch startup welcome & setup TUI
#   sf rollback [--list|--create|--baseline|<id>] Manage or revert Btrfs snapshots
# ==============================================================================
set -euo pipefail

SF_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
VERSION="$(tr -d '[:space:]' < "$SF_ROOT/VERSION" 2>/dev/null || echo 0.5.0)"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/bin:/bin:$PATH"

if [[ -t 1 && "${NO_COLOR:-0}" != "1" ]]; then
    B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
    C_MAG=$'\033[38;5;141m'; C_BLU=$'\033[38;5;111m'; C_CYN=$'\033[38;5;117m'
    C_GRN=$'\033[38;5;114m'; C_YLW=$'\033[38;5;221m'
else
    B=""; D=""; R=""; C_MAG=""; C_BLU=""; C_CYN=""; C_GRN=""; C_YLW=""
fi

load_summary() {
    THEME_COLOR="01-super-blue"; THEME_MODE="dark"; THEME_CORNERS="square"
    # shellcheck disable=SC1090
    [[ -f "$STATE_DIR/theme.env" ]] && source "$STATE_DIR/theme.env"
    SFX_STATE="$("$SF_ROOT/lib/sfx.sh" status 2>/dev/null || echo on)"
    CPU_NAME="$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null || uname -m)"
    FORGE_CNT=0
    [[ -d "$STATE_DIR/source-built" ]] && FORGE_CNT="$(find "$STATE_DIR/source-built" -name '*.stamp' 2>/dev/null | wc -l)"
    BASELINE_SNAP="$(cat "$STATE_DIR/last_pre_install_snapshot" 2>/dev/null || echo none)"
    if systemctl is-enabled superfedora-boot-guard.service >/dev/null 2>&1; then
        GUARD_ST="enabled"
    else
        GUARD_ST="ready"
    fi
}

print_banner() {
    load_summary
    printf '%s╔══════════════════════════════════════════════════════════════════════════╗%s\n' "$C_MAG$B" "$R"
    printf '%s║  [::] SUPER FEDORA 16-BIT ENTERTAINMENT & WORKSTATION SYSTEM  v%-9s ║%s\n' "$C_MAG$B" "$VERSION" "$R"
    printf '%s╠══════════════════════════════════════════════════════════════════════════╣%s\n' "$C_MAG$B" "$R"
    printf '%s║%s  %sCPU%s      : %-60s %s║%s\n' "$C_MAG$B" "$R" "$C_CYN$B" "$R" "${CPU_NAME:0:60}" "$C_MAG$B" "$R"
    printf '%s║%s  %sTheme%s    : %-22s %sMode%s: %-8s %sCorners%s: %-13s %s║%s\n' \
        "$C_MAG$B" "$R" "$C_CYN$B" "$R" "$THEME_COLOR" "$C_CYN$B" "$R" "$THEME_MODE" "$C_CYN$B" "$R" "$THEME_CORNERS" "$C_MAG$B" "$R"
    printf '%s║%s  %sForge%s    : %-22s %sSFX%s : %-8s %sGuard%s  : %-13s %s║%s\n' \
        "$C_MAG$B" "$R" "$C_CYN$B" "$R" "$FORGE_CNT native binaries" "$C_CYN$B" "$R" "$SFX_STATE" "$C_CYN$B" "$R" "$GUARD_ST (#$BASELINE_SNAP)" "$C_MAG$B" "$R"
    printf '%s╚══════════════════════════════════════════════════════════════════════════╝%s\n' "$C_MAG$B" "$R"
}

run_rollback() {
    local sub="${1:-}"
    case "$sub" in
        --list|list|status)
            "$SF_ROOT/lib/setup-btrfs-snapper.sh" --status
            echo
            if command -v snapper >/dev/null 2>&1; then
                snapper -c root list 2>/dev/null || sudo -n snapper -c root list 2>/dev/null || echo "Run with sudo to view root snapshots."
            else
                echo "snapper is not installed yet (run: sudo bash $SF_ROOT/lib/setup-btrfs-snapper.sh)"
            fi
            return 0 ;;
        --create|create)
            shift || true
            local desc="${*:-SuperFedora manual checkpoint}"
            local num
            num="$(sudo snapper -c root create -t single -p -d "$desc")"
            echo "[OK] Created Btrfs snapshot #$num ($desc)"
            return 0 ;;
        --setup|setup)
            sudo bash "$SF_ROOT/lib/setup-btrfs-snapper.sh"
            return 0 ;;
        --baseline|baseline)
            sub="$(cat "$STATE_DIR/last_pre_install_snapshot" 2>/dev/null || true)"
            [[ -n "$sub" ]] || { echo "error: no pre-install baseline snapshot recorded in $STATE_DIR" >&2; exit 1; } ;;
    esac

    if [[ "$sub" =~ ^[0-9]+$ ]]; then
        echo "Reverting root filesystem to Btrfs Snapshot #$sub..."
        if [[ -t 0 ]]; then
            read -r -p "Confirm rollback to snapshot #$sub? [y/N] " ans
            [[ "$ans" =~ ^[Yy]$ ]] || exit 0
        fi
        sudo snapper -c root undochange "${sub}..0"
        echo "[OK] Reverted to snapshot #$sub. Reboot to complete recovery."
        return 0
    fi

    if [[ ! -t 0 ]]; then
        local snap
        snap="$(cat "$STATE_DIR/last_pre_install_snapshot" 2>/dev/null || true)"
        [[ -n "$snap" ]] || { echo "error: no pre-install snapshot recorded in $STATE_DIR" >&2; exit 1; }
        echo "No TTY detected; use 'sf rollback $snap' or 'sf rollback --list'."
        exit 0
    fi

    print_banner
    printf '\n%s━━ Btrfs Snapshot & Boot-Guard Recovery Manager%s\n' "$C_BLU$B" "$R"
    "$SF_ROOT/lib/setup-btrfs-snapper.sh" --status
    echo
    snapper -c root list 2>/dev/null || sudo snapper -c root list 2>/dev/null || true
    printf '\n  %s[c]%s Create checkpoint snapshot   %s[b]%s Rollback to pre-install baseline (#%s)\n' "$C_CYN$B" "$R" "$C_YLW$B" "$R" "$BASELINE_SNAP"
    printf '  %s[g]%s Configure grub-btrfs & Guard %s[#]%s Enter snapshot number to restore   %s[q]%s Quit\n\n' "$C_GRN$B" "$R" "$C_MAG$B" "$R" "$D" "$R"
    read -r -p "Select action or snapshot #: " pick_act
    case "$pick_act" in
        c|C) read -r -p "Snapshot description: " d; run_rollback --create "${d:-Manual checkpoint}" ;;
        b|B) run_rollback --baseline ;;
        g|G) run_rollback --setup ;;
        [0-9]*) run_rollback "$pick_act" ;;
        *) exit 0 ;;
    esac
}

run_interactive_tui() {
    "$SF_ROOT/lib/sfx.sh" play startup 2>/dev/null || true
    while true; do
        clear 2>/dev/null || true
        print_banner
        printf '\n  %s[1]%s 16-Bit Theme & Day/Night Studio (Palette, Day/Night, Square/Rounded, Nightlight)\n' "$C_CYN$B" "$R"
        printf '  %s[2]%s SuperFedora Forge (-march=native Source Compiler & Presets)\n' "$C_CYN$B" "$R"
        printf '  %s[3]%s Hardware & Network TUIs (wiremix Audio, wlctl Wi-Fi, bluetui Bluetooth, btop)\n' "$C_CYN$B" "$R"
        printf '  %s[4]%s Btrfs Snapshots, grub-btrfs & Boot-Guard Rollback Manager\n' "$C_CYN$B" "$R"
        printf '  %s[5]%s Omarchy Quattro Dock & Workspace Layout Controls\n' "$C_CYN$B" "$R"
        printf '  %s[6]%s 16-Bit SNES Sound Engine (%s) & IdleScreen Setup\n' "$C_CYN$B" "$R" "$SFX_STATE"
        printf '  %s[7]%s Workstation Health Audit (sf status)\n' "$C_CYN$B" "$R"
        printf '  %s[q]%s Exit Cartridge Deck\n\n' "$D" "$R"
        read -r -p "SuperFedora Deck > " choice || exit 0
        "$SF_ROOT/lib/sfx.sh" play click 2>/dev/null || true
        case "$choice" in
            1)
                printf '\n  [n] Next Palette  [m] Toggle Day/Night  [c] Toggle Square/Rounded  [l] Toggle Nightlight  [s] Set Preset\n'
                read -r -p "  Theme Action > " ta
                case "$ta" in
                    n) "$SF_ROOT/lib/apply-theme.sh" next ;;
                    m) "$SF_ROOT/lib/apply-theme.sh" toggle ;;
                    c) "$SF_ROOT/lib/apply-theme.sh" corners toggle ;;
                    l) "$SF_ROOT/lib/apply-theme.sh" nightlight toggle ;;
                    s) read -r -p "  Name (snes|tokyo-night|catppuccin|nord|01..08): " tn; "$SF_ROOT/lib/apply-theme.sh" "$tn" ;;
                esac
                read -r -p "Press Enter to continue..." _ ;;
            2)
                "$SF_ROOT/lib/forge.sh" status
                read -r -p "Enter target or owner/repo to forge (or Enter to skip): " ft
                [[ -n "$ft" ]] && "$SF_ROOT/lib/forge.sh" "$ft"
                read -r -p "Press Enter to continue..." _ ;;
            3)
                printf '\n  [a] wiremix (Audio)  [w] wlctl (Wi-Fi)  [b] bluetui (Bluetooth)  [t] btop (Monitor)\n'
                read -r -p "  Launch TUI > " tt
                case "$tt" in
                    a) wiremix || true ;; w) wlctl || true ;; b) bluetui || true ;; t) btop || true ;;
                esac ;;
            4) run_rollback ;;
            5)
                "$SF_ROOT/lib/panel-ctl.sh" status
                printf '\n  [b/t/l/r] Dock Edge  [a] Toggle Autohide  [w] Cycle Workspace Layout\n'
                read -r -p "  Dock Action > " da
                case "$da" in
                    b) "$SF_ROOT/lib/panel-ctl.sh" position bottom ;;
                    t) "$SF_ROOT/lib/panel-ctl.sh" position top ;;
                    l) "$SF_ROOT/lib/panel-ctl.sh" position left ;;
                    r) "$SF_ROOT/lib/panel-ctl.sh" position right ;;
                    a) "$SF_ROOT/lib/panel-ctl.sh" autohide toggle ;;
                    w) "$SF_ROOT/lib/panel-ctl.sh" layout cycle ;;
                esac
                read -r -p "Press Enter to continue..." _ ;;
            6)
                "$SF_ROOT/lib/sfx.sh" toggle
                read -r -p "Press Enter to continue..." _ ;;
            7)
                "$SF_ROOT/bin/superfedora" status || true
                read -r -p "Press Enter to continue..." _ ;;
            q|Q|exit) exit 0 ;;
        esac
    done
}

CMD="${1:-tui}"
[[ $# -gt 0 ]] && shift
if [[ "$CMD" == "tui" || "$CMD" == "welcome" || "$CMD" == "deck" ]] && [[ $# -gt 0 ]]; then
    CMD="$1"; shift
fi
case "$CMD" in
    status|banner) print_banner ;;
    rollback)      run_rollback "$@" ;;
    tui|welcome|deck)
        if [[ -t 0 && -t 1 ]]; then run_interactive_tui; else print_banner; fi ;;
    -h|--help|help)
        sed -n '7,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
    *)
        print_banner ;;
esac
