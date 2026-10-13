#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# windows.sh — COSMIC Super+W window & workspace overview picker
# ==============================================================================
set -euo pipefail

sel="$(hyprctl clients -j | jq -r '
    sort_by(.workspace.id)[]
    | select(.workspace.id > 0 and .mapped)
    | "\(.workspace.id)\t\(.class)\t\(.title)\t\(.address)"' \
  | awk -F'\t' '{ printf "[%s]  %-18.18s  %s\t%s\n", $1, $2, $3, $4 }' \
  | fuzzel --dmenu --prompt "Windows  " --width 80 --with-nth 1 --accept-nth 2 2>/dev/null || true)"
[[ -z "$sel" ]] && exit 0
addr="${sel##*$'\t'}"
hyprctl dispatch focuswindow "address:$addr" >/dev/null
