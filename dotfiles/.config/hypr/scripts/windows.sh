#!/usr/bin/env bash
# COSMIC Super+W stand-in: pick any open window across workspaces and jump to it.
sel="$(hyprctl clients -j | jq -r '
    sort_by(.workspace.id)[]
    | select(.workspace.id > 0 and .mapped)
    | "\(.workspace.id)\t\(.class)\t\(.title)\t\(.address)"' \
  | awk -F'\t' '{ printf "[%s]  %-18.18s  %s\t%s\n", $1, $2, $3, $4 }' \
  | fuzzel --dmenu --prompt "Windows  " --width 80 --with-nth 1 --accept-nth 2 2>/dev/null)"
[ -z "$sel" ] && exit 0
# Older fuzzel without --accept-nth returns the whole line; take the last field
addr="${sel##*$'\t'}"
hyprctl dispatch focuswindow "address:$addr" >/dev/null
