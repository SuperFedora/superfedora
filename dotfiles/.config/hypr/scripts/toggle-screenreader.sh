#!/usr/bin/env bash
# COSMIC ScreenReader toggle (Super+Alt+S) using Orca.
if pgrep -x orca >/dev/null; then
    pkill -x orca
    notify-send -a System -t 1500 "Screen reader off"
else
    orca --replace >/dev/null 2>&1 &
    disown
    notify-send -a System -t 1500 "Screen reader on"
fi
