#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# panel-ctl.sh — Omarchy-Style Dock & Workspace Layout Engine
# ==============================================================================
# Usage:
#   superfedora dock status                           Print dock & workspace layout status
#   superfedora dock position <bottom|top|left|right> Move dock to a screen edge
#   superfedora dock autohide <on|off|toggle>         Configure dock auto-hide
#   superfedora dock always <on|off|toggle>           Show dock on all workspaces or floating-only
#   superfedora dock pinned <id...>                   Replace pinned .desktop app IDs
#   superfedora dock pin <id> [index]                 Pin a .desktop app to the dock
#   superfedora dock unpin <id>                       Remove a pinned .desktop app
#   superfedora dock apps                             Toggle fullscreen Launchpad App Grid
#   superfedora dock reset                            Restore default dock config
#   superfedora dock layout [cycle|tiling|scrolling|floating] [ws]  Switch workspace layout
#   superfedora dock minimize [address]               Minimize window to dock (special:minimized)
# ==============================================================================
set -euo pipefail

STATE_DIR="$HOME/.config/superfedora"
DOCK_JSON="$STATE_DIR/dock.json"
MODES_JSON="$STATE_DIR/workspace-modes.json"
mkdir -p "$STATE_DIR"

write_default() {
    cat > "$DOCK_JSON" <<'EOF'
{
  "position": "bottom",
  "autohide": false,
  "showAlways": true,
  "pinned": [
    "kitty",
    "org.mozilla.firefox",
    "com.google.Chrome",
    "yazi",
    "nvim",
    "btop"
  ]
}
EOF
}

[[ -f "$DOCK_JSON" ]] || write_default
[[ -f "$MODES_JSON" ]] || echo '{"default":"dwindle","workspaces":{}}' > "$MODES_JSON"

notify_dock() {
    if command -v qs >/dev/null 2>&1 && pgrep -x quickshell >/dev/null 2>&1; then
        qs ipc call dock reload >/dev/null 2>&1 || true
        qs ipc call workspaces reload >/dev/null 2>&1 || true
    fi
}

cmd_layout() {
    local sub="${1:-cycle}"
    local ws="${2:-}"
    if [[ -z "$ws" ]]; then
        ws="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')"
    fi
    local next_mode
    next_mode="$(python3 - "$MODES_JSON" "$sub" "$ws" <<'PY'
import json, os, sys
path, sub, ws = sys.argv[1], sys.argv[2].lower(), str(sys.argv[3])
d = json.load(open(path)) if os.path.exists(path) else {"default": "dwindle", "workspaces": {}}
ws_map = d.setdefault("workspaces", {})
cur = ws_map.get(ws, d.get("default", "dwindle"))
order = ["dwindle", "scrolling", "floating"]
if sub in ("tiling", "dwindle"):
    nxt = "dwindle"
elif sub in ("scrolling", "master"):
    nxt = "scrolling"
elif sub == "floating":
    nxt = "floating"
elif sub == "back":
    nxt = order[(order.index(cur) - 1) % 3] if cur in order else "dwindle"
elif sub == "current":
    print(cur)
    sys.exit(0)
else:
    nxt = order[(order.index(cur) + 1) % 3] if cur in order else "scrolling"
ws_map[ws] = nxt
json.dump(d, open(path, "w"), indent=2)
print(nxt)
PY
)"
    [[ "$sub" == "current" ]] && { echo "$next_mode"; return 0; }

    local clients
    clients="$(hyprctl clients -j 2>/dev/null || echo '[]')"
    local batch=""
    if [[ "$next_mode" == "floating" ]]; then
        while IFS= read -r addr; do
            [[ -n "$addr" ]] && batch+="dispatch setfloating address:${addr};dispatch resizewindowpixel exact 72% 74%,address:${addr};dispatch centerwindow 1;"
        done < <(jq -r --argjson w "$ws" '.[] | select(.workspace.id == $w and .mapped and (.floating | not)) | .address' <<<"$clients")
        hyprctl keyword input:follow_mouse 0 >/dev/null 2>&1 || true
    else
        while IFS= read -r addr; do
            [[ -n "$addr" ]] && batch+="dispatch settiled address:${addr};"
        done < <(jq -r --argjson w "$ws" '.[] | select(.workspace.id == $w and .mapped and .floating) | .address' <<<"$clients")
        if [[ "$next_mode" == "scrolling" ]]; then
            hyprctl keyword general:layout master >/dev/null 2>&1 || true
        else
            hyprctl keyword general:layout dwindle >/dev/null 2>&1 || true
        fi
        hyprctl keyword input:follow_mouse 1 >/dev/null 2>&1 || true
    fi
    [[ -n "$batch" ]] && hyprctl --batch "$batch" >/dev/null 2>&1 || true
    local label="$next_mode"
    [[ "$label" == "dwindle" ]] && label="tiling"
    notify-send -a "SuperFedora" -t 1400 "Workspace $ws layout" "Mode: ${label^}" 2>/dev/null || true
    notify_dock
}

