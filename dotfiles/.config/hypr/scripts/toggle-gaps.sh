#!/usr/bin/env bash
# Toggle between Omarchy gaps and no gaps for the current session.
if [ "$(hyprctl getoption general:gaps_out -j | jq -r '.custom' | awk '{print $1}')" = "0" ]; then
    hyprctl --batch "keyword general:gaps_in 5; keyword general:gaps_out 10; keyword general:border_size 2" >/dev/null
else
    hyprctl --batch "keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 0" >/dev/null
fi
