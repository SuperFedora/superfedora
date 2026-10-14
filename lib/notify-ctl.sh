#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# notify-ctl.sh — 16-Bit Workstation Notifications, Cast Comms & Banner Controller
# ==============================================================================
# Usage:
#   sf notify status                        Print DND, unread count & daemon state
#   sf notify history                       List notification history from Center
#   sf notify dnd [on|off|toggle]           Get, set, or toggle Do Not Disturb
#   sf notify clear                         Dismiss all active toasts & clear history
#   sf notify dismiss                       Dismiss the most recent notification
#   sf notify center                        Toggle the Notification Center popover
#   sf notify send <title> [body]           Send a desktop notification via notify-send
#   sf notify --banner <ready|warning|update|checkpoint>  Trigger 16-bit center banner
#   sf notify --cast <ai|security|builder|engineer|app|all> Trigger 16-bit cast comms test
# ==============================================================================
set -euo pipefail

SF_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/bin:/bin:$PATH"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
STATE_FILE="$STATE_DIR/notifications.json"
mkdir -p "$STATE_DIR"

ensure_state_file() {
    if [[ ! -f "$STATE_FILE" ]]; then
        printf '{"dnd": false, "history": []}\n' > "$STATE_FILE"
    fi
}

usage() {
    sed -n '7,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

qs_call() {
    local qbin=""
    command -v qs >/dev/null 2>&1 && qbin="qs" || { command -v quickshell >/dev/null 2>&1 && qbin="quickshell"; }
    if [[ -n "$qbin" ]] && { pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1; }; then
        "$qbin" ipc --any-display call notifications "$@" >/dev/null 2>&1 && return 0
    fi
    return 1
}

read_state_py() {
    ensure_state_file
    python3 - "$STATE_FILE" "$1" "${2:-}" << 'PY'
import json, os, sys

path = sys.argv[1]
mode = sys.argv[2]
arg = sys.argv[3] if len(sys.argv) > 3 else ""

try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    data = {"dnd": False, "history": []}

dnd = bool(data.get("dnd", False))
history = data.get("history", [])
if not isinstance(history, list):
    history = []

if mode == "status":
    print(f"DND={'on' if dnd else 'off'}")
    print(f"UNREAD={len(history)}")
elif mode == "history":
    if not history:
        print("  [--] No unread notifications in history.")
    else:
        for idx, item in enumerate(history, 1):
            t = item.get("time", "--:--")
            urg = item.get("urgency", "normal").upper()
            role = item.get("roleTitle", item.get("role", "SYS ENG")).upper()
            app = item.get("appName", "System")
            s = item.get("summary", "Notification")
            b = item.get("body", "").replace("\n", " ").strip()
            suffix = f" — {b}" if b else ""
            print(f"  [{idx:02d}] {t} [{role} // {app}] ({urg}): {s}{suffix}")
elif mode == "set_dnd":
    new_dnd = (not dnd) if arg == "toggle" else (arg in ("on", "1", "true"))
    data["dnd"] = new_dnd
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh)
    print("on" if new_dnd else "off")
elif mode == "clear":
    data["history"] = []
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh)
elif mode == "dismiss_one":
    if history:
        data["history"] = history[1:]
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(data, fh)
PY
}

trigger_banner() {
    local kind="${1:-ready}"
    case "${kind,,}" in
        ready|boot|login|unlock)
            qs_call banner ready || "$SF_ROOT/lib/sfx.sh" play startup >/dev/null 2>&1 || true
            printf '  [OK] Banner triggered: R E A D Y\n' ;;
        warn|warning|critical|alert|danger)
            qs_call banner warning || "$SF_ROOT/lib/sfx.sh" play alert >/dev/null 2>&1 || true
            printf '  [OK] Banner triggered: W A R N I N G\n' ;;
        update|forge|complete)
            qs_call banner update || "$SF_ROOT/lib/sfx.sh" play confirm >/dev/null 2>&1 || true
            printf '  [OK] Banner triggered: U P D A T E   C O M P L E T E\n' ;;
        checkpoint|snapshot|btrfs|saved)
            qs_call banner checkpoint || "$SF_ROOT/lib/sfx.sh" play confirm >/dev/null 2>&1 || true
            printf '  [OK] Banner triggered: C H E C K P O I N T   S A V E D\n' ;;
        *)
            echo "Usage: sf notify --banner <ready|warning|update|checkpoint>" >&2
            exit 2 ;;
    esac
}

