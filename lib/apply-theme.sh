#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# apply-theme.sh — SuperFedora 16-Bit Theme Engine (8 Jewel Colors x Dark/Light)
# ==============================================================================
# Usage:
#   sf theme                         Show active theme & available palettes
#   sf theme set <color> [dark|light] Apply a specific 16-bit color and mode
#   sf theme next | prev             Cycle through the 8 16-bit jewel colors
#   sf theme toggle                  Flip between dark and light variations
#   sf theme pick                    Interactive Fuzzel 16-bit theme selector
#   sf theme reload                  Re-apply saved theme from state file
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
STATE_FILE="$STATE_DIR/theme.env"
COLORS=("01-super-blue" "02-metroid-violet" "03-super-ruby" "04-emerald-green" "05-star-gold" "06-electric-cyan" "07-flame-orange" "08-neon-coral")

resolve_color() {
    case "${1,,}" in
        1|01|blue|super-blue|01-super-blue)                  echo "01-super-blue" ;;
        2|02|violet|purple|metroid-violet|02-metroid-violet) echo "02-metroid-violet" ;;
        3|03|ruby|red|super-ruby|03-super-ruby)              echo "03-super-ruby" ;;
        4|04|emerald|green|emerald-green|04-emerald-green)   echo "04-emerald-green" ;;
        5|05|gold|yellow|star-gold|05-star-gold)             echo "05-star-gold" ;;
        6|06|cyan|electric-cyan|06-electric-cyan)            echo "06-electric-cyan" ;;
        7|07|orange|flame-orange|07-flame-orange)            echo "07-flame-orange" ;;
        8|08|coral|neon-coral|08-neon-coral)                 echo "08-neon-coral" ;;
        *) return 1 ;;
    esac
}

palette_tokens() {
    case "$1" in
        01-super-blue)     NAME="Super Blue";     D_ACC="7aa2f7"; D_HOT="bcd3ff"; L_ACC="2554a3"; L_HOT="3c6eb4"; TUI_C="blue" ;;
        02-metroid-violet) NAME="Metroid Violet"; D_ACC="bb9af7"; D_HOT="decbff"; L_ACC="6b38b8"; L_HOT="8b5cf6"; TUI_C="magenta" ;;
        03-super-ruby)     NAME="Super Ruby";     D_ACC="f7768e"; D_HOT="ffbac7"; L_ACC="b91c3c"; L_HOT="e11d48"; TUI_C="red" ;;
        04-emerald-green)  NAME="Emerald Green";  D_ACC="9ece6a"; D_HOT="cbf0a3"; L_ACC="2d7a31"; L_HOT="16a34a"; TUI_C="green" ;;
        05-star-gold)      NAME="Star Gold";      D_ACC="e0af68"; D_HOT="ffdf9e"; L_ACC="946210"; L_HOT="ca8a04"; TUI_C="yellow" ;;
        06-electric-cyan)  NAME="Electric Cyan";  D_ACC="7dcfff"; D_HOT="bfeaff"; L_ACC="0369a1"; L_HOT="0284c7"; TUI_C="cyan" ;;
        07-flame-orange)   NAME="Flame Orange";   D_ACC="ff9e64"; D_HOT="ffc9a6"; L_ACC="b84309"; L_HOT="ea580c"; TUI_C="lightred" ;;
        08-neon-coral)     NAME="Neon Coral";     D_ACC="f43f5e"; D_HOT="ff99ac"; L_ACC="9f1239"; L_HOT="be123c"; TUI_C="lightmagenta" ;;
    esac
    if [[ "$2" == "light" ]]; then
        ACCENT="$L_ACC"; HOT="$L_HOT"; BG="e6e8f0"; BG_ALT="d8dae5"; BG_HOV="cfd2e0"; BORDER="9ea4bd"
        FG="1a1b26"; FG_DIM="343b58"; MUTED="636a8a"; SEL_BG="c5cae0"
        LOCK_FG="26, 27, 38"; LOCK_DIM="52, 59, 88"; LOCK_IN="230, 232, 240"
        KITTY_BG="#e6e8f0"; KITTY_FG="#1a1b26"; KITTY_C0="#d8dae5"; KITTY_C7="#1a1b26"; KITTY_C8="#636a8a"; KITTY_C15="#07080b"
        PORTAL_SCHEME="prefer-light"; TUI_TEXT="black"; TUI_BG="white"
    else
        ACCENT="$D_ACC"; HOT="$D_HOT"; BG="1a1b26"; BG_ALT="24283b"; BG_HOV="292e42"; BORDER="414868"
        FG="c0caf5"; FG_DIM="a9b1d6"; MUTED="565f89"; SEL_BG="283457"
        LOCK_FG="205, 214, 244"; LOCK_DIM="166, 173, 200"; LOCK_IN="26, 27, 38"
        KITTY_BG="#1a1b26"; KITTY_FG="#c0caf5"; KITTY_C0="#1a1b26"; KITTY_C7="#c0caf5"; KITTY_C8="#565f89"; KITTY_C15="#ffffff"
        PORTAL_SCHEME="prefer-dark"; TUI_TEXT="white"; TUI_BG="black"
    fi
}

