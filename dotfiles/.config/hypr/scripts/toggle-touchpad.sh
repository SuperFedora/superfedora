#!/usr/bin/env bash
# COSMIC TouchpadToggle (XF86TouchpadToggle).
state="${XDG_RUNTIME_DIR:-/tmp}/touchpad-disabled"
if [ -f "$state" ]; then
    hyprctl keyword 'device[elan-touchpad]:enabled' true >/dev/null
    rm -f "$state"
    notify-send -a System -t 1500 "Touchpad on"
else
    hyprctl keyword 'device[elan-touchpad]:enabled' false >/dev/null
    touch "$state"
    notify-send -a System -t 1500 "Touchpad off"
fi
