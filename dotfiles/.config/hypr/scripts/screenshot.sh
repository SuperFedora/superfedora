#!/usr/bin/env bash
# Capture & Omarchy center-bar tools: screenshot, screen recording (start/pause/stop), and color picker.
# Usage: screenshot.sh [region|window|screen|record|record-region|record-pause|record-stop|color]
set -u
export PATH="$HOME/.local/bin:$PATH"
state="$HOME/.config/superfedora/recording-file"
pflag="$HOME/.config/superfedora/recording-paused"

case "${1:-region}" in
    record-pause)
        if pgrep -x wf-recorder >/dev/null || pgrep -f '^gpu-screen-recorder' >/dev/null; then
            if [ -f "$pflag" ]; then
                rm -f "$pflag"
                pkill -CONT -x wf-recorder 2>/dev/null || pkill -CONT -f '^gpu-screen-recorder' 2>/dev/null || true
                notify-send -a SuperFedora "Screen Recording Resumed" "Recording active."
            else
                mkdir -p "$HOME/.config/superfedora" && touch "$pflag"
                pkill -STOP -x wf-recorder 2>/dev/null || pkill -STOP -f '^gpu-screen-recorder' 2>/dev/null || true
                notify-send -a SuperFedora "Screen Recording Paused" "Click START/RESUME in the top bar to continue."
            fi
            qs ipc call status refresh >/dev/null 2>&1 || true
        fi
        exit 0 ;;
    record-stop)
        rm -f "$pflag"
        if pgrep -x wf-recorder >/dev/null || pgrep -f '^gpu-screen-recorder' >/dev/null; then
            pkill -CONT -x wf-recorder 2>/dev/null || pkill -CONT -f '^gpu-screen-recorder' 2>/dev/null || true
            pkill -INT -x wf-recorder 2>/dev/null || pkill -INT -f '^gpu-screen-recorder' 2>/dev/null || true
            sleep 0.4
            f="$(cat "$state" 2>/dev/null || echo "$HOME/Videos/Recordings")"
            rm -f "$state"
            qs ipc call status refresh >/dev/null 2>&1 || true
            notify-send -a SuperFedora "Screen Recording Saved" "$(basename "$f")"
        fi
        exit 0 ;;
    record|record-region)
        vdir="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Recordings"
        mkdir -p "$vdir"
        if pgrep -x wf-recorder >/dev/null || pgrep -f '^gpu-screen-recorder' >/dev/null; then
            exec "$0" record-stop
        fi
        rm -f "$pflag"
        out="$vdir/recording-$(date +%Y%m%d-%H%M%S).mp4"
        mkdir -p "$HOME/.config/superfedora"
        echo "$out" > "$state"
        if [ "${1:-}" = "record-region" ]; then
            geom="$(slurp -d -b 1a1b2666 -c 7aa2f7ff -w 2)" || { rm -f "$state"; exit 0; }
            nohup wf-recorder -g "$geom" -f "$out" >/dev/null 2>&1 &
        else
            mon="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty')"
            nohup wf-recorder ${mon:+-o "$mon"} -f "$out" >/dev/null 2>&1 &
        fi
        sleep 0.25
        qs ipc call status refresh >/dev/null 2>&1 || true
        notify-send -a SuperFedora "Screen Recording Started" "Use the PAUSE / STOP controls in the top bar."
        exit 0 ;;
    color)
        sleep 0.15
        hex="$(hyprpicker -a 2>/dev/null | tr -d '[:space:]')"
        [ -n "$hex" ] && notify-send -a SuperFedora "Color Picker" "Copied $hex to clipboard"
        exit 0 ;;
esac

dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$dir"
file="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"

case "${1:-region}" in
    region)
        geom="$(slurp -d -b 1a1b2666 -c 7aa2f7ff -w 2)" || exit 0
        grim -g "$geom" "$file" ;;
    window)
        geom="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        grim -g "$geom" "$file" ;;
    screen)
        mon="$(hyprctl activeworkspace -j | jq -r .monitor)"
        grim -o "$mon" "$file" ;;
esac || exit 1

wl-copy < "$file"
notify-send -a Screenshot -i "$file" "Screenshot saved" "Copied to clipboard · $(basename "$file")"
