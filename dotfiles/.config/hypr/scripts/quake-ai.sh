#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# quake-ai.sh — Quake-Style Drop-Down AI Console & Agent Manager (SUPER + grave)
# ==============================================================================
# Usage:
#   quake-ai.sh [toggle|show|hide|restart|next-agent|set-agent <id>|list-agents]
#   quake-ai.sh [set-ollama <ip:port> [model]|add-agent <id> <label> <cmd>|remove-agent <id>]
#   quake-ai.sh [prompt-ollama|prompt-add|configure|status]
# ==============================================================================
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.minimax-code/bin:$HOME/.minimax/bin:$HOME/.grok/bin:$HOME/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
SELF="$(realpath "${BASH_SOURCE[0]}")"
SF_OLLAMA="$(command -v sf-ollama 2>/dev/null || realpath -m "$(dirname "$SELF")/../../../.local/bin/sf-ollama")"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
STATE_FILE="$STATE_DIR/quake-ai.env"; AGENTS_FILE="$STATE_DIR/ai-agents.conf"
mkdir -p "$STATE_DIR"

AI_AGENT="agy"; OLLAMA_HOST="127.0.0.1:11434"; OLLAMA_MODEL=""
# shellcheck disable=SC1090
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
AI_AGENT="${AI_AGENT:-agy}"; OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"

detect_ollama_model() {
    local h="${1:-$OLLAMA_HOST}" pref="${2:-}" m=""
    [[ -x "$SF_OLLAMA" ]] && m="$("$SF_OLLAMA" best-model "$h" "$pref" 2>/dev/null || true)"
    printf '%s' "${m:-${pref:-llama3.2}}"
}
[[ -z "$OLLAMA_MODEL" ]] && OLLAMA_MODEL="$(detect_ollama_model "$OLLAMA_HOST" "")"
[[ -f "$AGENTS_FILE" ]] || printf '# SuperFedora Custom AI Agents (id|label|command)\n' > "$AGENTS_FILE"

save_state() { printf 'AI_AGENT=%q\nOLLAMA_HOST=%q\nOLLAMA_MODEL=%q\n' "$AI_AGENT" "$OLLAMA_HOST" "$OLLAMA_MODEL" > "$STATE_FILE"; }

normalize_id() {
    case "${1:-$AI_AGENT}" in
        agy|antigravity|antigravity-cli) echo "agy" ;;
        mcode|minimax|minimax-code)      echo "mcode" ;;
        grok|grok-cli)                   echo "grok" ;;
        vibe|mistral|mistral-vibe)       echo "vibe" ;;
        claude|claude-code)              echo "claude" ;;
        chatgpt|chatgtp|codex|openai)    echo "chatgpt" ;;
        ollama|local)                    echo "ollama" ;;
        *)                               echo "${1:-agy}" ;;
    esac
}

