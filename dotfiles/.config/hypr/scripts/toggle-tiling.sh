#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# toggle-tiling.sh — Omarchy + COSMIC Workspace Layout & Minimize Helper
# ==============================================================================
# Usage:
#   toggle-tiling.sh [cycle|back|tiling|scrolling|floating]
#   toggle-tiling.sh minimize [address]
# ==============================================================================
set -euo pipefail

ACTION="${1:-cycle}"
[[ $# -gt 0 ]] && shift

if [[ -x "$HOME/.local/bin/superfedora" ]]; then
    if [[ "$ACTION" == "minimize" ]]; then
        exec "$HOME/.local/bin/superfedora" dock minimize "$@"
    else
        exec "$HOME/.local/bin/superfedora" dock layout "$ACTION" "$@"
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CTL="$(realpath "$SCRIPT_DIR/../../../../lib/panel-ctl.sh" 2>/dev/null || true)"
if [[ -n "$REPO_CTL" && -x "$REPO_CTL" ]]; then
    if [[ "$ACTION" == "minimize" ]]; then
        exec "$REPO_CTL" minimize "$@"
    else
        exec "$REPO_CTL" layout "$ACTION" "$@"
    fi
fi
