#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# session-ctl.sh — Desktop Environment (DE) & Session Selector for Lock Screen
# ==============================================================================
# Usage:
#   superfedora session status              Print active/selected DE label for hyprlock
#   superfedora session list                List all installed Wayland/X11 sessions
#   superfedora session next                Cycle to the next installed DE session
#   superfedora session set <session-id>    Select a specific DE session (e.g. gnome, hyprland)
#   superfedora session switch              Exit current compositor to launch selected DE
#   superfedora session pick                Interactive Fuzzel DE selector
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
STATE_FILE="$STATE_DIR/session.env"
mkdir -p "$STATE_DIR"

discover_sessions() {
    SESS_IDS=()
    SESS_NAMES=()
    local f id name has_sf=0
    [[ -f /usr/share/wayland-sessions/superfedora.desktop ]] && has_sf=1
    for f in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do
        [[ -f "$f" ]] || continue
        grep -qiE '^(NoDisplay|Hidden)=true' "$f" 2>/dev/null && continue
        id="$(basename "$f" .desktop)"
        if [[ "$has_sf" -eq 1 && ( "$id" == "hyprland" || "$id" == "hyprland-uwsm" ) ]]; then
            continue
        fi
        name="$(grep -m1 '^Name=' "$f" 2>/dev/null | cut -d= -f2- || echo "$id")"
        SESS_IDS+=("$id")
        SESS_NAMES+=("${name:-$id}")
    done
    if [[ "${#SESS_IDS[@]}" -eq 0 ]]; then
        SESS_IDS=("superfedora")
        SESS_NAMES=("SuperFedora")
    fi
}

get_current_id() {
    local cur=""
    # shellcheck disable=SC1090
    [[ -f "$STATE_FILE" ]] && source "$STATE_FILE" && cur="${SELECTED_SESSION:-}"
    if [[ -z "$cur" ]] && command -v gdbus >/dev/null 2>&1; then
        cur="$(gdbus call --system --dest org.freedesktop.Accounts \
            --object-path "/org/freedesktop/Accounts/User$(id -u)" \
            --method org.freedesktop.DBus.Properties.Get \
            org.freedesktop.Accounts.User Session 2>/dev/null | sed -n "s/.*'\\([^']*\\)'.*/\\1/p" || true)"
    fi
    if [[ ( -z "$cur" || "$cur" == "hyprland" || "$cur" == "hyprland-uwsm" ) && -f /usr/share/wayland-sessions/superfedora.desktop ]]; then
        cur="superfedora"
    fi
    echo "${cur:-superfedora}"
}

set_session_id() {
    local target="$1"
    printf 'SELECTED_SESSION="%s"\n' "$target" > "$STATE_FILE"
    if command -v gdbus >/dev/null 2>&1; then
        gdbus call --system --dest org.freedesktop.Accounts \
            --object-path "/org/freedesktop/Accounts/User$(id -u)" \
            --method org.freedesktop.Accounts.User.SetSession "$target" >/dev/null 2>&1 || true
        gdbus call --system --dest org.freedesktop.Accounts \
            --object-path "/org/freedesktop/Accounts/User$(id -u)" \
            --method org.freedesktop.Accounts.User.SetXSession "$target" >/dev/null 2>&1 || true
    fi
}

discover_sessions
CUR_ID="$(get_current_id)"
CUR_IDX=0
for i in "${!SESS_IDS[@]}"; do
    if [[ "${SESS_IDS[$i]}" == "$CUR_ID" ]]; then
        CUR_IDX="$i"
        break
    fi
done
CUR_NAME="${SESS_NAMES[$CUR_IDX]}"

case "${1:-status}" in
    status)
        printf '<b>󰒓 DE: %s</b>\n' "$CUR_NAME" ;;
    list)
        for i in "${!SESS_IDS[@]}"; do
            mark="   "; [[ "$i" -eq "$CUR_IDX" ]] && mark="[*]"
            printf '%s %-20s (%s)\n' "$mark" "${SESS_IDS[$i]}" "${SESS_NAMES[$i]}"
        done ;;
    next)
        next_idx=$(( (CUR_IDX + 1) % ${#SESS_IDS[@]} ))
        set_session_id "${SESS_IDS[$next_idx]}"
        printf '<b>󰒓 DE: %s</b>\n' "${SESS_NAMES[$next_idx]}" ;;
    set)
        target="${2:-hyprland}"
        set_session_id "$target" ;;
    switch)
        if command -v gdbus >/dev/null 2>&1; then
            gdbus call --system --dest org.gnome.DisplayManager \
                --object-path /org/gnome/DisplayManager/LocalDisplayFactory \
                --method org.gnome.DisplayManager.LocalDisplayFactory.CreateTransientDisplay >/dev/null 2>&1 || true
        fi
        systemctl --user stop hyprland-session.target >/dev/null 2>&1 || true
        systemctl --user reset-failed >/dev/null 2>&1 || true
        hyprctl dispatch exit >/dev/null 2>&1 || loginctl terminate-user "$USER" >/dev/null 2>&1 || true ;;
    pick)
        choice="$(for i in "${!SESS_IDS[@]}"; do printf '%s: %s\n' "${SESS_IDS[$i]}" "${SESS_NAMES[$i]}"; done \
            | fuzzel --dmenu --prompt "Select DE > " --lines 6 --width 38)" || exit 0
        sel_id="${choice%%:*}"
        [[ -n "$sel_id" ]] && set_session_id "$sel_id" ;;
    *)
        sed -n '7,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