all_agents() {
    local chat_bin="codex" cid clabel ccmd cbin
    command -v chatgpt >/dev/null 2>&1 && chat_bin="chatgpt"
    printf 'agy|core|Antigravity CLI (agy)|agy|agy\nmcode|core|MiniMax Code (mcode)|mcode|mcode\n'
    printf 'grok|core|xAI Grok CLI (grok)|grok|grok\nvibe|core|Mistral Vibe (vibe)|vibe|vibe\n'
    printf 'claude|standard|Claude Code (claude)|claude|claude\n'
    printf 'chatgpt|standard|ChatGPT / Codex (%s)|%s|%s\n' "$chat_bin" "$chat_bin" "$chat_bin"
    printf 'ollama|local|Ollama (%s // %s)|sf-ollama chat %s %s|ollama\n' "$OLLAMA_HOST" "$OLLAMA_MODEL" "$OLLAMA_HOST" "$OLLAMA_MODEL"
    if [[ -f "$AGENTS_FILE" ]]; then
        while IFS='|' read -r cid clabel ccmd; do
            [[ -z "${cid// /}" || "$cid" == \#* ]] && continue
            case "$cid" in agy|mcode|grok|vibe|claude|chatgpt|ollama) continue ;; esac
            clabel="${clabel//|/ -}"; ccmd="${ccmd//|/ }"; cbin="${ccmd%% *}"
            printf '%s|custom|%s|%s|%s\n' "$cid" "${clabel:-$cid}" "${ccmd:-$cid}" "${cbin:-$cid}"
        done < "$AGENTS_FILE"
    fi
}

resolve_agent() {
    local target cid clabel ccmd cbin found=0
    target="$(normalize_id "${1:-$AI_AGENT}")"
    while IFS='|' read -r cid _ clabel ccmd cbin; do
        if [[ "$cid" == "$target" ]]; then
            AI_AGENT="$cid"; AI_LABEL="$clabel"; AI_CMD="$ccmd"; AI_BIN="$cbin"; found=1; break
        fi
    done < <(all_agents)
    [[ $found -eq 0 ]] && { AI_AGENT="agy"; AI_LABEL="Antigravity CLI (agy)"; AI_CMD="agy"; AI_BIN="agy"; }
    save_state
}

list_agents() {
    local probe_out="" ol_online="0" ol_best="" cid ccat clabel ccmd cbin inst act
    if [[ -x "$SF_OLLAMA" ]]; then
        probe_out="$("$SF_OLLAMA" probe "$OLLAMA_HOST" "$OLLAMA_MODEL" 2>/dev/null || true)"
        IFS='|' read -r _ OLLAMA_HOST ol_online ol_best _ <<<"${probe_out%%$'\n'*}"
        [[ -n "$ol_best" && "$ol_best" != "$OLLAMA_MODEL" ]] && OLLAMA_MODEL="$ol_best"
    fi
    resolve_agent "$AI_AGENT"
    printf 'CFG|%s|%s|%s|%s\n' "$AI_AGENT" "$AI_LABEL" "$OLLAMA_HOST" "$OLLAMA_MODEL"
    while IFS='|' read -r cid ccat clabel ccmd cbin; do
        inst=0; command -v "$cbin" >/dev/null 2>&1 && inst=1
        [[ "$cid" == "ollama" && "$ol_online" == "1" ]] && inst=1
        act=0; [[ "$cid" == "$AI_AGENT" ]] && act=1
        printf 'AGENT|%s|%s|%s|%s|%d|%d\n' "$cid" "$ccat" "$clabel" "$ccmd" "$inst" "$act"
    done < <(all_agents)
    [[ -n "$probe_out" ]] && printf '%s\n' "$probe_out"
}

set_ollama() {
    local host="${1:-$OLLAMA_HOST}" model="${2:-}"
    host="${host#http://}"; host="${host#https://}"; host="${host%/}"; host="${host%%/*}"
    if [[ -n "$host" ]]; then
        [[ "$host" != *:* ]] && host="$host:11434"
        OLLAMA_HOST="$host"
    fi
    OLLAMA_MODEL="$(detect_ollama_model "$OLLAMA_HOST" "${model%% *}")"
    save_state
}

add_custom_agent() {
    local id="${1:-}" label="${2:-}" cmd="${3:-}" tmp="$AGENTS_FILE.tmp"
    id="$(echo "$id" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9_-')"
    label="${label//|/ -}"; cmd="${cmd//|/ }"
    [[ -n "$id" && -n "$cmd" ]] || { echo "Usage: quake-ai.sh add-agent <id> <label> <command>" >&2; exit 2; }
    case "$id" in agy|mcode|grok|vibe|claude|chatgpt|ollama) echo "Cannot override built-in agent '$id'" >&2; exit 2 ;; esac
    [[ -z "$label" ]] && label="$id ($cmd)"
    if [[ -f "$AGENTS_FILE" ]]; then grep -Ev "^${id}\\|" "$AGENTS_FILE" > "$tmp" || true; mv "$tmp" "$AGENTS_FILE"; fi
    printf '%s|%s|%s\n' "$id" "$label" "$cmd" >> "$AGENTS_FILE"
}

remove_custom_agent() {
    local id="${1:-}" tmp="$AGENTS_FILE.tmp"
    [[ -n "$id" && -f "$AGENTS_FILE" ]] || return 0
    grep -Ev "^${id}\\|" "$AGENTS_FILE" > "$tmp" || true; mv "$tmp" "$AGENTS_FILE"
    if [[ "$AI_AGENT" == "$id" ]]; then AI_AGENT="agy"; save_state; fi
}

