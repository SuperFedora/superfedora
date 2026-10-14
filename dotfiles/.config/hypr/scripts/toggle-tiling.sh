#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# toggle-tiling.sh — Omarchy Quattro + COSMIC Workspace Layout, Save/Restore & Minimize
# ==============================================================================
# Usage:
#   toggle-tiling.sh [cycle|back|tiling|scrolling|floating]
#   toggle-tiling.sh [save-layout|restore-layout] [workspace_id]
#   toggle-tiling.sh minimize [address]
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
LAYOUTS_JSON="$STATE_DIR/workspace-layouts.json"
mkdir -p "$STATE_DIR"

ACTION="${1:-cycle}"
[[ $# -gt 0 ]] && shift

if [[ "$ACTION" == "save-layout" ]]; then
    WS="${1:-$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')}"
    CLIENTS="$(hyprctl clients -j 2>/dev/null || echo '[]')"
    python3 - "$LAYOUTS_JSON" "$WS" "$CLIENTS" <<'PY'
import json, os, sys
path, ws, raw = sys.argv[1], str(sys.argv[2]), sys.argv[3]
d = json.load(open(path)) if os.path.exists(path) else {}
clients = [
    {"address": c.get("address"), "class": c.get("class"), "floating": bool(c.get("floating")), "at": c.get("at", [0, 0]), "size": c.get("size", [800, 600])}
    for c in json.loads(raw) if str(c.get("workspace", {}).get("id")) == ws and c.get("mapped")
]
d[ws] = clients
json.dump(d, open(path, "w"), indent=2)
print(f"[OK] Saved {len(clients)} window(s) for workspace {ws}")
PY
    notify-send -a "SuperFedora" -t 1400 "Quattro Layout Saved" "Workspace $WS window geometry saved" 2>/dev/null || true
    exit 0
fi

if [[ "$ACTION" == "restore-layout" ]]; then
    WS="${1:-$(hyprctl activeworkspace -j 2>/dev/null || echo '{"id":1}' | jq -r '.id // 1')}"
    [[ "$WS" =~ ^[0-9]+$ ]] || WS="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')"
    [[ -f "$LAYOUTS_JSON" ]] || { notify-send -a "SuperFedora" -t 1400 "Quattro Layout" "No saved layout for workspace $WS" 2>/dev/null || true; exit 0; }
    CLIENTS="$(hyprctl clients -j 2>/dev/null || echo '[]')"
    BATCH="$(python3 - "$LAYOUTS_JSON" "$WS" "$CLIENTS" <<'PY'
import json, sys
path, ws, raw = sys.argv[1], str(sys.argv[2]), sys.argv[3]
saved = json.load(open(path)).get(ws, [])
live = [c for c in json.loads(raw) if str(c.get("workspace", {}).get("id")) == ws and c.get("mapped")]
cmds = []
for s in saved:
    match = next((c for c in live if c.get("address") == s.get("address")), None)
    if not match:
        match = next((c for c in live if c.get("class") == s.get("class")), None)
    if not match:
        continue
    addr = match["address"]
    if s.get("floating"):
        x, y = s.get("at", [100, 100])
        w, h = s.get("size", [900, 650])
        cmds.append(f"dispatch setfloating address:{addr};dispatch resizewindowpixel exact {w} {h},address:{addr};dispatch movewindowpixel exact {x} {y},address:{addr};")
    else:
        cmds.append(f"dispatch settiled address:{addr};")
print("".join(cmds))
PY
)"
    [[ -n "$BATCH" ]] && hyprctl --batch "$BATCH" >/dev/null 2>&1 || true
    notify-send -a "SuperFedora" -t 1400 "Quattro Layout Restored" "Workspace $WS layout applied" 2>/dev/null || true
    exit 0
fi

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
