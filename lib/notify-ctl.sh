#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# notify-ctl.sh — Notification Center, History & Do Not Disturb Controller
# ==============================================================================
# Usage:
#   sf notify status               Print DND state, unread count, and daemon state
#   sf notify history              List notification history from Notification Center
#   sf notify dnd [on|off|toggle]  Get, set, or toggle Do Not Disturb mode
#   sf notify clear                Dismiss all active toasts and clear history
#   sf notify dismiss              Dismiss the most recent notification
#   sf notify center               Toggle the GNOME/COSMIC Notification Center popover
#   sf notify send <title> [body]  Send a desktop notification via notify-send
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
STATE_FILE="$STATE_DIR/notifications.json"
mkdir -p "$STATE_DIR"

ensure_state_file() {
    if [[ ! -f "$STATE_FILE" ]]; then
        printf '{"dnd": false, "history": []}\n' > "$STATE_FILE"
    fi
}

usage() {
    sed -n '7,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

qs_call() {
    if command -v qs >/dev/null 2>&1 && { pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1; }; then
        qs ipc --any-display call notifications "$@" >/dev/null 2>&1 || true
        return 0
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
            app = item.get("appName", "System")
            s = item.get("summary", "Notification")
            b = item.get("body", "").replace("\n", " ").strip()
            suffix = f" — {b}" if b else ""
            print(f"  [{idx:02d}] {t} [{urg}] {app}: {s}{suffix}")
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
        ;;
    history|list)
        eval "$(read_state_py status)"
        printf 'SuperFedora Notification History (DND: %s, Unread: %s)\n' "$DND" "$UNREAD"
        read_state_py history
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