compute_geometry() {
    local mon_json
    mon_json="$(hyprctl monitors -j 2>/dev/null || echo '[]')"
    read -r MON_NAME MON_X MON_Y MON_W MON_H < <(jq -r '
        (.[] | select(.focused == true)) // .[0] // {name:"default", x:0, y:0, width:1920, height:1080, scale:1}
        | "\(.name // "default") \(.x) \(.y) \((.width / (.scale // 1)) | floor) \((.height / (.scale // 1)) | floor)"
    ' <<<"$mon_json")
    MON_NAME="${MON_NAME:-default}"; MON_X="${MON_X:-0}"; MON_Y="${MON_Y:-0}"; MON_W="${MON_W:-1920}"; MON_H="${MON_H:-1080}"
    Q_W=$(( MON_W * 68 / 100 )); Q_H=$(( MON_H * 58 / 100 ))
    if (( Q_W > 1280 )); then Q_W=1280; elif (( Q_W < 860 )); then Q_W=860; fi
    if (( Q_W > MON_W - 40 )); then Q_W=$(( MON_W - 40 )); fi
    if (( Q_H > 720 )); then Q_H=720; elif (( Q_H < 480 )); then Q_H=480; fi
    if (( Q_H > MON_H - 64 )); then Q_H=$(( MON_H - 64 )); fi
    Q_X=$(( MON_X + (MON_W - Q_W) / 2 )); Q_Y=$(( MON_Y + 42 ))
}

has_quake_client() { hyprctl clients -j 2>/dev/null | jq -e '.[] | select(.class == "quake-ai")' >/dev/null 2>&1; }
is_special_ai_open() { hyprctl monitors -j 2>/dev/null | jq -e '.[] | select(.focused == true and .specialWorkspace.name == "special:ai")' >/dev/null 2>&1; }

spawn_quake() {
    [[ "$AI_AGENT" == "ollama" ]] && OLLAMA_MODEL="$(detect_ollama_model "$OLLAMA_HOST" "$OLLAMA_MODEL")"
    resolve_agent "$AI_AGENT"
    local runner="$STATE_DIR/quake-ai-runner.sh" safe_title="${AI_LABEL//[\'\"]/}"
    {
        printf '#!/usr/bin/env bash\nexport PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.minimax-code/bin:$HOME/.minimax/bin:$HOME/.grok/bin:$HOME/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:$PATH"\n'
        printf 'export AI_AGENT=%q AI_LABEL=%q AI_BIN=%q AI_CMD=%q OLLAMA_HOST=%q OLLAMA_MODEL=%q SF_OLLAMA=%q\n' \
            "$AI_AGENT" "$AI_LABEL" "$AI_BIN" "$AI_CMD" "$OLLAMA_HOST" "$OLLAMA_MODEL" "$SF_OLLAMA"
        cat <<'EOF'
clear
if [[ "$AI_AGENT" == "ollama" ]]; then
    if command -v ollama >/dev/null 2>&1; then OLLAMA_HOST="$OLLAMA_HOST" ollama run "$OLLAMA_MODEL"
    elif [[ -x "$SF_OLLAMA" ]]; then "$SF_OLLAMA" chat "$OLLAMA_HOST" "$OLLAMA_MODEL"
    else printf '\033[1;33m[!]\033[0m Cannot connect to Ollama at %s (%s)\n' "$OLLAMA_HOST" "$OLLAMA_MODEL"; fi
elif command -v "$AI_BIN" >/dev/null 2>&1; then eval "$AI_CMD"
else printf '\033[1;33m[!]\033[0m %s (%s) is not installed yet. Configure via Top Bar AI menu or: sf ai configure\n' "$AI_LABEL" "$AI_BIN"; fi
exec "${SHELL:-/bin/bash}"
EOF
    } > "$runner"
    chmod +x "$runner"
    hyprctl dispatch exec "[workspace special:ai silent; float; size $Q_W $Q_H; move $Q_X $Q_Y] kitty --class quake-ai -o 'map escape launch --type=background $SELF hide' -o 'map shift+escape send_text all \x1b' --title 'Quake AI — $safe_title' -e $runner" >/dev/null
    for _ in {1..30}; do has_quake_client && break; sleep 0.04; done
}

show_quake() {
    resolve_agent "$AI_AGENT"; compute_geometry; has_quake_client || spawn_quake
    is_special_ai_open || hyprctl dispatch togglespecialworkspace ai >/dev/null
    hyprctl --batch "dispatch movewindowpixel exact $Q_X $Q_Y,class:^(quake-ai)$; dispatch resizewindowpixel exact $Q_W $Q_H,class:^(quake-ai)$; dispatch focuswindow class:^(quake-ai)$" >/dev/null
}

hide_quake() { is_special_ai_open && hyprctl dispatch togglespecialworkspace ai >/dev/null || true; }
relaunch_quake() { pkill -f "kitty --class quake-ai" 2>/dev/null || true; for _ in {1..25}; do has_quake_client || break; sleep 0.04; done; show_quake; }

prompt_ollama() {
    local host model choices
    host="$(printf '%s\n127.0.0.1:11434\nlocalhost:11434\n' "$OLLAMA_HOST" | awk '!seen[$0]++' | fuzzel --dmenu --prompt 'Ollama Server (host:port) > ' --width 48)" || return 0
    [[ -n "${host// /}" ]] || return 0
    set_ollama "$host" ""
    choices="$("$SF_OLLAMA" fuzzel-models "$OLLAMA_HOST" "$OLLAMA_MODEL" 2>/dev/null || true)"
    model="$(printf '%s\n' "$choices" | fuzzel --dmenu --prompt "Model ($OLLAMA_HOST) > " --width 56)" || return 0
    [[ -z "${model// /}" || "$model" == "[!]"* ]] && return 0
    set_ollama "$OLLAMA_HOST" "${model%% *}"; resolve_agent "ollama"; relaunch_quake
}

prompt_add_agent() {
    local cmd id label
    cmd="$(printf 'aider\nopencode\ngemini\ngoose session\n' | fuzzel --dmenu --prompt 'Agent Command > ' --width 44)" || return 0
    [[ -n "${cmd// /}" ]] || return 0
    id="$(echo "${cmd%% *}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
    label="$(printf '%s (%s)\n%s\n' "${id^} CLI" "$cmd" "$cmd" | fuzzel --dmenu --prompt 'Agent Label > ' --width 44)" || return 0
    add_custom_agent "$id" "${label:-$id}" "$cmd"; resolve_agent "$id"; relaunch_quake
}

configure_tui() {
    local probe_out ol_online ol_best ol_st loaded_list all_list cid ccat clabel ccmd cbin st mk act aid oh om nid nlbl ncmd rid mnames=()
    while true; do
        probe_out="$("$SF_OLLAMA" probe "$OLLAMA_HOST" "$OLLAMA_MODEL" 2>/dev/null || true)"
        IFS='|' read -r _ OLLAMA_HOST ol_online ol_best _ <<<"${probe_out%%$'\n'*}"
        [[ -n "$ol_best" && "$ol_best" != "$OLLAMA_MODEL" ]] && OLLAMA_MODEL="$ol_best"
        ol_st="OFFLINE"; [[ "$ol_online" == "1" ]] && ol_st="ONLINE"
        loaded_list="$(awk -F'|' '$1=="OLLAMA_MODEL" && $3=="1"{printf "%s ", $2}' <<<"$probe_out")"
        all_list="$(awk -F'|' '$1=="OLLAMA_MODEL"{printf "%s ", $6}' <<<"$probe_out")"
        resolve_agent "$AI_AGENT"; clear
        printf '=== SUPERFEDORA QUAKE AI // AGENT & OLLAMA CONFIGURATOR ===\n  Active Agent  : %s [%s]\n  Ollama Server : http://%s [%s] (Active Model: %s)\n  VRAM Loaded   : %s\n  Server Models : %s\n\n' \
            "$AI_LABEL" "$AI_AGENT" "$OLLAMA_HOST" "$ol_st" "$OLLAMA_MODEL" "${loaded_list:-none}" "${all_list:-none}"
        while IFS='|' read -r cid ccat clabel ccmd cbin; do
            st="[--]"; mk="   "; command -v "$cbin" >/dev/null 2>&1 && st="[OK]"
            [[ "$cid" == "ollama" && "$ol_online" == "1" ]] && st="[OK]"; [[ "$cid" == "$AI_AGENT" ]] && mk="[*]"
            printf '  %s %-10s %-10s %-34s (%s) %s\n' "$mk" "$cid" "[$ccat]" "$clabel" "$ccmd" "$st"
        done < <(all_agents)
        printf '\n  1) Select active agent  2) Set Ollama Server & Pick Model  3) Add custom agent  4) Remove custom agent  5) Launch Quake AI  q) Quit\n'
        read -r -p "  Select action [1-5/q]: " act
        case "$act" in
            1) read -r -p "  Agent ID: " aid; [[ -n "$aid" ]] && resolve_agent "$aid" ;;
            2) read -r -p "  Ollama Host/URL [$OLLAMA_HOST]: " oh; set_ollama "${oh:-$OLLAMA_HOST}" ""
               printf '  Probing http://%s ...\n' "$OLLAMA_HOST"; "$SF_OLLAMA" table "$OLLAMA_HOST" "$OLLAMA_MODEL"
               mapfile -t mnames < <("$SF_OLLAMA" probe "$OLLAMA_HOST" "$OLLAMA_MODEL" | awk -F'|' '$1=="OLLAMA_MODEL"{print $2}')
               read -r -p "  Select model (#, name, or Enter for $OLLAMA_MODEL): " om
               if [[ "$om" =~ ^[0-9]+$ ]] && (( om >= 1 && om <= ${#mnames[@]} )); then om="${mnames[$((om - 1))]}"; fi
               set_ollama "$OLLAMA_HOST" "${om:-$OLLAMA_MODEL}"; resolve_agent "ollama" ;;
            3) read -r -p "  ID: " nid; read -r -p "  Label: " nlbl; read -r -p "  Command: " ncmd
               [[ -n "$nid" && -n "$ncmd" ]] && add_custom_agent "$nid" "$nlbl" "$ncmd" ;;
            4) read -r -p "  Custom ID to remove: " rid; [[ -n "$rid" ]] && remove_custom_agent "$rid" ;;
            5) relaunch_quake; break ;;
            q|Q|"") break ;;
        esac
    done
}

