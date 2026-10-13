#!/usr/bin/env bash
# COSMIC-style directional focus: inside a stack (Hyprland group), left/right
# walk through the tabs first, then leave the stack like COSMIC does.
# Usage: focus.sh l|r|u|d
dir="$1"
if [ "$dir" = l ] || [ "$dir" = r ]; then
    win="$(hyprctl activewindow -j)"
    len="$(jq '.grouped | length' <<<"$win" 2>/dev/null || echo 0)"
    if [ "${len:-0}" -gt 1 ]; then
        idx="$(jq -r '.address as $a | .grouped | index($a)' <<<"$win")"
        if [ "$dir" = l ] && [ "$idx" -gt 0 ]; then
            exec hyprctl dispatch changegroupactive b >/dev/null
        elif [ "$dir" = r ] && [ "$idx" -lt $((len - 1)) ]; then
            exec hyprctl dispatch changegroupactive f >/dev/null
        fi
    fi
fi
exec hyprctl dispatch movefocus "$dir" >/dev/null
