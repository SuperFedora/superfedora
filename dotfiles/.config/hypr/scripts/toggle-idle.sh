#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# toggle-idle.sh — Cycle Coffee / Idle mode:
#   poweroff    -> Screensaver (2m) -> Lock (5m) -> Screen Off (10m)
#   lock        -> Screensaver (2m) -> Lock (5m) · Never powers off screen
#   screensaver -> Screensaver (2m) · Never locks or powers off screen
# Usage: toggle-idle.sh [toggle|cycle|poweroff|lock|screensaver|on|off|status]
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
MODE_FILE="$STATE_DIR/idle-mode"
STAY_AWAKE_FILE="$STATE_DIR/stay-awake"
mkdir -p "$STATE_DIR"

pgrep -x hypridle >/dev/null 2>&1 || hyprctl dispatch exec hypridle >/dev/null 2>&1 || true

cur="$(cat "$MODE_FILE" 2>/dev/null || true)"
if [[ -z "$cur" ]]; then
    [[ -f "$STAY_AWAKE_FILE" ]] && cur="screensaver" || cur="poweroff"
fi

case "${1:-toggle}" in
    status)
        echo "$cur"
        exit 0 ;;
    poweroff|normal|idle|off)
        next="poweroff" ;;
    lock|lock-only)
        next="lock" ;;
    screensaver|stay-awake|awake|on)
        next="screensaver" ;;
    *)
        case "$cur" in
            poweroff)    next="lock" ;;
            lock)        next="screensaver" ;;
            *)           next="poweroff" ;;
        esac ;;
esac

echo "$next" > "$MODE_FILE"
if [[ "$next" == "screensaver" ]]; then touch "$STAY_AWAKE_FILE"; else rm -f "$STAY_AWAKE_FILE"; fi

case "$next" in
    poweroff)
        notify-send -a SuperFedora "Idle Mode: Screen Power Off" "Screensaver (2m) -> Lock (5m) -> Screen Off (10m)" ;;
    lock)
        notify-send -a SuperFedora "Idle Mode: Lock Screen Only" "Screensaver (2m) -> Lock (5m) · Screen never powers off" ;;
    screensaver)
        notify-send -a SuperFedora "Idle Mode: Only Screensaver" "Screensaver (2m) · Never locks or powers off" ;;
esac
command -v qs >/dev/null 2>&1 && qs ipc call status refresh >/dev/null 2>&1 || true
