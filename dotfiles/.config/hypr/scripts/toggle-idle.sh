#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# toggle-idle.sh — Toggle hypridle on/off (Stay-Awake mode)
# Usage: toggle-idle.sh [toggle|status]
# ==============================================================================
set -euo pipefail

if [[ "${1:-toggle}" == "status" ]]; then
    pgrep -x hypridle >/dev/null && echo "enabled" || echo "paused"
    exit 0
fi

if pgrep -x hypridle >/dev/null; then
    pkill -x hypridle
    notify-send -a System "Stay awake" "Idle, lock and screen-off are paused"
else
    hyprctl dispatch exec hypridle >/dev/null
    notify-send -a System "Idle enabled" "Screensaver, lock and screen-off resume"
fi
