#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# quake-ai.sh — SuperDock [`] AI Harness & LLM Manager (All-in-One + Modular)
# ==============================================================================
# Usage:
#   quake-ai.sh [toggle|show|hide|restart|next-agent|set-agent <id>|list-agents]
#   quake-ai.sh [set-config <mode> <id> [host] [model]|probe-host <host> [model]]
#   quake-ai.sh [set-ollama <ip:port> [model]|add-agent <id> <label> <cmd>|remove-agent <id>]
#   quake-ai.sh [prompt-ollama|prompt-add|configure|status]
# ==============================================================================
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.minimax-code/bin:$HOME/.minimax/bin:$HOME/.grok/bin:$HOME/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
SELF="${BASH_SOURCE[0]}"; SF_OLLAMA="$HOME/.local/bin/sf-ollama"
[[ -x "$SF_OLLAMA" ]] || SF_OLLAMA="$(command -v sf-ollama 2>/dev/null || echo "$HOME/.local/bin/sf-ollama")"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"; FAST_FILE="${XDG_RUNTIME_DIR:-/tmp}/quake-ai-${HYPRLAND_INSTANCE_SIGNATURE:-0}.env"
STATE_FILE="$STATE_DIR/quake-ai.env"; AGENTS_FILE="$STATE_DIR/ai-agents.conf"; RELAUNCH_LOCK="$STATE_DIR/quake-relaunching"
[[ -d "$STATE_DIR" ]] || mkdir -p "$STATE_DIR"

AI_MODE=""; AI_HARNESS="pi"; AI_AGENT="agy"; OLLAMA_HOST="127.0.0.1:11434"; OLLAMA_MODEL=""; DEFAULT_TERMINAL="kitty"
# shellcheck disable=SC1090
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"; [[ -f "$STATE_DIR/defaults.env" ]] && source "$STATE_DIR/defaults.env"; [[ -f "$STATE_DIR/profile.env" ]] && source "$STATE_DIR/profile.env"
AI_AGENT="${AI_AGENT:-agy}"; AI_HARNESS="${AI_HARNESS:-pi}"; OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"; DEFAULT_TERMINAL="${DEFAULT_TERMINAL:-kitty}"
if [[ -z "$AI_MODE" ]]; then [[ "$AI_AGENT" == "ollama" ]] && AI_MODE="modular" || AI_MODE="allinone"; fi

detect_ollama_model() { local h="${1:-$OLLAMA_HOST}" pref="${2:-}" m=""; [[ -x "$SF_OLLAMA" ]] && m="$("$SF_OLLAMA" best-model "$h" "$pref" 2>/dev/null || true)"; printf '%s' "${m:-${pref:-llama3.2}}"; }
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2}"
[[ -f "$AGENTS_FILE" ]] || printf '# SuperFedora Custom AI Agents (id|label|command)\n' > "$AGENTS_FILE"
save_state() { printf 'AI_MODE=%q\nAI_HARNESS=%q\nAI_AGENT=%q\nOLLAMA_HOST=%q\nOLLAMA_MODEL=%q\n' "$AI_MODE" "$AI_HARNESS" "$AI_AGENT" "$OLLAMA_HOST" "$OLLAMA_MODEL" > "$STATE_FILE"; }