case "${1:-toggle}" in
    toggle)        if has_quake_client && is_special_ai_open; then hide_quake; else show_quake; fi ;;
    show|open)     show_quake ;;
    hide|close)    hide_quake ;;
    restart|relaunch) relaunch_quake ;;
    set-agent)     resolve_agent "${2:-agy}"; relaunch_quake ;;
    next-agent)
        mapfile -t IDS < <(all_agents | cut -d'|' -f1); NEXT="${IDS[0]:-agy}"
        for i in "${!IDS[@]}"; do [[ "${IDS[$i]}" == "$AI_AGENT" ]] && { NEXT="${IDS[$(( (i + 1) % ${#IDS[@]} ))]}"; break; }; done
        resolve_agent "$NEXT"; relaunch_quake ;;
    list-agents)   list_agents ;;
    set-ollama)    set_ollama "${2:-}" "${3:-}" ;;
    add-agent)     add_custom_agent "${2:-}" "${3:-}" "${4:-}" ;;
    remove-agent)  remove_custom_agent "${2:-}" ;;
    prompt-ollama) prompt_ollama ;;
    prompt-add)    prompt_add_agent ;;
    configure|tui) configure_tui ;;
    status)        resolve_agent "$AI_AGENT"; compute_geometry
                   printf 'Agent: %s (%s) | Ollama: %s (%s) | Geometry: %dx%d+%d+%d\n' "$AI_LABEL" "$AI_CMD" "$OLLAMA_HOST" "$OLLAMA_MODEL" "$Q_W" "$Q_H" "$Q_X" "$Q_Y" ;;
    *)             sed -n '7,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
