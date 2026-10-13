#!/usr/bin/env bash
# COSMIC Super+Y: toggle tiling for the whole active workspace.
# If any window is tiled, float them all; otherwise tile them all.
ws="$(hyprctl activeworkspace -j | jq -r .id)"
clients="$(hyprctl clients -j | jq -c --argjson ws "$ws" '[.[] | select(.workspace.id == $ws)]')"
tiled="$(jq '[.[] | select(.floating == false)] | length' <<<"$clients")"

if [ "$tiled" -gt 0 ]; then
    target=false   # float the tiled ones
    msg="Floating"
else
    target=true    # tile the floating ones
    msg="Tiling"
fi

cmds="$(jq -r --argjson t "$target" \
    '.[] | select(.floating == ($t)) | "dispatch togglefloating address:\(.address);"' <<<"$clients")"
[ -n "$cmds" ] && hyprctl --batch "$cmds" >/dev/null
notify-send -a Tiling -t 1200 "$msg" "Workspace $ws"