sync_pi_ollama() {
    local host="${1:-$OLLAMA_HOST}" model="${2:-$OLLAMA_MODEL}" probe=""
    [[ -x "$SF_OLLAMA" ]] && probe="$("$SF_OLLAMA" probe "$host" "$model" 2>/dev/null || true)"
    python3 -c 'import json,os,sys; path,host,cur,probe=sys.argv[1:5]; os.makedirs(os.path.dirname(path),exist_ok=True); data=json.load(open(path)) if os.path.exists(path) else {}; models=[]; seen=set()
for line in probe.splitlines():
 p=line.split("|")
 if len(p)>=2 and p[0]=="OLLAMA_MODEL" and p[1] and p[1] not in seen: seen.add(p[1]); models.append({"id":p[1]})
if cur and cur not in seen: models.insert(0,{"id":cur})
data["$schema"]="https://pi.dev/schemas/models.schema.json"; data.setdefault("providers",{})["ollama"]={"baseUrl":f"http://{host}/v1","api":"openai-completions","apiKey":"ollama","models":models or [{"id":"llama3.2"}]}; json.dump(data,open(path,"w"),indent=2)' "$HOME/.pi/agent/models.json" "$host" "$model" "$probe" 2>/dev/null || true
}
normalize_id() {
    case "${1:-$AI_AGENT}" in
        agy|antigravity*) echo "agy" ;; mcode|minimax*) echo "mcode" ;; grok|grok-cli) echo "grok" ;; vibe|mistral*) echo "vibe" ;;
        claude*) echo "claude" ;; chatgpt|chatgtp|codex|openai) echo "chatgpt" ;; ollama|local|pi|opencode|aider|ollama-cli|sf-chat) echo "ollama" ;; *) echo "${1:-agy}" ;;
    esac
}
harness_meta() {
    case "${1:-pi}" in
        pi)         printf 'Pi Coding Harness (pi)|pi --provider ollama --model %s|pi\n' "$OLLAMA_MODEL" ;;
        mcode)      printf 'MiniMax Code Harness (mcode)|OPENAI_BASE_URL=http://%s/v1 OPENAI_API_KEY=ollama mcode -m %s|mcode\n' "$OLLAMA_HOST" "$OLLAMA_MODEL" ;;
        opencode)   printf 'OpenCode CLI (opencode)|OLLAMA_HOST=http://%s opencode|opencode\n' "$OLLAMA_HOST" ;;
        aider)      printf 'Aider Pair Programmer (aider)|OLLAMA_API_BASE=http://%s aider --model ollama_chat/%s|aider\n' "$OLLAMA_HOST" "$OLLAMA_MODEL" ;;
        ollama-cli) printf 'Ollama Native CLI (ollama)|OLLAMA_HOST=%s ollama run %s|ollama\n' "$OLLAMA_HOST" "$OLLAMA_MODEL" ;;
        sf-chat|*)  printf 'SuperFedora Native Chat (sf-ollama)|%s chat %s %s|sf-ollama\n' "$SF_OLLAMA" "$OLLAMA_HOST" "$OLLAMA_MODEL" ;;
    esac
}
all_harnesses() {
    printf 'pi|Pi Coding Harness (pi)|Agentic coding TUI with read, bash, edit & write tools|pi\nmcode|MiniMax Code (mcode)|Terminal coding agent wired to custom LLM server|mcode\n'
    printf 'opencode|OpenCode CLI (opencode)|Modular terminal coding harness for local LLMs|opencode\naider|Aider Pair Programmer (aider)|Git-aware AI pair programming in terminal|aider\n'
    printf 'ollama-cli|Ollama Native CLI (ollama)|Direct interactive model REPL via ollama run|ollama\nsf-chat|SuperFedora Direct Chat|Built-in zero-dependency streaming LLM console|sf-ollama\n'
}
all_agents() {
    local chat_bin="codex" hlbl hcmd hbin cid clabel ccmd cbin; command -v chatgpt >/dev/null 2>&1 && chat_bin="chatgpt"
    IFS='|' read -r hlbl hcmd hbin < <(harness_meta "$AI_HARNESS") || true
    printf 'agy|core|Antigravity CLI (agy)|agy|agy\nmcode|core|MiniMax Code (mcode)|mcode|mcode\ngrok|core|xAI Grok CLI (grok)|grok|grok\nvibe|core|Mistral Vibe (vibe)|vibe|vibe\n'
    printf 'claude|standard|Claude Code (claude)|claude|claude\nchatgpt|standard|ChatGPT / Codex (%s)|%s|%s\nollama|local|%s (%s // %s)|%s|%s\n' "$chat_bin" "$chat_bin" "$chat_bin" "${hlbl%% (*}" "$OLLAMA_HOST" "$OLLAMA_MODEL" "$hcmd" "$hbin"
    if [[ -f "$AGENTS_FILE" ]]; then
        while IFS='|' read -r cid clabel ccmd; do
            [[ -z "${cid// /}" || "$cid" == \#* ]] && continue
            case "$cid" in agy|mcode|grok|vibe|claude|chatgpt|ollama) continue ;; esac
            clabel="${clabel//|/ -}"; ccmd="${ccmd//|/ }"; cbin="${ccmd%% *}"; printf '%s|custom|%s|%s|%s\n' "$cid" "${clabel:-$cid}" "${ccmd:-$cid}" "${cbin:-$cid}"
        done < "$AGENTS_FILE"
    fi
}
resolve_agent() {
    local raw="${1:-$AI_AGENT}" target cid clabel ccmd cbin found=0
    case "$raw" in pi|opencode|aider|ollama-cli|sf-chat) AI_HARNESS="$raw"; AI_MODE="modular"; target="ollama" ;; *) target="$(normalize_id "$raw")" ;; esac
    [[ "$target" == "ollama" ]] && AI_MODE="modular" || AI_MODE="allinone"
    while IFS='|' read -r cid _ clabel ccmd cbin; do [[ "$cid" == "$target" ]] && { AI_AGENT="$cid"; AI_LABEL="$clabel"; AI_CMD="$ccmd"; AI_BIN="$cbin"; found=1; break; }; done < <(all_agents)
    [[ $found -eq 0 ]] && { AI_MODE="allinone"; AI_AGENT="agy"; AI_LABEL="Antigravity CLI (agy)"; AI_CMD="agy"; AI_BIN="agy"; }; save_state
}
list_agents() {
    local probe_out="" ol_online="0" ol_best="" cid ccat clabel ccmd cbin hid hlbl hdesc hbin inst act
    if [[ -x "$SF_OLLAMA" ]]; then
        probe_out="$("$SF_OLLAMA" probe "$OLLAMA_HOST" "$OLLAMA_MODEL" 2>/dev/null || true)"
        IFS='|' read -r _ OLLAMA_HOST ol_online ol_best _ <<<"${probe_out%%$'\n'*}" || true
        [[ -n "$ol_best" && "$ol_best" != "$OLLAMA_MODEL" ]] && OLLAMA_MODEL="$ol_best"
    fi
    resolve_agent "$AI_AGENT"; printf 'CFG|%s|%s|%s|%s|%s|%s|%s\n' "$AI_AGENT" "$AI_LABEL" "$OLLAMA_HOST" "$OLLAMA_MODEL" "$AI_MODE" "$AI_HARNESS" "${ol_online:-0}"
    while IFS='|' read -r hid hlbl hdesc hbin; do
        inst=0; command -v "$hbin" >/dev/null 2>&1 && inst=1; [[ "$hid" == "sf-chat" && -x "$SF_OLLAMA" ]] && inst=1
        act=0; [[ "$AI_MODE" == "modular" && "$AI_HARNESS" == "$hid" ]] && act=1; printf 'HARNESS|%s|%s|%s|%d|%d\n' "$hid" "$hlbl" "$hdesc" "$inst" "$act"
    done < <(all_harnesses)
    while IFS='|' read -r cid ccat clabel ccmd cbin; do
        inst=0; command -v "$cbin" >/dev/null 2>&1 && inst=1; [[ "$cid" == "ollama" && "$ol_online" == "1" ]] && inst=1
        act=0; [[ "$cid" == "$AI_AGENT" ]] && act=1; printf 'AGENT|%s|%s|%s|%s|%d|%d\n' "$cid" "$ccat" "$clabel" "$ccmd" "$inst" "$act"
    done < <(all_agents)
    [[ -n "$probe_out" ]] && printf '%s\n' "$probe_out"
}
set_ollama() {
    local host="${1:-$OLLAMA_HOST}" model="${2:-}"; host="${host#http://}"; host="${host#https://}"; host="${host%/}"; host="${host%%/*}"
    [[ -n "$host" ]] && { [[ "$host" != *:* ]] && host="$host:11434"; OLLAMA_HOST="$host"; }
    OLLAMA_MODEL="$(detect_ollama_model "$OLLAMA_HOST" "${model%% *}")"; save_state; sync_pi_ollama "$OLLAMA_HOST" "$OLLAMA_MODEL"
}
set_config() {
    local mode="${1:-allinone}" target="${2:-agy}" host="${3:-}" model="${4:-}"
    if [[ "$mode" == "modular" ]]; then
        AI_MODE="modular"; AI_HARNESS="${target:-pi}"; AI_AGENT="ollama"
        [[ -n "$host" || -n "$model" ]] && set_ollama "${host:-$OLLAMA_HOST}" "${model:-$OLLAMA_MODEL}"; resolve_agent "ollama"
    else AI_MODE="allinone"; resolve_agent "$target"; fi
    qs ipc call status refresh >/dev/null 2>&1 || true; relaunch_quake
}
add_custom_agent() {
    local id="${1:-}" label="${2:-}" cmd="${3:-}" tmp="$AGENTS_FILE.tmp"; id="$(echo "$id" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9_-')"; label="${label//|/ -}"; cmd="${cmd//|/ }"
    [[ -n "$id" && -n "$cmd" ]] || { echo "Usage: quake-ai.sh add-agent <id> <label> <command>" >&2; exit 2; }
    case "$id" in agy|mcode|grok|vibe|claude|chatgpt|ollama) echo "Cannot override built-in agent '$id'" >&2; exit 2 ;; esac
    [[ -z "$label" ]] && label="$id ($cmd)"; if [[ -f "$AGENTS_FILE" ]]; then grep -Ev "^${id}\\|" "$AGENTS_FILE" > "$tmp" || true; mv "$tmp" "$AGENTS_FILE"; fi
    printf '%s|%s|%s\n' "$id" "$label" "$cmd" >> "$AGENTS_FILE"
}
remove_custom_agent() {
    local id="${1:-}" tmp="$AGENTS_FILE.tmp"; [[ -n "$id" && -f "$AGENTS_FILE" ]] || return 0
    grep -Ev "^${id}\\|" "$AGENTS_FILE" > "$tmp" || true; mv "$tmp" "$AGENTS_FILE"; [[ "$AI_AGENT" == "$id" ]] && { AI_AGENT="agy"; save_state; } || true
}
compute_geometry() {
    local mon_json full_w full_h hdr_h="${1:-40}"; [[ "$hdr_h" =~ ^[0-9]+$ ]] || hdr_h=40
    mon_json="$(hyprctl monitors -j 2>/dev/null || echo '[]')"
    read -r MON_NAME MON_X MON_Y MON_W MON_H SPEC_OPEN < <(jq -r '(.[] | select(.focused == true)) // .[0] // {name:"default", x:0, y:0, width:1920, height:1080, scale:1} | "\(.name // "default") \(.x) \(.y) \((.width / (.scale // 1)) | round) \((.height / (.scale // 1)) | round) \(if .specialWorkspace.name == "special:ai" then 1 else 0 end)"' <<<"$mon_json")
    MON_NAME="${MON_NAME:-default}"; MON_X="${MON_X:-0}"; MON_Y="${MON_Y:-0}"; MON_W="${MON_W:-1920}"; MON_H="${MON_H:-1080}"; SPEC_OPEN="${SPEC_OPEN:-0}"
    full_w=$(( (MON_W * 76 + 50) / 100 )); full_h=$(( (MON_H * 78 + 50) / 100 ))
    (( full_w > 1340 )) && full_w=1340; (( full_w < 1060 )) && full_w=1060; (( full_w > MON_W - 40 )) && full_w=$(( MON_W - 40 ))
    (( full_h > 840 )) && full_h=840; (( full_h < 660 )) && full_h=660; (( full_h > MON_H - 64 )) && full_h=$(( MON_H - 64 ))
    Q_FULL_H="$full_h"; Q_BASE_Y=$(( MON_Y + 36 + (MON_H - 36 - full_h) / 2 ))
    Q_X=$(( MON_X + (MON_W - full_w) / 2 + 12 )); Q_Y=$(( Q_BASE_Y + hdr_h + 6 )); Q_W=$(( full_w - 24 )); Q_H=$(( full_h - hdr_h - 20 ))
}
has_quake_client() { hyprctl clients -j 2>/dev/null | grep -q '"class": "quake-ai"'; }
is_special_ai_open() { hyprctl monitors -j 2>/dev/null | grep -q '"special:ai"'; }
save_fast() { printf 'Q_PID=%q\nQ_X=%q\nQ_BASE_Y=%q\nQ_W=%q\nQ_FULL_H=%q\nQ_HDR_H=%q\nQ_OPEN=%q\n' "${Q_PID:-}" "${Q_X:-432}" "${Q_BASE_Y:-42}" "${Q_W:-1056}" "${Q_FULL_H:-460}" "${Q_HDR_H:-40}" "${1:-0}" > "$FAST_FILE"; }

