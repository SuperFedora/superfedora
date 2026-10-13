#!/usr/bin/env bash
# Restart Quickshell inside the Hyprland session.
pkill -x quickshell
sleep 0.3
hyprctl dispatch exec quickshell >/dev/null
