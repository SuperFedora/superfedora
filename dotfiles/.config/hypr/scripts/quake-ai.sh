#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# quake-ai.sh — Quake-Style Drop-Down AI Console Launcher (SUPER + grave)
# ==============================================================================
# Usage:
#   quake-ai.sh [toggle|show|hide|restart|next-agent|set-agent <agy|grok|mcode|vibe>|status]
# ==============================================================================
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.minimax-code/bin:$HOME/.grok/bin:/usr/bin:/bin:$PATH"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
STATE_FILE="$STATE_DIR/quake-ai.env"
mkdir -p "$STATE_DIR"

AI_AGENT="agy"
# shellcheck disable=SC1090
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"

resolve_agent() {
    case "${1:-$AI_AGENT}" in
        agy|antigravity|antigravity-cli)
            AI_AGENT="agy"
            AI_LABEL="Antigravity CLI (agy)"
            AI_BIN="agy" ;;
        grok|grok-cli)
            AI_AGENT="grok"
            AI_LABEL="xAI Grok CLI (grok)"
            AI_BIN="grok" ;;
        mcode|minimax|minimax-code)
            AI_AGENT="mcode"
            AI_LABEL="MiniMax Code (mcode)"
            AI_BIN="mcode" ;;
        vibe|mistral|mistral-vibe)
            AI_AGENT="vibe"
            AI_LABEL="Mistral Vibe (vibe)"
            AI_BIN="vibe" ;;
        *)
            AI_AGENT="agy"
            AI_LABEL="Antigravity CLI (agy)"
            AI_BIN="agy" ;;
    esac
    printf 'AI_AGENT="%s"\n' "$AI_AGENT" > "$STATE_FILE"
}

compute_geometry() {
    local mon_json
    mon_json="$(hyprctl monitors -j 2>/dev/null || echo '[]')"
    read -r MON_NAME MON_X MON_Y MON_W MON_H < <(jq -r '
        (.[] | select(.focused == true)) // .[0] // {name:"default", x:0, y:0, width:1920, height:1080, scale:1}
        | "\(.name // "default") \(.x) \(.y) \((.width / (.scale // 1)) | floor) \((.height / (.scale // 1)) | floor)"
    ' <<<"$mon_json")
    MON_NAME="${MON_NAME:-default}"
    MON_X="${MON_X:-0}"; MON_Y="${MON_Y:-0}"; MON_W="${MON_W:-1920}"; MON_H="${MON_H:-1080}"

    # Bounded width/height so ultrawide monitors get a centered console, not full-width stretch
    Q_W=$(( MON_W * 68 / 100 ))
    (( Q_W > 1280 )) && Q_W=1280
    (( Q_W < 860 ))  && Q_W=860
    (( Q_W > MON_W - 40 )) && Q_W=$(( MON_W - 40 ))

    Q_H=$(( MON_H * 58 / 100 ))
    (( Q_H > 720 )) && Q_H=720
    (( Q_H < 480 )) && Q_H=480
    (( Q_H > MON_H - 96 )) && Q_H=$(( MON_H - 96 ))

    Q_X=$(( MON_X + (MON_W - Q_W) / 2 ))
    Q_Y=$(( MON_Y + 74 ))
}

has_quake_client() {
    hyprctl clients -j 2>/dev/null | jq -e '.[] | select(.class == "quake-ai")' >/dev/null 2>&1
}

is_special_ai_open() {
    hyprctl monitors -j 2>/dev/null | jq -e '.[] | select(.focused == true and .specialWorkspace.name == "special:ai")' >/dev/null 2>&1
}

notify_qs_show() {
    command -v qs >/dev/null 2>&1 && qs ipc call ai show "$Q_W" "$AI_AGENT" "$MON_NAME" >/dev/null 2>&1 || true
}

notify_qs_hide() {
    command -v qs >/dev/null 2>&1 && qs ipc call ai hide >/dev/null 2>&1 || true
}

spawn_quake() {
    resolve_agent "$AI_AGENT"
    local runner="$STATE_DIR/quake-ai-runner.sh"
    cat > "$runner" <<EOF
#!/usr/bin/env bash
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$HOME/.minimax-code/bin:\$HOME/.grok/bin:/usr/bin:/bin:\$PATH"
clear
printf '\033[1;34m::\033[0m \033[1mSUPERFEDORA QUAKE AI\033[0m // \033[1;36m%s\033[0m  \033[2m[Super+\` hide | Super+Shift+\` switch]\033[0m\n\n' "$AI_LABEL"
if command -v "$AI_BIN" >/dev/null 2>&1; then
    "$AI_BIN"
else
    printf '\033[1;33m[!]\033[0m %s binary (%s) is not installed yet. Run: sf install --only 80\n' "$AI_LABEL" "$AI_BIN"
fi
exec "\${SHELL:-/bin/bash}"
EOF
    chmod +x "$runner"
    hyprctl dispatch exec "[workspace special:ai silent; float; size $Q_W $Q_H; move $Q_X $Q_Y] kitty --class quake-ai --title 'Quake AI — $AI_LABEL' -e $runner" >/dev/null
    local i
    for i in {1..30}; do
        has_quake_client && break
        sleep 0.04
    done
}

show_quake() {
    resolve_agent "$AI_AGENT"
    compute_geometry
    has_quake_client || spawn_quake
    if ! is_special_ai_open; then
        hyprctl dispatch togglespecialworkspace ai >/dev/null
    fi
    hyprctl --batch "dispatch movewindowpixel exact $Q_X $Q_Y,class:^(quake-ai)$; dispatch resizewindowpixel exact $Q_W $Q_H,class:^(quake-ai)$; dispatch focuswindow class:^(quake-ai)$" >/dev/null
    notify_qs_show
}

hide_quake() {
    if is_special_ai_open; then
        hyprctl dispatch togglespecialworkspace ai >/dev/null
    fi
    notify_qs_hide
}

ACTION="${1:-toggle}"
case "$ACTION" in
    toggle)
        if has_quake_client && is_special_ai_open; then
            hide_quake
        else
            show_quake
        fi ;;
    show|open)
        show_quake ;;
    hide|close)
        hide_quake ;;
    restart|relaunch)
        pkill -f "kitty --class quake-ai" 2>/dev/null || true
        sleep 0.1
        show_quake ;;
    set-agent)
        resolve_agent "${2:-agy}"
        pkill -f "kitty --class quake-ai" 2>/dev/null || true
        sleep 0.1
        show_quake ;;
    next-agent)
        case "$AI_AGENT" in
            agy)    NEXT="grok" ;;
            grok)  NEXT="mcode" ;;
            mcode) NEXT="vibe" ;;
            *)     NEXT="agy" ;;
        esac
        resolve_agent "$NEXT"
        pkill -f "kitty --class quake-ai" 2>/dev/null || true
        sleep 0.1
        show_quake ;;
    status)
        resolve_agent "$AI_AGENT"
        compute_geometry
        printf 'Agent: %s (%s) | Geometry: %dx%d+%d+%d\n' "$AI_LABEL" "$AI_BIN" "$Q_W" "$Q_H" "$Q_X" "$Q_Y" ;;
    *)
        sed -n '7,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
