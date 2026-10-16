#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# toggle-touchpad.sh — Hardware Input/Output Toggles (Touchpad, Webcam, Mic, Speaker, ThinkPad Kbd Backlight)
# Usage:
#   toggle-touchpad.sh [touchpad]                           Toggle touchpad on/off
#   toggle-touchpad.sh webcam [toggle|on|off|status]        Toggle web camera on/off
#   toggle-touchpad.sh mic [toggle|mute|unmute|status]      Toggle microphone mute + ThinkPad micmute LED
#   toggle-touchpad.sh speaker [toggle|mute|unmute]         Toggle speaker mute + ThinkPad mute LED
#   toggle-touchpad.sh kbd-backlight [cycle|up|down|0|1|2]  Cycle/set ThinkPad keyboard backlight
#   toggle-touchpad.sh dpms [off|on|sync]                   Turn screen + keyboard lights off or restore on wake
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
WEBCAM_FILE="$STATE_DIR/webcam-enabled"
KBD_FILE="$STATE_DIR/kbd-backlight"
WP_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d"
WP_CONF="$WP_CONF_DIR/99-superfedora-webcam.conf"
mkdir -p "$STATE_DIR"

refresh_qs() {
    if command -v qs >/dev/null 2>&1 && pgrep -x quickshell >/dev/null 2>&1; then
        qs ipc call status refresh >/dev/null 2>&1 || true
    fi
}

set_led() {
    local dev="$1" val="$2" sys="/sys/class/leds/$1/brightness"
    if command -v brightnessctl >/dev/null 2>&1; then
        brightnessctl -q --device="$dev" set "$val" >/dev/null 2>&1 || true
    fi
    [[ -w "$sys" ]] && echo "$val" > "$sys" 2>/dev/null || true
    return 0
}

kbd_leds_list() {
    local p name
    for p in /sys/class/leds/*; do
        [[ -e "$p/brightness" ]] || continue
        name="${p##*/}"
        case "$name" in
            *kbd_backlight*|platform::micmute|platform::mute|tpacpi::power|tpacpi::thinkvantage|input*::capslock|input*::numlock|input*::scrolllock)
                echo "$name"
                ;;
        esac
    done
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
    local node="$1" label="$2" sub="${3:-toggle}" led_path="$4" led_dev=""
    case "$sub" in
        status) wpctl get-volume "$node" 2>/dev/null || true; return 0 ;;
        mute|off|1)   wpctl set-mute "$node" 1 2>/dev/null || true ;;
        unmute|on|0)  wpctl set-mute "$node" 0 2>/dev/null || true ;;
        up)           wpctl set-volume -l 1.0 "$node" 5%+ 2>/dev/null || true ;;
        down)         wpctl set-volume "$node" 5%- 2>/dev/null || true ;;
        *)            wpctl set-mute "$node" toggle 2>/dev/null || true ;;
    esac
    local st led_val=0
    st="$(wpctl get-volume "$node" 2>/dev/null || true)"
    [[ "$st" == *"[MUTED]"* ]] && led_val=1
    if [[ -n "$led_path" ]]; then
        led_dev="${led_path#/sys/class/leds/}"
        led_dev="${led_dev%/brightness}"
        set_led "$led_dev" "$led_val"
    fi
    refresh_qs
    if [[ "$node" == "@DEFAULT_AUDIO_SINK@" ]]; then
        qs ipc call osd volume >/dev/null 2>&1 || true
    fi
    if [[ "$led_val" -eq 1 ]]; then
        notify-send -a "SuperFedora" -t 1400 "$label: Muted" "Audio muted" 2>/dev/null || true
    else
        notify-send -a "SuperFedora" -t 1400 "$label: Active" "$st" 2>/dev/null || true
    fi
}

cmd_kbd_backlight() {
    local sub="${1:-cycle}" dev="tpacpi::kbd_backlight" sys="/sys/class/leds/tpacpi::kbd_backlight/brightness" cur=0 next=0 lbl="OFF"
    if [[ -f "$sys" ]]; then cur="$(cat "$sys" 2>/dev/null || echo 0)"
    elif command -v brightnessctl >/dev/null 2>&1 && brightnessctl --device="$dev" get >/dev/null 2>&1; then
        cur="$(brightnessctl --device="$dev" get 2>/dev/null || echo 0)"
    elif [[ -f "$KBD_FILE" ]]; then cur="$(tr -d '[:space:]' < "$KBD_FILE" 2>/dev/null || echo 0)"; fi
    [[ "$cur" =~ ^[0-9]+$ ]] || cur=0
    [[ "$sub" == "status" ]] && { echo "$cur"; return 0; }
    case "$sub" in
        0|off)  next=0 ;;
        1|low)  next=1 ;;
        2|high) next=2 ;;
        up)     next=$(( cur < 2 ? cur + 1 : 2 )) ;;
        down)   next=$(( cur > 0 ? cur - 1 : 0 )) ;;
        *)      next=$(( (cur + 1) % 3 )) ;;
    esac
    set_led "$dev" "$next"
    echo "$next" > "$KBD_FILE"
    refresh_qs
    case "$next" in 1) lbl="LOW (50%)" ;; 2) lbl="HIGH (100%)" ;; *) lbl="OFF (0%)" ;; esac
    notify-send -a "SuperFedora" -t 1400 "ThinkPad Keyboard Backlight: $lbl" "Level $next / 2" 2>/dev/null || true
}