load_state() {
    THEME_COLOR="01-super-blue"; THEME_MODE="dark"
    # shellcheck disable=SC1090
    [[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
    THEME_COLOR="$(resolve_color "${THEME_COLOR:-01-super-blue}" || echo "01-super-blue")"
    [[ "${THEME_MODE:-dark}" == "light" ]] || THEME_MODE="dark"
}

write_lock_shape() {
    printf 'shape {\n    monitor =\n    size = %s\n    color = rgba(%s, %s)\n    rounding = %s\n    border_size = 2\n    border_color = rgb(%s)\n    position = %s\n    halign = %s\n    valign = %s\n}\n' "$1" "$LOCK_IN" "$2" "$3" "$ACCENT" "$4" "$5" "$6"
}

write_lock_lbl() {
    printf 'label {\n    monitor =\n    text = %s\n    color = %s\n    font_size = %s\n    font_family = JetBrainsMono Nerd Font\n    position = %s\n    halign = %s\n    valign = %s\n%s}\n' "$1" "$2" "$3" "$4" "$5" "$6" "${7:-}"
}

apply_all() {
    local color="$1" mode="$2"
    palette_tokens "$color" "$mode"
    mkdir -p "$STATE_DIR" "$HOME/.config/hypr/conf" "$HOME/.config/quickshell" "$HOME/.config/fuzzel" "$HOME/.config/kitty" "$HOME/.config/idlescreen"
    printf 'THEME_COLOR="%s"\nTHEME_MODE="%s"\n' "$color" "$mode" > "$STATE_FILE"

    # shellcheck disable=SC2088
    local wall_rel="~/Pictures/Wallpapers/$mode/$color.png"
    local wall_abs="$HOME/Pictures/Wallpapers/$mode/$color.png"

    # 1. Desktop Wallpaper (hyprpaper)
    printf 'wallpaper {\n    monitor =\n    path = %s\n    fit_mode = cover\n}\n\nsplash = false\n' "$wall_rel" > "$HOME/.config/hypr/hyprpaper.conf"
    echo "$wall_abs" > "$HOME/.config/hypr/.current-wallpaper"
    if command -v hyprctl >/dev/null 2>&1 && [[ -f "$wall_abs" ]]; then
        hyprctl hyprpaper unload all >/dev/null 2>&1 || true
        hyprctl hyprpaper preload "$wall_abs" >/dev/null 2>&1 || true
        hyprctl hyprpaper wallpaper ",$wall_abs" >/dev/null 2>&1 || true
    fi

    # 2. Lock Screen (hyprlock — clock-free 4K 16-bit SUPER FEDORA Hero art + bottom-docked auth card)
    {
        printf '# Hyprlock Configuration — SuperFedora 16-Bit Theme (%s / %s)\ngeneral {\n    hide_cursor = false\n    ignore_empty_input = true\n    immediate_render = true\n    fail_timeout = 1200\n}\nanimations {\n    enabled = false\n}\nbackground {\n    monitor =\n    path = %s\n    blur_passes = 0\n    blur_size = 0\n}\n' "$NAME" "$mode" "$wall_rel"
        write_lock_shape "460, 210" "0.92" "6" "0, 28" "center" "bottom"
        printf 'image {\n    monitor =\n    path = ~/Pictures/Wallpapers/avatar.jpg\n    size = 64\n    rounding = 6\n    border_size = 2\n    border_color = rgb(%s)\n    position = 0, 156\n    halign = center\n    valign = bottom\n}\n' "$HOT"
        write_lock_lbl "<b>\$USER</b>  ·  <span foreground=\"#$ACCENT\">[SESSION LOCKED]</span>" "rgba($LOCK_FG, 1.0)" "14" "0, 124" "center" "bottom"
        printf 'input-field {\n    monitor =\n    size = 340, 44\n    outline_thickness = 2\n    rounding = 4\n    dots_size = 0.26\n    dots_spacing = 0.18\n    dots_center = true\n    fade_on_empty = false\n    font_color = rgb(%s)\n    inner_color = rgba(%s, 0.98)\n    outer_color = rgb(%s)\n    check_color = rgb(9ece6a)\n    fail_color = rgb(f7768e)\n    fail_text = <b>AUTH FAILED ($ATTEMPTS) — TRY AGAIN</b>\n    capslock_color = rgb(e0af68)\n    placeholder_text = <i>Type password to unlock...</i>\n    position = 0, 70\n    halign = center\n    valign = bottom\n}\n' "$LOCK_FG" "$LOCK_IN" "$ACCENT"
        write_lock_lbl "󰤄 Suspend"    "rgba($LOCK_DIM, 1.0)" "12" "-140, 38" "center" "bottom" $'    onclick = systemctl suspend\n'
        write_lock_lbl "󰍹 Screen Off" "rgba($LOCK_DIM, 1.0)" "12" "-45, 38"  "center" "bottom" $'    onclick = hyprctl dispatch dpms off\n'
        write_lock_lbl "󰜉 Restart"    "rgba($LOCK_DIM, 1.0)" "12" "55, 38"   "center" "bottom" $'    onclick = systemctl reboot\n'
        write_lock_lbl "󰐥 Power Off"  "rgb(f7768e)"          "12" "145, 38"  "center" "bottom" $'    onclick = systemctl poweroff\n'
    } > "$HOME/.config/hypr/hyprlock.conf"

    # 3. Hyprland Borders & Groupbar (looknfeel.conf + live hyprctl)
    [[ -f "$HOME/.config/hypr/conf/looknfeel.conf" ]] && sed -i \
        -e "s/col\.active_border = .*/col.active_border = rgb($ACCENT)/" \
        -e "s/col\.inactive_border = .*/col.inactive_border = rgba(${BORDER}aa)/" \
        -e "s/col\.border_active = .*/col.border_active = rgb($ACCENT)/" \
        -e "s/col\.border_inactive = .*/col.border_inactive = rgba(${BORDER}aa)/" \
        -e "s/text_color = .*/text_color = rgb($FG)/" \
        -e "s/col\.active = .*/col.active = rgba(${ACCENT}cc)/" \
        -e "s/col\.inactive = .*/col.inactive = rgba(${BG_ALT}cc)/" \
        "$HOME/.config/hypr/conf/looknfeel.conf"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl keyword general:col.active_border "rgb($ACCENT)" >/dev/null 2>&1 || true
        hyprctl keyword general:col.inactive_border "rgba(${BORDER}aa)" >/dev/null 2>&1 || true
    fi

    # 4. Quickshell Top Bar, OSD, Notifications & Calendar (live IPC update, zero reload popup)
    printf '{"bg":"#%s","bgAlt":"#%s","bgHover":"#%s","border":"#%s","fg":"#%s","fgDim":"#%s","muted":"#%s","blue":"#%s","cyan":"#%s"}\n' \
        "$BG" "$BG_ALT" "$BG_HOV" "$BORDER" "$FG" "$FG_DIM" "$MUTED" "$ACCENT" "$HOT" > "$STATE_DIR/quickshell-theme.json"
    command -v qs >/dev/null 2>&1 && qs ipc call theme reload >/dev/null 2>&1 || true

    # 5. Fuzzel Launcher & Menus (fuzzel.ini)
    printf '# Fuzzel Configuration — SuperFedora 16-Bit Theme (%s / %s)\nfont=JetBrainsMono Nerd Font:size=12\ndpi-aware=auto\nprompt="> "\nicon-theme=Adwaita\nterminal=kitty -e\nwidth=36\nlines=10\nhorizontal-pad=24\nvertical-pad=16\ninner-pad=10\n\n[colors]\nbackground=%sf2\ntext=%sff\nmatch=%sff\nselection=%sff\nselection-text=%sff\nselection-match=%sff\nborder=%sff\n\n[border]\nwidth=2\nradius=0\n' \
        "$NAME" "$mode" "$BG" "$FG" "$ACCENT" "$SEL_BG" "$FG" "$HOT" "$ACCENT" > "$HOME/.config/fuzzel/fuzzel.ini"

    # 6. Kitty Terminal (kitty.conf + live SIGUSR1 reload)
    if [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
        sed -i \
            -e "s/^foreground .*/foreground            $KITTY_FG/" \
            -e "s/^background .*/background            $KITTY_BG/" \
            -e "s/^selection_background .*/selection_background   #$ACCENT/" \
            -e "s/^cursor  .*/cursor                #$ACCENT/" \
            -e "s/^cursor_text_color .*/cursor_text_color     $KITTY_BG/" \
            -e "s/^color0 .*/color0                $KITTY_C0/" \
            -e "s/^color7 .*/color7                $KITTY_C7/" \
            -e "s/^color8 .*/color8                $KITTY_C8/" \
            -e "s/^color15 .*/color15               $KITTY_C15/" \
            "$HOME/.config/kitty/kitty.conf"
        pkill -USR1 -x kitty 2>/dev/null || true
    fi

    # 7. IdleScreen configuration
    printf '[general]\nidle_timeout_secs = 120\nprimary_output = ""\n\n[saver]\nactive = "superfedora"\n\n[saver.ascii]\nmode = "superfedora"\ntargets = ["superfedora"]\ntext = ""\nfps = 0\ndwell_secs = 5.0\ndissolve_duration_secs = 0.699999988079071\n' > "$HOME/.config/idlescreen/config.toml"

    # 8. GTK / XDG Desktop Portal color-scheme
    command -v gsettings >/dev/null 2>&1 && gsettings set org.gnome.desktop.interface color-scheme "$PORTAL_SCHEME" 2>/dev/null || true

    # 9. Login Greeter (greetd + tuigreet ANSI theme when /etc/greetd/config.toml is writable)
    local tui_theme="border=$TUI_C;title=$TUI_C;prompt=$TUI_C;time=$TUI_TEXT;action=$TUI_C;button=$TUI_C;container=$TUI_BG;input=$TUI_TEXT"
    if [[ -w /etc/greetd/config.toml ]]; then
        printf '# SuperFedora login screen: greetd + tuigreet on tty1.\n# Hyprland is started through uwsm, which runs it as a systemd user session\n# (graphical-session.target, portals and user services come up properly).\n# Managed by SuperFedora (system/etc/greetd/config.toml).\n\n[terminal]\nvt = 1\n\n[default_session]\ncommand = "tuigreet --time --asterisks --remember --remember-session --theme '\''%s'\'' --sessions /usr/share/wayland-sessions --cmd '\''uwsm start -e -D Hyprland hyprland.desktop'\'' --greeting '\''SUPER FEDORA'\''"\nuser = "greetd"\n' "$tui_theme" > /etc/greetd/config.toml
    fi
    printf '[OK] Active 16-bit theme: %s (%s mode)\n' "$NAME" "$mode"
}

load_state
case "${1:-status}" in
    set)
        c="$(resolve_color "${2:-$THEME_COLOR}")" || { echo "unknown color: ${2:-}" >&2; exit 2; }
        m="${3:-$THEME_MODE}"; [[ "$m" == "light" || "$m" == "dark" ]] || { echo "mode must be dark or light" >&2; exit 2; }
        apply_all "$c" "$m" ;;
    next|prev)
        idx=0; for i in "${!COLORS[@]}"; do [[ "${COLORS[$i]}" == "$THEME_COLOR" ]] && idx=$i; done
        step=1; [[ "$1" == "prev" ]] && step=7
        apply_all "${COLORS[$(( (idx + step) % 8 ))]}" "$THEME_MODE" ;;
    toggle)
        other="light"; [[ "$THEME_MODE" == "light" ]] && other="dark"
        apply_all "$THEME_COLOR" "$other" ;;
    reload)
        apply_all "$THEME_COLOR" "$THEME_MODE" >/dev/null ;;
    pick)
        other="light"; [[ "$THEME_MODE" == "light" ]] && other="dark"
        choice="$(printf '%s\n' "[*] Toggle mode ($THEME_MODE -> $other)" "${COLORS[@]}" | fuzzel --dmenu --prompt "16-Bit Theme > " --lines 9 --width 36)" || exit 0
        if [[ "$choice" == "[*] Toggle"* ]]; then apply_all "$THEME_COLOR" "$other"; else apply_all "$choice" "$THEME_MODE"; fi ;;
    status|list)
        palette_tokens "$THEME_COLOR" "$THEME_MODE"
        printf 'Active Theme : %s (%s) [%s]\nPalettes     : %s\n' "$NAME" "$THEME_COLOR" "$THEME_MODE" "${COLORS[*]}" ;;
    *)
        sed -n '6,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