cmd_minimize() {
    local addr="${1:-}"
    local ws=""
    if [[ -n "$addr" ]]; then
        ws="$(hyprctl clients -j 2>/dev/null | jq -r --arg a "$addr" 'first(.[] | select(.address == $a) | .workspace.id) // empty')"
    else
        read -r addr ws < <(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.address // "") \(.workspace.id // "")"')
    fi
    [[ -n "$addr" && "$ws" =~ ^[0-9]+$ ]] || exit 0
    hyprctl --batch "dispatch movetoworkspacesilent special:minimized,address:${addr};dispatch workspace ${ws}" >/dev/null 2>&1 || true
    notify_dock
}

ACTION="${1:-status}"
[[ $# -gt 0 ]] && shift

case "$ACTION" in
    status|list)
        python3 - "$DOCK_JSON" "$MODES_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
m = json.load(open(sys.argv[2]))
print(f"Dock Position : {d.get('position', 'bottom')}")
print(f"Auto-Hide     : {'on' if d.get('autohide') else 'off'}")
print(f"Show Always   : {'on (all workspaces)' if d.get('showAlways', True) else 'off (floating workspaces only)'}")
print(f"Pinned Apps   : {', '.join(d.get('pinned', []))}")
ws = m.get("workspaces", {})
if ws:
    modes_str = ", ".join(f"WS{k}={v}" for k, v in sorted(ws.items()))
    print(f"WS Layouts    : {modes_str}")
PY
        ;;
    position|edge)
        POS="${1:-bottom}"
        python3 - "$DOCK_JSON" "$POS" <<'PY'
import json, sys
p, pos = sys.argv[1], sys.argv[2].lower()
if pos not in ("bottom", "top", "left", "right"):
    sys.exit("Position must be bottom, top, left, or right")
d = json.load(open(p))
d["position"] = pos
json.dump(d, open(p, "w"), indent=2)
print(f"[OK] Dock position set to {pos}")
PY
        notify_dock
        ;;
    autohide)
        VAL="${1:-toggle}"
        python3 - "$DOCK_JSON" "$VAL" <<'PY'
import json, sys
p, val = sys.argv[1], sys.argv[2].lower()
d = json.load(open(p))
if val == "toggle":
    d["autohide"] = not bool(d.get("autohide", False))
else:
    d["autohide"] = val in ("on", "true", "1", "yes")
json.dump(d, open(p, "w"), indent=2)
print(f"[OK] Dock autohide {'enabled' if d['autohide'] else 'disabled'}")
PY
        notify_dock
        ;;
    always|show-always|toggle)
        VAL="${1:-toggle}"
        [[ "$VAL" == "bottom" || "$VAL" == "top" || "$VAL" == "left" || "$VAL" == "right" ]] && VAL="toggle"
        python3 - "$DOCK_JSON" "$VAL" <<'PY'
import json, sys
p, val = sys.argv[1], sys.argv[2].lower()
d = json.load(open(p))
if val == "toggle":
    d["showAlways"] = not bool(d.get("showAlways", True))
else:
    d["showAlways"] = val in ("on", "true", "1", "yes")
json.dump(d, open(p, "w"), indent=2)
print(f"[OK] Dock visibility: {'all workspaces' if d['showAlways'] else 'floating workspaces only'}")
PY
        notify_dock
        ;;
    pinned)
        python3 - "$DOCK_JSON" "$@" <<'PY'
import json, sys
p = sys.argv[1]
pins = [x.removesuffix(".desktop") for x in sys.argv[2:] if x.strip()]
d = json.load(open(p))
d["pinned"] = pins
json.dump(d, open(p, "w"), indent=2)
PY
        notify_dock
        ;;
    pin)
        APP="${1:-}"
        IDX="${2:--1}"
        [[ -n "$APP" ]] || exit 2
        python3 - "$DOCK_JSON" "$APP" "$IDX" <<'PY'
import json, sys
p, app, idx = sys.argv[1], sys.argv[2].removesuffix(".desktop"), int(sys.argv[3])
d = json.load(open(p))
pins = [x for x in d.get("pinned", []) if x != app]
if 0 <= idx <= len(pins):
    pins.insert(idx, app)
else:
    pins.append(app)
d["pinned"] = pins
json.dump(d, open(p, "w"), indent=2)
print(f"[OK] Pinned {app} to dock")
PY
        notify_dock
        ;;
    unpin)
        APP="${1:-}"
        [[ -n "$APP" ]] || exit 2
        python3 - "$DOCK_JSON" "$APP" <<'PY'
import json, sys
p, app = sys.argv[1], sys.argv[2].removesuffix(".desktop")
d = json.load(open(p))
d["pinned"] = [x for x in d.get("pinned", []) if x != app]
json.dump(d, open(p, "w"), indent=2)
print(f"[OK] Unpinned {app} from dock")
PY
        notify_dock
        ;;
    apps|grid|launchpad)
        qs ipc call dock toggleApps >/dev/null 2>&1 || true
        ;;
    layout|mode)
        cmd_layout "$@"
        ;;
    minimize)
        cmd_minimize "$@"
        ;;
    reset|init|preset)
        write_default
        echo '{"default":"dwindle","workspaces":{}}' > "$MODES_JSON"
        notify_dock
        echo "[OK] Dock reset to Omarchy defaults"
        ;;
    *)
        sed -n '6,18p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
