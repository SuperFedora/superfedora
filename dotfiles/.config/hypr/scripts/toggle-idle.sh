#!/usr/bin/env bash
# Toggle hypridle on/off (stay-awake mode). Bar shows a coffee icon while off.
if pgrep -x hypridle >/dev/null; then
    pkill -x hypridle
    notify-send -a System "Stay awake" "Idle, lock and screen-off are paused"
else
    hyprctl dispatch exec hypridle >/dev/null
    notify-send -a System "Idle enabled" "Screensaver, lock and screen-off resume"
fi
