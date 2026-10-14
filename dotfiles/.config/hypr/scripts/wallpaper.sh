#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# wallpaper.sh — SuperFedora 16-bit theme & wallpaper switcher for Hyprland
# Usage: wallpaper.sh [next|prev|toggle|mode [day|night]|corners [square|rounded|toggle]|nightlight|pick|set <color-or-file>]
# ==============================================================================
set -euo pipefail

THEME_ENGINE="$HOME/.local/share/superfedora/lib/apply-theme.sh"
if command -v sf >/dev/null 2>&1; then
    run_theme() { sf theme "$@"; }
elif [[ -x "$THEME_ENGINE" ]]; then
    run_theme() { "$THEME_ENGINE" "$@"; }
else
    run_theme() { return 1; }
fi

apply_file() {
    local f="$1"
    hyprctl hyprpaper preload "$f" >/dev/null 2>&1 || true
    hyprctl hyprpaper wallpaper ",$f" >/dev/null 2>&1 || true
    echo "$f" > "$HOME/.config/hypr/.current-wallpaper"
    printf 'wallpaper {\n    monitor =\n    path = %s\n    fit_mode = cover\n}\n\nsplash = false\n' "$f" \
        > "$HOME/.config/hypr/hyprpaper.conf"
}

case "${1:-next}" in
    next|prev|toggle|pick|status|reload|day|night|light|dark)
        run_theme "$@" ;;
    mode)
        run_theme mode "${2:-toggle}" ;;
    corners)
        run_theme corners "${2:-toggle}" ;;
    nightlight|night-light)
        run_theme nightlight "${2:-toggle}" ;;
    set)
        if [[ -f "${2:-}" ]]; then
            apply_file "$2"
        else
            shift
            run_theme set "$@"
        fi ;;
    *)
        run_theme "$@" ;;
esac
