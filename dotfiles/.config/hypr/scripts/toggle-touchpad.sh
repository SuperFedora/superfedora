#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# toggle-touchpad.sh — Hardware Input/Output Toggles (Touchpad, Webcam, Mic, Speaker)
# Usage:
#   toggle-touchpad.sh [touchpad]                      Toggle touchpad on/off
#   toggle-touchpad.sh webcam [toggle|on|off|status]   Toggle web camera on/off
#   toggle-touchpad.sh mic [toggle|mute|unmute|status] Toggle microphone mute
#   toggle-touchpad.sh speaker [toggle|mute|unmute]    Toggle speaker mute
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
WEBCAM_FILE="$STATE_DIR/webcam-enabled"
WP_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d"
WP_CONF="$WP_CONF_DIR/99-superfedora-webcam.conf"
mkdir -p "$STATE_DIR"

refresh_qs() {
    if command -v qs >/dev/null 2>&1 && pgrep -x quickshell >/dev/null 2>&1; then
        qs ipc call status refresh >/dev/null 2>&1 || true
    fi
}

cmd_webcam() {
    local sub="${1:-toggle}" cur="on" target="off" rt="${XDG_RUNTIME_DIR:-/tmp}"
    [[ -f "$WEBCAM_FILE" ]] && cur="$(tr -d '[:space:]' < "$WEBCAM_FILE")"
    [[ "$cur" == "off" || "$cur" == "0" || "$cur" == "false" ]] && cur="off" || cur="on"
    [[ "$sub" == "status" ]] && { echo "$cur"; return 0; }
    case "$sub" in
        on|enable|1|true)   target="on" ;;
        off|disable|0|false) target="off" ;;
        *) [[ "$cur" == "off" ]] && target="on" || target="off" ;;
    esac
    echo "$target" > "$WEBCAM_FILE"
    refresh_qs
    local sink_st src_st
    sink_st="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
    [[ "$sink_st" == Volume:* ]] && echo "$sink_st" > "$rt/sf-sink.state"
    src_st="$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || true)"
    [[ "$src_st" == Volume:* ]] && echo "$src_st" > "$rt/sf-src.state"
    [[ -f "$rt/sf-webcam.pid" ]] && kill "$(cat "$rt/sf-webcam.pid" 2>/dev/null)" 2>/dev/null || true
    if [[ "$target" == "off" ]]; then
        mkdir -p "$WP_CONF_DIR"
        printf 'wireplumber.profiles = {\n  main = {\n    monitor.v4l2 = disabled\n    monitor.libcamera = disabled\n  }\n}\n' > "$WP_CONF"
        sudo -n modprobe -r uvcvideo 2>/dev/null || true
        notify-send -a "SuperFedora" -t 1500 "Web Camera: OFF" "Camera input disabled" 2>/dev/null || true
    else
        rm -f "$WP_CONF"
        sudo -n modprobe uvcvideo 2>/dev/null || true
        notify-send -a "SuperFedora" -t 1500 "Web Camera: ON" "Camera input enabled" 2>/dev/null || true
    fi
    (
        echo "$BASHPID" > "$rt/sf-webcam.pid"
        sleep 0.2
        systemctl --user reset-failed wireplumber 2>/dev/null || true
        systemctl --user restart wireplumber 2>/dev/null || true
        for _ in 1 2 3 4 5 6; do wpctl get-volume @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && break; sleep 0.15; done
        [[ "$(cat "$rt/sf-sink.state" 2>/dev/null)" == *"[MUTED]"* ]] && wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 2>/dev/null || true
        [[ "$(cat "$rt/sf-src.state" 2>/dev/null)" == *"[MUTED]"* ]] && wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1 2>/dev/null || true
        refresh_qs
    ) </dev/null >/dev/null 2>&1 & disown || true
}

cmd_audio() {
    local node="$1" label="$2" sub="${3:-toggle}"
    case "$sub" in
        status) wpctl get-volume "$node" 2>/dev/null || true; return 0 ;;
        mute|off|1)   wpctl set-mute "$node" 1 2>/dev/null || true ;;
        unmute|on|0)  wpctl set-mute "$node" 0 2>/dev/null || true ;;
        up)           wpctl set-volume -l 1.0 "$node" 5%+ 2>/dev/null || true ;;
        down)         wpctl set-volume "$node" 5%- 2>/dev/null || true ;;
        *)            wpctl set-mute "$node" toggle 2>/dev/null || true ;;
    esac
    refresh_qs
    local st
    st="$(wpctl get-volume "$node" 2>/dev/null || true)"
    if [[ "$st" == *"[MUTED]"* ]]; then
        notify-send -a "SuperFedora" -t 1400 "$label: Muted" "Audio muted" 2>/dev/null || true
    else
        notify-send -a "SuperFedora" -t 1400 "$label: Active" "$st" 2>/dev/null || true
    fi
}

case "${1:-touchpad}" in
    webcam|camera|cam) shift || true; cmd_webcam "${1:-toggle}" ;;
    mic|microphone|input) shift || true; cmd_audio "@DEFAULT_AUDIO_SOURCE@" "Microphone" "${1:-toggle}" ;;
    speaker|speakers|output|sink) shift || true; cmd_audio "@DEFAULT_AUDIO_SINK@" "Speakers" "${1:-toggle}" ;;
    *)
        state="${XDG_RUNTIME_DIR:-/tmp}/touchpad-disabled"
        if [[ -f "$state" ]]; then
            hyprctl keyword 'device[elan-touchpad]:enabled' true >/dev/null
            rm -f "$state"
            notify-send -a System -t 1500 "Touchpad on"
        else
            hyprctl keyword 'device[elan-touchpad]:enabled' false >/dev/null
            touch "$state"
            notify-send -a System -t 1500 "Touchpad off"
        fi
        ;;
esac
