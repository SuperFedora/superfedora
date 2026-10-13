#!/usr/bin/env bash
# COSMIC zoom (Super+= / Super+- / Super+. / Super+,) using Hyprland's cursor zoom.
# Usage: zoom.sh in|out|reset
cur="$(hyprctl getoption cursor:zoom_factor -j | jq -r .float)"
case "${1:-in}" in
    in)    new="$(awk -v z="$cur" 'BEGIN { z *= 1.25; if (z > 6) z = 6; print z }')" ;;
    out)   new="$(awk -v z="$cur" 'BEGIN { z /= 1.25; if (z < 1.05) z = 1; print z }')" ;;
    reset) new=1 ;;
esac
hyprctl keyword cursor:zoom_factor "$new" >/dev/null
