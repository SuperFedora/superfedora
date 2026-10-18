#!/usr/bin/env bash
# Omarchy-style menu built on fuzzel --dmenu.
# Usage: menu.sh [main|apps|capture|toggle|style|setup|system]
set -u

[[ -x "$HOME/.local/bin/superbar" ]] && exec "$HOME/.local/bin/superbar" menu "${1:-main}"

H="$HOME/.config/hypr"
TERM_CMD="xdg-terminal-exec"

pick() { # pick <prompt> <lines...>
    local prompt="$1"; shift
    printf '%s\n' "$@" | fuzzel --dmenu --prompt "$prompt  " --lines "$#" --width 30
}

float_term() { "$TERM_CMD" --class floating-term -e "$@" & }

menu_main() {
    case "$(pick "Go" \
        "󰚩  Quake AI" "󰀻  Apps" "  Capture" "󰔡  Toggle" "  Style" "  Setup" "  About" "  System")" in
        *Quake*)   qs ipc call ai toggle ;;
        *Apps*)    fuzzel ;;
        *Capture*) menu_capture ;;
        *Toggle*)  menu_toggle ;;
        *Style*)   menu_style ;;
        *Setup*)   menu_setup ;;
        *About*)   float_term bash -c 'fastfetch 2>/dev/null || hyprctl version; read -n1 -rsp "Press any key"' ;;
        *System*)  menu_system ;;
    esac
}

menu_capture() {
    case "$(pick "Capture" "  Region" "  Window" "󰍹  Screen" "󰈋  Color picker")" in
        *Region*) ~/.local/bin/superbar capture region ;;
        *Window*) ~/.local/bin/superbar capture window ;;
        *Screen*) ~/.local/bin/superbar capture screen ;;
        *Color*)  sleep 0.2; hyprpicker -a ;;
    esac
}

menu_toggle() {
    case "$(pick "Toggle" "󰚩  Quake AI console" "󰀻  Launchpad App Grid" "󰘔  Dock visibility" "󰕰  Workspace layout" "󰒲  Idle / stay awake" "󰍜  Top bar" "  Gaps" "󰹑  Float active window")" in
        *Quake*)     qs ipc call ai toggle ;;
        *Launchpad*) qs ipc call dock toggleApps ;;
        *Dock*)      qs ipc call dock toggle ;;
        *Workspace*) ~/.local/bin/superbar tiling cycle ;;
        *Idle*)      ~/.local/bin/superlock idle cycle ;;
        *bar*)       qs ipc call bar toggle ;;
        *Gaps*)      ~/.local/bin/superbar gaps toggle ;;
        *Float*)     hyprctl dispatch togglefloating >/dev/null ;;
    esac
}

menu_style() {
    case "$(pick "Style" "Next 16-bit color" "Toggle dark / light mode" "Pick 16-bit theme" "Edit look & feel")" in
        *Next*)   ~/.local/bin/supertheme next ;;
        *Toggle*) ~/.local/bin/supertheme toggle ;;
        *Pick*)   ~/.local/bin/supertheme pick ;;
        *Edit*)   float_term "${EDITOR:-nano}" "$H/conf/looknfeel.conf" ;;
    esac
}

menu_setup() {
    case "$(pick "Setup" \
        "  Audio" "  Wi-Fi" "󰂯  Bluetooth" "󰍹  Monitors" "  Keybindings" \
        "  Hyprland config" "  Hypridle" "  Hyprlock" "  Quickshell bar" "  IdleScreen")" in
        *Audio*)      qs ipc call settings open system ;;
        *Wi-Fi*)      qs ipc call settings open network ;;
        *Bluetooth*)  qs ipc call settings open devices ;;
        *Monitors*)   float_term "${EDITOR:-nano}" "$H/conf/monitors.conf" ;;
        *Keybind*)    float_term "${EDITOR:-nano}" "$H/conf/bindings.conf" ;;
        *Hyprland*)   float_term "${EDITOR:-nano}" "$H/hyprland.conf" ;;
        *Hypridle*)   float_term "${EDITOR:-nano}" "$H/hypridle.conf" ;;
        *Hyprlock*)   float_term "${EDITOR:-nano}" "$H/hyprlock.conf" ;;
        *Quickshell*) float_term "${EDITOR:-nano}" "$HOME/.config/quickshell/SuperBar.qml" ;;
        *IdleScreen*) float_term idlescreen tui ;;
    esac
}

menu_system() {
    case "$(pick "System" "  Lock" "󰤄  Suspend" "󰍃  Log out" "󰜉  Restart" "󰐥  Shut down")" in
        *Lock*)     qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session ;;
        *Suspend*)  systemctl suspend ;;
        *Log*)      hyprctl dispatch exit ;;
        *Restart*)  systemctl reboot ;;
        *Shut*)     systemctl poweroff ;;
    esac
}

restart_shell() {
    [[ -x "$HOME/.local/bin/superbar" ]] && exec "$HOME/.local/bin/superbar" restart-shell
    hyprctl reload >/dev/null 2>&1 || true
    systemctl --user restart supershell.service 2>/dev/null || true
}

toggle_screenreader() {
    [[ -x "$HOME/.local/bin/supersettings" ]] && exec "$HOME/.local/bin/supersettings" apply orca toggle
    if pgrep -x orca >/dev/null; then
        pkill -x orca
        notify-send -a System -t 1500 "Screen reader off"
    else
        orca --replace >/dev/null 2>&1 &
        disown
        notify-send -a System -t 1500 "Screen reader on"
    fi
}

case "${1:-main}" in
    main)                menu_main ;;
    capture)             menu_capture ;;
    toggle)              menu_toggle ;;
    style)               menu_style ;;
    setup)               menu_setup ;;
    system)              menu_system ;;
    restart-shell)       restart_shell ;;
    toggle-screenreader) toggle_screenreader ;;
    *)                   menu_main ;;
esac