cmd_dpms() {
    local sub="${1:-off}" rt="${XDG_RUNTIME_DIR:-/tmp}"
    local state_file="$rt/sf-dpms-leds.state" pid_file="$rt/sf-dpms-watch.pid" dev cur
    case "$sub" in
        off)
            PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH" idlescreen stop >/dev/null 2>&1 || true
            if [[ ! -f "$state_file" ]]; then
                : > "$state_file"
                while IFS= read -r dev; do
                    [[ -n "$dev" ]] || continue
                    cur="$(cat "/sys/class/leds/$dev/brightness" 2>/dev/null || echo 0)"
                    [[ "$cur" =~ ^[0-9]+$ ]] || cur=0
                    printf '%s=%s\n' "$dev" "$cur" >> "$state_file"
                done < <(kbd_leds_list)
            fi
            while IFS= read -r dev; do
                [[ -n "$dev" ]] && set_led "$dev" 0
            done < <(kbd_leds_list)
            hyprctl dispatch dpms off >/dev/null 2>&1 || true
            [[ -f "$pid_file" ]] && kill "$(cat "$pid_file" 2>/dev/null)" 2>/dev/null || true
            (
                echo "$BASHPID" > "$pid_file"
                sleep 1.2
                while [[ -f "$state_file" ]]; do
                    if hyprctl monitors -j 2>/dev/null | grep -q '"dpmsStatus": true'; then
                        "$0" dpms on >/dev/null 2>&1 || true
                        break
                    fi
                    sleep 0.5
                done
                rm -f "$pid_file"
            ) </dev/null >/dev/null 2>&1 & disown || true
            ;;
        on)
            [[ -f "$pid_file" ]] && kill "$(cat "$pid_file" 2>/dev/null)" 2>/dev/null || true
            rm -f "$pid_file"
            hyprctl dispatch dpms on >/dev/null 2>&1 || true
            if [[ -f "$state_file" ]]; then
                while IFS='=' read -r dev cur; do
                    [[ -n "$dev" && "$cur" =~ ^[0-9]+$ ]] && set_led "$dev" "$cur"
                done < "$state_file"
                rm -f "$state_file"
            elif [[ -f "$KBD_FILE" ]]; then
                cur="$(tr -d '[:space:]' < "$KBD_FILE" 2>/dev/null || echo 0)"
                [[ "$cur" =~ ^[0-9]+$ ]] && set_led "tpacpi::kbd_backlight" "$cur"
            fi
            refresh_qs
            ;;
        sync)
            if hyprctl monitors -j 2>/dev/null | grep -q '"dpmsStatus": false'; then
                [[ -f "$state_file" ]] || cmd_dpms off
            elif [[ -f "$state_file" ]]; then
                cmd_dpms on
            fi
            ;;
    esac
}

case "${1:-touchpad}" in
    webcam|camera|cam) shift || true; cmd_webcam "${1:-toggle}" ;;
    mic|microphone|input) shift || true; cmd_audio "@DEFAULT_AUDIO_SOURCE@" "Microphone" "${1:-toggle}" "/sys/class/leds/platform::micmute/brightness" ;;
    speaker|speakers|output|sink) shift || true; cmd_audio "@DEFAULT_AUDIO_SINK@" "Speakers" "${1:-toggle}" "/sys/class/leds/platform::mute/brightness" ;;
    kbd|kbd-backlight|backlight) shift || true; cmd_kbd_backlight "${1:-cycle}" ;;
    dpms|screen) shift || true; cmd_dpms "${1:-off}" ;;
    *)
        [[ "${1:-}" == "touchpad" ]] && { shift || true; }
        sub="${1:-toggle}"
        state="${XDG_RUNTIME_DIR:-/tmp}/touchpad-disabled"
        cfg_val="$(tr -d '[:space:]' < "$STATE_DIR/touchpad-enabled" 2>/dev/null || echo 1)"
        cur_on=1
        [[ -f "$state" || "$cfg_val" == "0" || "$cfg_val" == "off" ]] && cur_on=0
        case "$sub" in
            on|1|enable|true) want_on=1 ;;
            off|0|disable|false) want_on=0 ;;
            *) want_on=$(( 1 - cur_on )) ;;
        esac
        if [[ "$want_on" -eq 1 ]]; then
            hyprctl keyword 'device[elan-touchpad]:enabled' true >/dev/null 2>&1 || true
            rm -f "$state"
            echo "1" > "$STATE_DIR/touchpad-enabled"
            refresh_qs
            notify-send -a System -t 1500 "Touchpad on"
        else
            hyprctl keyword 'device[elan-touchpad]:enabled' false >/dev/null 2>&1 || true
            touch "$state"
            echo "0" > "$STATE_DIR/touchpad-enabled"
            refresh_qs
            notify-send -a System -t 1500 "Touchpad off"
        fi
        ;;
esac