spawn_quake() {
    [[ "$AI_AGENT" == "ollama" ]] && { OLLAMA_MODEL="$(detect_ollama_model "$OLLAMA_HOST" "$OLLAMA_MODEL")"; sync_pi_ollama "$OLLAMA_HOST" "$OLLAMA_MODEL"; }
    resolve_agent "$AI_AGENT"
    local runner="$STATE_DIR/quake-ai-runner.sh" safe_title="${AI_LABEL//[\'\"]/}"
    {
        printf '#!/usr/bin/env bash\nexport PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.minimax-code/bin:$HOME/.minimax/bin:$HOME/.grok/bin:$HOME/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:$PATH"\n'
        printf 'export AI_MODE=%q AI_HARNESS=%q AI_AGENT=%q AI_LABEL=%q AI_BIN=%q AI_CMD=%q OLLAMA_HOST=%q OLLAMA_MODEL=%q SF_OLLAMA=%q SELF=%q RELAUNCH_LOCK=%q\n' "$AI_MODE" "$AI_HARNESS" "$AI_AGENT" "$AI_LABEL" "$AI_BIN" "$AI_CMD" "$OLLAMA_HOST" "$OLLAMA_MODEL" "$SF_OLLAMA" "$SELF" "$RELAUNCH_LOCK"
        cat <<'EOF'
[[ -f "$HOME/.config/superfedora/profile.env" ]] && source "$HOME/.config/superfedora/profile.env" && export USER_FULLNAME USER_EMAIL USER_DEVICE_NAME USER_GITHUB USER_WORKSPACE USER_AI_ROLE
[[ -n "${USER_WORKSPACE:-}" && -d "${USER_WORKSPACE/#\~/$HOME}" ]] && cd "${USER_WORKSPACE/#\~/$HOME}" || true; clear
if [[ "$AI_AGENT" == "ollama" ]]; then
    if [[ "$AI_HARNESS" == "pi" ]] && command -v pi >/dev/null 2>&1; then pi --provider ollama --model "$OLLAMA_MODEL"
    elif [[ "$AI_HARNESS" == "mcode" ]] && command -v mcode >/dev/null 2>&1; then OPENAI_BASE_URL="http://$OLLAMA_HOST/v1" OPENAI_API_KEY="ollama" mcode -m "$OLLAMA_MODEL"
    elif [[ "$AI_HARNESS" == "opencode" ]] && command -v opencode >/dev/null 2>&1; then OLLAMA_HOST="http://$OLLAMA_HOST" opencode
    elif [[ "$AI_HARNESS" == "aider" ]] && command -v aider >/dev/null 2>&1; then OLLAMA_API_BASE="http://$OLLAMA_HOST" aider --model "ollama_chat/$OLLAMA_MODEL"
    elif [[ "$AI_HARNESS" == "ollama-cli" ]] && command -v ollama >/dev/null 2>&1; then OLLAMA_HOST="$OLLAMA_HOST" ollama run "$OLLAMA_MODEL"
    elif [[ "$AI_HARNESS" == "sf-chat" && -x "$SF_OLLAMA" ]]; then "$SF_OLLAMA" chat "$OLLAMA_HOST" "$OLLAMA_MODEL"
    elif command -v pi >/dev/null 2>&1; then pi --provider ollama --model "$OLLAMA_MODEL"
    elif command -v ollama >/dev/null 2>&1; then OLLAMA_HOST="$OLLAMA_HOST" ollama run "$OLLAMA_MODEL"
    elif [[ -x "$SF_OLLAMA" ]]; then "$SF_OLLAMA" chat "$OLLAMA_HOST" "$OLLAMA_MODEL"
    else printf '\033[1;33m[!]\033[0m Cannot connect to Ollama at %s (%s)\n' "$OLLAMA_HOST" "$OLLAMA_MODEL"; fi
elif command -v "$AI_BIN" >/dev/null 2>&1; then eval "$AI_CMD"
else printf '\033[1;33m[!]\033[0m %s (%s) is not installed yet. Click [Dock Settings] in the SuperDock header to pick another agent or harness.\n' "$AI_LABEL" "$AI_BIN"; fi
"${SHELL:-/bin/bash}"
[[ -f "$RELAUNCH_LOCK" ]] || "$SELF" hide >/dev/null 2>&1 || true
EOF
    } > "$runner"; chmod +x "$runner"
    if [[ "${DEFAULT_TERMINAL:-kitty}" == "kitty" ]] && command -v kitty >/dev/null 2>&1; then
        hyprctl dispatch exec "[workspace special:ai silent; float; size $Q_W $Q_H; move $Q_X $Q_Y] kitty --class quake-ai -o 'map escape launch --type=background $SELF hide' -o 'map shift+escape send_text all \x1b' -o 'map alt+grave launch --type=background qs ipc call superdeck open ai' -o 'map alt+1 launch --type=background qs ipc call superdeck open 1' -o 'map alt+2 launch --type=background qs ipc call superdeck open 2' -o 'map alt+3 launch --type=background qs ipc call superdeck open 3' -o 'map alt+4 launch --type=background qs ipc call superdeck open 4' -o 'map alt+5 launch --type=background qs ipc call superdeck open 5' -o 'map alt+6 launch --type=background qs ipc call superdeck open 6' -o 'map alt+7 launch --type=background qs ipc call superdeck open 7' -o 'map alt+8 launch --type=background qs ipc call superdeck open 8' -o 'map alt+9 launch --type=background qs ipc call superdeck open 9' -o 'map alt+0 launch --type=background qs ipc call superdeck open 0' --title 'Quake AI — $safe_title' -e $runner" >/dev/null
    else hyprctl dispatch exec "[workspace special:ai silent; float; size $Q_W $Q_H; move $Q_X $Q_Y] xdg-terminal-exec --class quake-ai --title 'Quake AI — $safe_title' -e $runner" >/dev/null; fi
    for _ in {1..30}; do has_quake_client && break; sleep 0.04; done
}
show_quake() {
    local hdr_h="${1:-40}" batch=""; exec 9>"$STATE_DIR/quake-ai.lock"; flock -w 2 9 || true
    # shellcheck disable=SC1090
    [[ -f "$FAST_FILE" ]] && source "$FAST_FILE"; compute_geometry "$hdr_h"
    if [[ -n "${Q_PID:-}" && -d "/proc/$Q_PID" ]] && tr '\0' ' ' < "/proc/$Q_PID/cmdline" 2>/dev/null | grep -Eq 'quake-ai|alt\+1'; then
        Q_HDR_H="$hdr_h"; (( SPEC_OPEN == 1 )) || batch="dispatch togglespecialworkspace ai; "
        hyprctl --batch "${batch}dispatch resizewindowpixel exact $Q_W $Q_H,class:^(quake-ai)$; dispatch movewindowpixel exact $Q_X $Q_Y,class:^(quake-ai)$; dispatch focuswindow class:^(quake-ai)$" >/dev/null
        save_fast 1; return 0
    fi
    if has_quake_client; then
        Q_PID="$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class=="quake-ai") | .pid' | head -n1)"
        if [[ -n "$Q_PID" ]] && ! tr '\0' ' ' < "/proc/$Q_PID/cmdline" 2>/dev/null | grep -Eq 'quake-ai|alt\+1'; then
            touch "$RELAUNCH_LOCK"; hyprctl dispatch closewindow "class:^(quake-ai)$" >/dev/null 2>&1 || true
            for _ in {1..20}; do has_quake_client || break; sleep 0.04; done; rm -f "$RELAUNCH_LOCK"
        fi
    fi
    has_quake_client || spawn_quake
    Q_PID="$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class=="quake-ai") | .pid' | head -n1)"; Q_HDR_H="$hdr_h"
    is_special_ai_open || batch="dispatch togglespecialworkspace ai; "
    hyprctl --batch "${batch}dispatch resizewindowpixel exact $Q_W $Q_H,class:^(quake-ai)$; dispatch movewindowpixel exact $Q_X $Q_Y,class:^(quake-ai)$; dispatch focuswindow class:^(quake-ai)$" >/dev/null
    save_fast 1
}
hide_quake() {
    [[ -f "$RELAUNCH_LOCK" ]] && return 0
    exec 9>"$STATE_DIR/quake-ai.lock"; flock -w 2 9 || true
    # shellcheck disable=SC1090
    [[ -f "$FAST_FILE" ]] && source "$FAST_FILE"
    if is_special_ai_open; then hyprctl dispatch togglespecialworkspace ai >/dev/null || true; fi
    [[ -n "${Q_PID:-}" && -d "/proc/$Q_PID" ]] && save_fast 0
    [[ "${1:-}" == "keep-deck" ]] || qs ipc call superdeck close >/dev/null 2>&1 || true
}
relaunch_quake() {
    touch "$RELAUNCH_LOCK"; rm -f "$FAST_FILE"; hyprctl dispatch closewindow "class:^(quake-ai)$" >/dev/null 2>&1 || true
    for _ in {1..25}; do has_quake_client || break; sleep 0.04; done
    show_quake "${1:-40}"; rm -f "$RELAUNCH_LOCK"
}
prompt_ollama() {
    local host model choices; host="$(printf '%s\n127.0.0.1:11434\nlocalhost:11434\n' "$OLLAMA_HOST" | awk '!seen[$0]++' | fuzzel --dmenu --prompt 'Ollama Server (host:port) > ' --width 48)" || return 0
    [[ -n "${host// /}" ]] || return 0; set_ollama "$host" ""; choices="$("$SF_OLLAMA" fuzzel-models "$OLLAMA_HOST" "$OLLAMA_MODEL" 2>/dev/null || true)"
    model="$(printf '%s\n' "$choices" | fuzzel --dmenu --prompt "Model ($OLLAMA_HOST) > " --width 56)" || return 0
    [[ -z "${model// /}" || "$model" == "[!]"* ]] && return 0; set_ollama "$OLLAMA_HOST" "${model%% *}"; resolve_agent "ollama"
    if has_quake_client && is_special_ai_open; then relaunch_quake; fi
}
prompt_add_agent() {
    local cmd id label; cmd="$(printf 'pi\naider\nopencode\ngemini\n' | fuzzel --dmenu --prompt 'Agent Command > ' --width 44)" || return 0
    [[ -n "${cmd// /}" ]] || return 0; id="$(echo "${cmd%% *}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
    label="$(printf '%s (%s)\n%s\n' "${id^} CLI" "$cmd" "$cmd" | fuzzel --dmenu --prompt 'Agent Label > ' --width 44)" || return 0
    add_custom_agent "$id" "${label:-$id}" "$cmd"; resolve_agent "$id"; if has_quake_client && is_special_ai_open; then relaunch_quake; fi
}
ask_agent() {
    local q="${*:-}" out=""; [[ -n "${q// /}" ]] || { echo "Please enter a prompt."; return 0; }; resolve_agent "$AI_AGENT"
    [[ "$AI_AGENT" == "ollama" ]] && command -v pi >/dev/null 2>&1 && { sync_pi_ollama "$OLLAMA_HOST" "$OLLAMA_MODEL"; if out="$(timeout 45 pi --provider ollama --model "$OLLAMA_MODEL" -p "$q" </dev/null 2>&1)" && [[ -n "${out// /}" ]]; then printf '%s\n' "$out"; return 0; fi; }
    case "$AI_AGENT" in agy|grok|vibe|claude) if command -v "$AI_BIN" >/dev/null 2>&1 && out="$(timeout 45 "$AI_BIN" -p "$q" </dev/null 2>&1)" && [[ -n "${out// /}" ]]; then printf '%s\n' "$out"; return 0; fi ;; esac
    "$SF_OLLAMA" ask "$OLLAMA_HOST" "$OLLAMA_MODEL" "$q"
}
case "${1:-toggle}" in
    toggle)        if has_quake_client && is_special_ai_open; then hide_quake; else show_quake "${2:-40}"; fi ;;
    show|open)     show_quake "${2:-40}" ;;
    hide|close)    hide_quake "${2:-}" ;;
    restart|relaunch) relaunch_quake "${2:-40}" ;;
    select-agent)  resolve_agent "${2:-agy}"; qs ipc call status refresh >/dev/null 2>&1 || true; if has_quake_client; then relaunch_quake; fi ;;
    set-agent)     resolve_agent "${2:-agy}"; qs ipc call status refresh >/dev/null 2>&1 || true; relaunch_quake ;;
    set-config)    set_config "${2:-allinone}" "${3:-agy}" "${4:-}" "${5:-}" ;;
    probe-host)    set_ollama "${2:-$OLLAMA_HOST}" "${3:-}"; qs ipc call status refresh >/dev/null 2>&1 || true ;;
    next-agent)    mapfile -t IDS < <(all_agents | cut -d'|' -f1); NEXT="${IDS[0]:-agy}"; for i in "${!IDS[@]}"; do [[ "${IDS[$i]}" == "$AI_AGENT" ]] && { NEXT="${IDS[$(( (i + 1) % ${#IDS[@]} ))]}"; break; }; done
                   resolve_agent "$NEXT"; qs ipc call status refresh >/dev/null 2>&1 || true; if has_quake_client; then relaunch_quake; fi ;;
    ask|query)     shift; ask_agent "$@" ;;
    list-agents)   list_agents ;;
    set-ollama)    set_ollama "${2:-}" "${3:-}" ;;
    add-agent)     add_custom_agent "${2:-}" "${3:-}" "${4:-}" ;;
    remove-agent)  remove_custom_agent "${2:-}" ;;
    prompt-ollama) prompt_ollama ;;
    prompt-add)    prompt_add_agent ;;
    configure|tui) "$SF_OLLAMA" table "$OLLAMA_HOST" "$OLLAMA_MODEL" ;;
    status)        resolve_agent "$AI_AGENT"; compute_geometry "${2:-40}"; printf 'Mode: %s | Agent: %s (%s) | Harness: %s | Ollama: %s (%s) | Geometry: %dx%d+%d+%d\n' "$AI_MODE" "$AI_LABEL" "$AI_CMD" "$AI_HARNESS" "$OLLAMA_HOST" "$OLLAMA_MODEL" "$Q_W" "$Q_H" "$Q_X" "$Q_Y" ;;
    *)             sed -n '7,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
