#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# toggle-idle.sh — Toggle Keep Screen On / Stay-Awake mode (screensaver plays, never locks or powers off monitor)
# Usage: toggle-idle.sh [toggle|on|off|status]
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
STAY_AWAKE_FILE="$STATE_DIR/stay-awake"
mkdir -p "$STATE_DIR"

pgrep -x hypridle >/dev/null 2>&1 || hyprctl dispatch exec hypridle >/dev/null 2>&1 || true

case "${1:-toggle}" in
    status)
        [[ -f "$STAY_AWAKE_FILE" ]] && echo "paused" || echo "enabled"
        exit 0 ;;
    stay-awake|awake|on)
        touch "$STAY_AWAKE_FILE" ;;
    normal|idle|off)
        rm -f "$STAY_AWAKE_FILE" ;;
    *)
        if [[ -f "$STAY_AWAKE_FILE" ]]; then rm -f "$STAY_AWAKE_FILE"; else touch "$STAY_AWAKE_FILE"; fi ;;
esac

if [[ -f "$STAY_AWAKE_FILE" ]]; then
    notify-send -a SuperFedora "Keep Screen On: ON" "Screensaver will play; lock and monitor off are paused"
else
    notify-send -a SuperFedora "Keep Screen On: OFF" "Normal screen lock and monitor power-off resumed"
fi
command -v qs >/dev/null 2>&1 && qs ipc call status refresh >/dev/null 2>&1 || true
