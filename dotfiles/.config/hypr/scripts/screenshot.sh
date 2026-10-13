#!/usr/bin/env bash
# Screenshot to ~/Pictures/Screenshots and the clipboard.
# Usage: screenshot.sh [region|window|screen]
set -u
dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$dir"
file="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"

case "${1:-region}" in
    region)
        geom="$(slurp -d -b 1a1b2666 -c 7aa2f7ff -w 2)" || exit 0
        grim -g "$geom" "$file" ;;
    window)
        geom="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        grim -g "$geom" "$file" ;;
    screen)
        mon="$(hyprctl activeworkspace -j | jq -r .monitor)"
        grim -o "$mon" "$file" ;;
esac || exit 1

wl-copy < "$file"
notify-send -a Screenshot -i "$file" "Screenshot saved" "Copied to clipboard · $(basename "$file")"
