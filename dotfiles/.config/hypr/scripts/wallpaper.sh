#!/usr/bin/env bash
# Wallpaper switcher for hyprpaper.
# Sources: ~/Pictures/Wallpapers, then Fedora's dark backgrounds.
# Usage: wallpaper.sh [next|pick|set <file>]
set -u
state="$HOME/.config/hypr/.current-wallpaper"

mapfile -t walls < <(
    find "$HOME/Pictures/Wallpapers" /usr/share/backgrounds/fedora-workstation \
        -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*_dark.webp' \) \
        2>/dev/null | sort
)
[ "${#walls[@]}" -eq 0 ] && exit 1

apply() {
    local f="$1"
    hyprctl hyprpaper wallpaper ",$f" >/dev/null
    echo "$f" > "$state"
    # Persist for next login (hyprpaper 0.8 block syntax)
    printf 'wallpaper {\n    monitor =\n    path = %s\n    fit_mode = cover\n}\n\nsplash = false\n' "$f" \
        > "$HOME/.config/hypr/hyprpaper.conf"
}

case "${1:-next}" in
    next)
        cur="$(cat "$state" 2>/dev/null)"
        next="${walls[0]}"
        for i in "${!walls[@]}"; do
            if [ "${walls[$i]}" = "$cur" ]; then
                next="${walls[$(( (i + 1) % ${#walls[@]} ))]}"; break
            fi
        done
        apply "$next" ;;
    pick)
        choice="$(printf '%s\n' "${walls[@]}" | sed "s|$HOME|~|" \
            | fuzzel --dmenu --prompt "Wallpaper  " --width 80)" || exit 0
        apply "${choice/#\~/$HOME}" ;;
    set)
        apply "$2" ;;
esac
