#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# toggle-gaps.sh — Toggle between Tokyo Night gaps and zero-gap monocle layout
# ==============================================================================
set -euo pipefail

cur_gap="$(hyprctl getoption general:gaps_out -j | jq -r '.custom' | awk '{print $1}')"
if [[ "$cur_gap" == "0" ]]; then
    hyprctl --batch "keyword general:gaps_in 5; keyword general:gaps_out 10; keyword general:border_size 2" >/dev/null
else
    hyprctl --batch "keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 0" >/dev/null
fi

exit 0