trigger_cast() {
    local role="${1:-all}"
    case "${role,,}" in
        ai|agent|openclaw|agy|claude|ollama|pi)
            qs_call cast ai || { command -v notify-send >/dev/null 2>&1 && notify-send -a "AGY // OPENCLAW" "Neural Harness Link Active" "Context indexed. Ready for code synthesis and workstation automation." || true; }
            printf '  [OK] Cast comms triggered: AI Agent (Bottom-Center)\n' ;;
        sec|security|alert|polkit|firewall|critical)
            qs_call cast security || { command -v notify-send >/dev/null 2>&1 && notify-send -u critical -a "POLKIT // GUARD" "Privilege Escalation Check" "Critical telemetry & policy guard monitoring active." || true; }
            printf '  [OK] Cast comms triggered: Security / System Alert (Top-Center + WARNING Banner)\n' ;;
        build|builder|forge|dnf|cargo|gcc)
            qs_call cast builder || { command -v notify-send >/dev/null 2>&1 && notify-send -a "SF FORGE" "Native Target Compiled" "Built with -O3 -march=native -flto=auto and linked via mold." || true; }
            printf '  [OK] Cast comms triggered: Builder / Forge (Top-Right)\n' ;;
        eng|engineer|sys|system|superfedora|btrfs)
            qs_call cast engineer || { command -v notify-send >/dev/null 2>&1 && notify-send -a "SUPERFEDORA" "Btrfs Checkpoint Verified" "Workstation subvolume state synchronized and ready for rollback." || true; }
            printf '  [OK] Cast comms triggered: System Engineer (Top-Right)\n' ;;
        app|apps|firefox|discord|slack|spotify)
            qs_call cast app || { command -v notify-send >/dev/null 2>&1 && notify-send -a "FIREFOX" "External App Transmission" "Incoming desktop application relay framed in 16-bit scanline bezel." || true; }
            printf '  [OK] Cast comms triggered: App Comms (Top-Right)\n' ;;
        all|test)
            qs_call cast all || true
            printf '  [OK] Cast comms triggered: Full Workstation Cast Showcase\n' ;;
        *)
            echo "Usage: sf notify --cast <ai|security|builder|engineer|app|all>" >&2
            exit 2 ;;
    esac
}

ACTION="${1:-status}"
[[ $# -gt 0 ]] && shift
DND="off"
UNREAD="0"

case "$ACTION" in
    status)
        eval "$(read_state_py status)"
        daemon_state="offline"
        { pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1; } && daemon_state="running (quickshell)"
        printf '  [OK] Notification Server : %s\n' "$daemon_state"
        printf '  [OK] Do Not Disturb      : %s\n' "$DND"
        printf '  [OK] Unread in Center    : %s\n' "$UNREAD"
        printf '  [OK] Cast Portrait Dir   : %s\n' "$STATE_DIR/cast"
        ;;
    history|list)
        eval "$(read_state_py status)"
        printf 'SuperFedora Notification History (DND: %s, Unread: %s)\n' "$DND" "$UNREAD"
        read_state_py history
        ;;
    --banner|banner)
        trigger_banner "${1:-ready}"
        ;;
    --banner=*)
        trigger_banner "${ACTION#*=}"
        ;;
    --cast|cast|character|role)
        trigger_cast "${1:-all}"
        ;;
    --cast=*)
        trigger_cast "${ACTION#*=}"
        ;;
    test|preview)
        target="${1:-all}"
        case "${target,,}" in
            ready|warn|warning|update|checkpoint) trigger_banner "$target" ;;
            *) trigger_cast "$target" ;;
        esac
        ;;
    dnd)
        sub="${1:-toggle}"
        case "$sub" in
            on|off|toggle)
                new_state="$(read_state_py set_dnd "$sub")"
                qs_call setDnd "$new_state" || true
                printf '  [OK] Do Not Disturb: %s\n' "$new_state"
                ;;
            status|get)
                eval "$(read_state_py status)"
                echo "$DND"
                ;;
            *)
                echo "Usage: sf notify dnd [on|off|toggle|status]" >&2
                exit 2
                ;;
        esac
        ;;
    clear|dismiss-all|dismissAll)
        read_state_py clear
        qs_call dismissAll || true
        printf '  [OK] Cleared all notifications.\n'
        ;;
    dismiss)
        if ! qs_call dismiss; then
            read_state_py dismiss_one
        fi
        printf '  [OK] Dismissed latest notification.\n'
        ;;
    center|toggle)
        qs_call toggle || true
        printf '  [OK] Toggled Notification Center.\n'
        ;;
    send)
        title="${1:-SuperFedora}"
        body="${2:-}"
        if command -v notify-send >/dev/null 2>&1; then
            if [[ -n "$body" ]]; then
                notify-send -a "SuperFedora" "$title" "$body"
            else
                notify-send -a "SuperFedora" "$title"
            fi
            printf '  [OK] Sent notification: %s\n' "$title"
        else
            echo "  [FAIL] notify-send not installed" >&2
            exit 1
        fi
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "unknown notify action: $ACTION" >&2
        usage >&2
        exit 2
        ;;
esac
