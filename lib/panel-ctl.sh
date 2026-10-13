#!/usr/bin/env bash
# ==============================================================================
# panel-ctl.sh — Multi-Edge Panels & Dock Configuration Engine
# ==============================================================================
# Usage:
#   sf panel status                           Print current edge configuration
#   sf panel toggle <edge>                    Toggle top|bottom|left|right on/off
#   sf panel set <edge> <key> <value>         Update enabled|span|percent|thickness|hideMode
#   sf panel preset <name>                    Apply preset (default|top-only|dock-left|quad)
#   sf panel reset                            Restore default layout
# ==============================================================================
set -euo pipefail

STATE_DIR="$HOME/.config/superfedora"
PANELS_JSON="$STATE_DIR/panels.json"
mkdir -p "$STATE_DIR"

write_default() {
    cat > "$PANELS_JSON" <<'EOF'
{
  "top": {
    "enabled": true,
    "span": "full",
    "percent": 100,
    "thickness": 36,
    "hideMode": "never",
    "start": ["launcher", "workspaces"],
    "center": ["clock"],
    "end": ["tray", "status"]
  },
  "bottom": {
    "enabled": true,
    "span": "hug",
    "percent": 65,
    "thickness": 52,
    "hideMode": "intellihide",
    "start": [],
    "center": ["apps"],
    "end": []
  },
  "left": {
    "enabled": false,
    "span": "hug",
    "percent": 70,
    "thickness": 46,
    "hideMode": "intellihide",
    "start": ["launcher"],
    "center": ["workspaces", "apps"],
    "end": ["theme", "status"]
  },
  "right": {
    "enabled": false,
    "span": "hug",
    "percent": 70,
    "thickness": 46,
    "hideMode": "intellihide",
    "start": ["workspaces"],
    "center": ["apps"],
    "end": ["theme", "status"]
  }
}
EOF
}

[[ -f "$PANELS_JSON" ]] || write_default

notify_quickshell() {
    if command -v qs >/dev/null 2>&1 && pgrep -x quickshell >/dev/null 2>&1; then
        qs ipc call panels reload >/dev/null 2>&1 || true
    fi
}

ACTION="${1:-status}"
[[ $# -gt 0 ]] && shift

case "$ACTION" in
    status|list)
        python3 - "$PANELS_JSON" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
print("EDGE    STATE  SPAN      PCT   SIZE  HIDE MODE    SLOTS (START | CENTER | END)")
print("------  -----  --------  ----  ----  -----------  ----------------------------")
for edge in ("top", "bottom", "left", "right"):
    c = d.get(edge, {})
    st = "ON " if c.get("enabled") else "OFF"
    sp = c.get("span", "hug")
    pct = f"{c.get('percent', 100)}%"
    th = f"{c.get('thickness', 36)}px"
    hm = c.get("hideMode", "never")
    slots = f"{','.join(c.get('start',[]))} | {','.join(c.get('center',[]))} | {','.join(c.get('end',[]))}"
    print(f"{edge:<6}  [{st}]  {sp:<8}  {pct:<4}  {th:<4}  {hm:<11}  {slots}")
PY
        ;;
    init)
        [[ -f "$PANELS_JSON" ]] || write_default
        notify_quickshell
        ;;
    reset)
        write_default
        notify_quickshell
        echo "[OK] Panels reset to default (Top Bar + Bottom Intellihide Dock)"
        ;;
    toggle)
        EDGE="${1:-bottom}"
        python3 - "$PANELS_JSON" "$EDGE" <<'PY'
import json, sys
path, edge = sys.argv[1], sys.argv[2].lower()
if edge not in ("top", "bottom", "left", "right"):
    sys.exit(f"Invalid edge: {edge}")
with open(path) as f:
    d = json.load(f)
d.setdefault(edge, {})["enabled"] = not bool(d.get(edge, {}).get("enabled", False))
with open(path, "w") as f:
    json.dump(d, f, indent=2)
state = "ON" if d[edge]["enabled"] else "OFF"
print(f"[OK] Panel '{edge}' is now {state}")
PY
        notify_quickshell
        ;;
    set)
        EDGE="${1:-}"
        KEY="${2:-}"
        VAL="${3:-}"
        [[ -n "$EDGE" && -n "$KEY" && -n "$VAL" ]] || { echo "Usage: sf panel set <top|bottom|left|right> <enabled|span|percent|thickness|hideMode|start|center|end> <value>" >&2; exit 2; }
        python3 - "$PANELS_JSON" "$EDGE" "$KEY" "$VAL" <<'PY'
import json, sys
path, edge, key, val = sys.argv[1], sys.argv[2].lower(), sys.argv[3], sys.argv[4]
if edge not in ("top", "bottom", "left", "right"):
    sys.exit(f"Invalid edge: {edge}")
with open(path) as f:
    d = json.load(f)
cfg = d.setdefault(edge, {})
if key == "enabled":
    cfg["enabled"] = val.lower() in ("1", "true", "on", "yes")
elif key == "span":
    if val not in ("full", "hug", "percent"):
        sys.exit("span must be full, hug, or percent")
    cfg["span"] = val
elif key == "percent":
    cfg["percent"] = max(20, min(100, int(val)))
elif key == "thickness":
    cfg["thickness"] = max(26, min(84, int(val)))
elif key == "hideMode":
    if val not in ("never", "intellihide", "autohide"):
        sys.exit("hideMode must be never, intellihide, or autohide")
    cfg["hideMode"] = val
elif key in ("start", "center", "end"):
    cfg[key] = [x.strip() for x in val.split(",") if x.strip()] if val != "none" else []
else:
    sys.exit(f"Unknown key: {key}")
with open(path, "w") as f:
    json.dump(d, f, indent=2)
print(f"[OK] Updated {edge}.{key} = {cfg[key]}")
PY
        notify_quickshell
        ;;
    preset)
        PRESET="${1:-default}"
        write_default
        if [[ "$PRESET" == "top-only" ]]; then
            "$0" set bottom enabled false >/dev/null
        elif [[ "$PRESET" == "dock-left" ]]; then
            "$0" set bottom enabled false >/dev/null
            "$0" set left enabled true >/dev/null
        elif [[ "$PRESET" == "quad" ]]; then
            "$0" set left enabled true >/dev/null
            "$0" set right enabled true >/dev/null
        fi
        notify_quickshell
        echo "[OK] Applied panel preset: $PRESET"
        ;;
    *)
        sed -n '4,10p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
