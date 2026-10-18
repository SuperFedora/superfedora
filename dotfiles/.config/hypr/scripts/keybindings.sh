#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# keybindings.sh — Searchable Fuzzel HUD for all described Hyprland keybindings
# ==============================================================================
set -euo pipefail

[[ -x "$HOME/.local/bin/superbar" ]] && exec "$HOME/.local/bin/superbar" keybindings "$@"

hyprctl binds -j | jq -r '
  def mods($m):
    [ (if ($m / 64 | floor) % 2 == 1 then "SUPER" else empty end),
      (if ($m / 4  | floor) % 2 == 1 then "CTRL"  else empty end),
      (if ($m / 8  | floor) % 2 == 1 then "ALT"   else empty end),
      (if ($m      | floor) % 2 == 1 then "SHIFT" else empty end) ] | join(" + ");
  .[] | select(.has_description == true)
      | (mods(.modmask)) as $m
      | "\(if $m == "" then "" else $m + " + " end)\(.key)\t\(.description)"' \
  | awk -F'\t' '!seen[$0]++ { printf "%-28s %s\n", $1, $2 }' \
  | fuzzel --dmenu --prompt "Keys  " --width 70 --lines 20 >/dev/null || true
