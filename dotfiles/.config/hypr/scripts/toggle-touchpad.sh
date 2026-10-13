#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# toggle-touchpad.sh — COSMIC TouchpadToggle (XF86TouchpadToggle)
# ==============================================================================
set -euo pipefail

state="${XDG_RUNTIME_DIR:-/tmp}/touchpad-disabled"
if [[ -f "$state" ]]; then
    hyprctl keyword 'device[elan-touchpad]:enabled' true >/dev/null
    rm -f "$state"
    notify-send -a System -t 1500 "Touchpad on"
else
    hyprctl keyword 'device[elan-touchpad]:enabled' false >/dev/null
    touch "$state"
    notify-send -a System -t 1500 "Touchpad off"
fi
