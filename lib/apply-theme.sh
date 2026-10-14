#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# apply-theme.sh — SuperFedora 16-Bit Theme Engine (Day/Night x Square/Rounded)
# ==============================================================================
# Usage:
#   sf theme                                  Show active theme & available palettes
#   sf theme <name> [--mode night|day|toggle] [--corners square|rounded|toggle]
#   sf theme set <color> [night|day] [square|rounded] Apply color, mode & corners
#   sf theme next | prev                      Cycle through 16-bit palettes
#   sf theme toggle | mode [night|day|toggle] Flip between night (dark) & day (light)
#   sf theme corners [square|rounded|toggle]  Swap between 90-degree square & rounded edges
#   sf theme nightlight [on|off|toggle]       Toggle eye-care warm night light
#   sf theme pick                             Interactive Fuzzel 16-bit theme selector
#   sf theme reload                           Re-apply saved theme from state file
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
STATE_FILE="$STATE_DIR/theme.env"
COLORS=("01-super-blue" "02-metroid-violet" "03-super-ruby" "04-emerald-green" "05-star-gold" "06-electric-cyan" "07-flame-orange" "08-neon-coral" "snes" "tokyo-night" "catppuccin" "nord")

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
        snes|16bit|super-nintendo)                           echo "snes" ;;
        tokyo|tokyo-night|tokyonight)                        echo "tokyo-night" ;;
        catppuccin|mocha|latte)                              echo "catppuccin" ;;
        nord|arctic)                                         echo "nord" ;;
        *) return 1 ;;
    esac
}

resolve_mode() {
    case "${1,,}" in
        day|light)  echo "light" ;;
        night|dark) echo "dark" ;;
        toggle)     [[ "${THEME_MODE:-dark}" == "light" ]] && echo "dark" || echo "light" ;;
        *) return 1 ;;
    esac
}

palette_tokens() {
    WALL_KEY="$1"
    case "$1" in
        01-super-blue)     NAME="Super Blue";     D_ACC="7aa2f7"; D_HOT="bcd3ff"; L_ACC="2554a3"; L_HOT="3c6eb4"; TUI_C="blue" ;;
        02-metroid-violet) NAME="Metroid Violet"; D_ACC="bb9af7"; D_HOT="decbff"; L_ACC="6b38b8"; L_HOT="8b5cf6"; TUI_C="magenta" ;;
        03-super-ruby)     NAME="Super Ruby";     D_ACC="f7768e"; D_HOT="ffbac7"; L_ACC="b91c3c"; L_HOT="e11d48"; TUI_C="red" ;;
        04-emerald-green)  NAME="Emerald Green";  D_ACC="9ece6a"; D_HOT="cbf0a3"; L_ACC="2d7a31"; L_HOT="16a34a"; TUI_C="green" ;;
        05-star-gold)      NAME="Star Gold";      D_ACC="e0af68"; D_HOT="ffdf9e"; L_ACC="946210"; L_HOT="ca8a04"; TUI_C="yellow" ;;
        06-electric-cyan)  NAME="Electric Cyan";  D_ACC="7dcfff"; D_HOT="bfeaff"; L_ACC="0369a1"; L_HOT="0284c7"; TUI_C="cyan" ;;
        07-flame-orange)   NAME="Flame Orange";   D_ACC="ff9e64"; D_HOT="ffc9a6"; L_ACC="b84309"; L_HOT="ea580c"; TUI_C="lightred" ;;
        08-neon-coral)     NAME="Neon Coral";     D_ACC="f43f5e"; D_HOT="ff99ac"; L_ACC="9f1239"; L_HOT="be123c"; TUI_C="lightmagenta" ;;
        snes)              NAME="SNES 16-Bit";    WALL_KEY="02-metroid-violet"; D_ACC="b48ead"; D_HOT="e0af68"; L_ACC="6b38b8"; L_HOT="b84309"; TUI_C="magenta" ;;
        tokyo-night)       NAME="Tokyo Night";    WALL_KEY="01-super-blue";     D_ACC="7aa2f7"; D_HOT="7dcfff"; L_ACC="2e7de9"; L_HOT="007197"; TUI_C="blue" ;;
        catppuccin)        NAME="Catppuccin";     WALL_KEY="08-neon-coral";     D_ACC="cba6f7"; D_HOT="f5c2e7"; L_ACC="8839ef"; L_HOT="ea76cb"; TUI_C="magenta" ;;
        nord)              NAME="Nord";           WALL_KEY="06-electric-cyan";  D_ACC="88c0d0"; D_HOT="81a1c1"; L_ACC="5e81ac"; L_HOT="4c566a"; TUI_C="cyan" ;;
    esac
    if [[ "$2" == "light" ]]; then
        ACCENT="$L_ACC"; HOT="$L_HOT"; BG="e6e8f0"; BG_ALT="d8dae5"; BG_HOV="cfd2e0"; BORDER="9ea4bd"
        FG="1a1b26"; FG_DIM="343b58"; MUTED="636a8a"; SEL_BG="c5cae0"
        LOCK_FG="26, 27, 38"; LOCK_DIM="52, 59, 88"; LOCK_IN="230, 232, 240"
        KITTY_BG="#e6e8f0"; KITTY_FG="#1a1b26"; KITTY_C0="#d8dae5"; KITTY_C7="#1a1b26"; KITTY_C8="#636a8a"; KITTY_C15="#07080b"
        PORTAL_SCHEME="prefer-light"; GTK_THEME="Adwaita"; TUI_TEXT="black"; TUI_BG="white"
    else
        ACCENT="$D_ACC"; HOT="$D_HOT"; BG="1a1b26"; BG_ALT="24283b"; BG_HOV="292e42"; BORDER="414868"
        FG="c0caf5"; FG_DIM="a9b1d6"; MUTED="565f89"; SEL_BG="283457"
        LOCK_FG="205, 214, 244"; LOCK_DIM="166, 173, 200"; LOCK_IN="26, 27, 38"
        KITTY_BG="#1a1b26"; KITTY_FG="#c0caf5"; KITTY_C0="#1a1b26"; KITTY_C7="#c0caf5"; KITTY_C8="#565f89"; KITTY_C15="#ffffff"
        PORTAL_SCHEME="prefer-dark"; GTK_THEME="Adwaita-dark"; TUI_TEXT="white"; TUI_BG="black"
    fi
}

load_state() {
    THEME_COLOR="01-super-blue"; THEME_MODE="dark"; THEME_CORNERS="square"; THEME_NIGHTLIGHT="off"
    # shellcheck disable=SC1090
    [[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
    THEME_COLOR="$(resolve_color "${THEME_COLOR:-01-super-blue}" || echo "01-super-blue")"
    [[ "${THEME_MODE:-dark}" == "light" ]] || THEME_MODE="dark"
    [[ "${THEME_CORNERS:-square}" == "rounded" ]] || THEME_CORNERS="square"
    [[ "${THEME_NIGHTLIGHT:-off}" == "on" ]] || THEME_NIGHTLIGHT="off"
}

write_lock_lbl() {
    printf 'label {\n    monitor =\n    text = %s\n    color = %s\n    font_size = %s\n    font_family = JetBrainsMono Nerd Font\n    position = %s\n    halign = %s\n    valign = %s\n%s}\n' "$1" "$2" "$3" "$4" "$5" "$6" "${7:-}"
}

apply_all() {
    local color="$1" mode="$2" corners="${3:-$THEME_CORNERS}" nl="${4:-$THEME_NIGHTLIGHT}"
    [[ "$corners" == "rounded" ]] || corners="square"
    [[ "$nl" == "on" ]] || nl="off"
    palette_tokens "$color" "$mode"
    mkdir -p "$STATE_DIR" "$HOME/.config/hypr/conf" "$HOME/.config/quickshell" "$HOME/.config/fuzzel" "$HOME/.config/kitty" "$HOME/.config/idlescreen"
    printf 'THEME_COLOR="%s"\nTHEME_MODE="%s"\nTHEME_CORNERS="%s"\nTHEME_NIGHTLIGHT="%s"\n' "$color" "$mode" "$corners" "$nl" > "$STATE_FILE"
    echo "$corners" > "$STATE_DIR/theme-corners"

    local lock_round="0" hypr_round="0" qs_rad="0" qs_rad_sm="0" fuzzel_rad="0"
    [[ "$corners" == "rounded" ]] && { lock_round="10"; hypr_round="10"; qs_rad="10"; qs_rad_sm="6"; fuzzel_rad="10"; }

    # shellcheck disable=SC2088
    local wall_rel="~/Pictures/Wallpapers/$mode/$WALL_KEY.png"
    local wall_abs="$HOME/Pictures/Wallpapers/$mode/$WALL_KEY.png"

    # 1. Desktop Wallpaper (hyprpaper)
    printf 'wallpaper {\n    monitor =\n    path = %s\n    fit_mode = cover\n}\n\nsplash = false\n' "$wall_rel" > "$HOME/.config/hypr/hyprpaper.conf"
    echo "$wall_abs" > "$HOME/.config/hypr/.current-wallpaper"
    if command -v hyprctl >/dev/null 2>&1 && [[ -f "$wall_abs" ]]; then
        hyprctl hyprpaper unload all >/dev/null 2>&1 || true
        hyprctl hyprpaper preload "$wall_abs" >/dev/null 2>&1 || true
        hyprctl hyprpaper wallpaper ",$wall_abs" >/dev/null 2>&1 || true
    fi

    # 2. Lock Screen (hyprlock)
    {
        printf '# Hyprlock Configuration — SuperFedora 16-Bit Theme (%s / %s / %s)\ngeneral {\n    hide_cursor = false\n    ignore_empty_input = true\n    immediate_render = true\n    fail_timeout = 1200\n}\nauth {\n    pam {\n        enabled = true\n        module = password-auth\n    }\n    fingerprint {\n        enabled = true\n    }\n}\nanimations {\n    enabled = false\n}\nbackground {\n    monitor =\n    path = %s\n    blur_passes = 0\n    blur_size = 0\n}\n' "$NAME" "$mode" "$corners" "$wall_rel"
        write_lock_lbl "<b>󰍹 Screen Off</b>" "rgba($LOCK_FG, 1.0)" "12" "-390, -24" "right" "top" $'    onclick = hyprctl dispatch dpms off\n'
        write_lock_lbl "<b>󰤄 Suspend</b>"    "rgba($LOCK_FG, 1.0)" "12" "-276, -24" "right" "top" $'    onclick = systemctl suspend\n'
        write_lock_lbl "<b>󰜉 Restart</b>"    "rgba($LOCK_FG, 1.0)" "12" "-162, -24" "right" "top" $'    onclick = systemctl reboot\n'
        write_lock_lbl "<b>󰐥 Power Off</b>"  "rgb(f7768e)"         "12" "-28, -24"  "right" "top" $'    onclick = systemctl poweroff\n'
        write_lock_lbl "cmd[update:1000] ~/.local/share/superfedora/lib/session-ctl.sh status" "rgb($ACCENT)" "12" "-28, 56" "right" "bottom" $'    onclick = ~/.local/share/superfedora/lib/session-ctl.sh next\n'
        write_lock_lbl "<b>󰍃 Switch DE / Log Out</b>" "rgba($LOCK_DIM, 1.0)" "12" "-28, 28" "right" "bottom" $'    onclick = ~/.local/share/superfedora/lib/session-ctl.sh switch\n'
        printf 'image {\n    monitor =\n    path = ~/Pictures/Wallpapers/avatar.jpg\n    size = 88\n    rounding = %s\n    border_size = 2\n    border_color = rgb(%s)\n    position = 0, 148\n    halign = center\n    valign = bottom\n}\n' "$lock_round" "$ACCENT"
        write_lock_lbl "<b>\$USER</b>" "rgba($LOCK_FG, 1.0)" "16" "0, 108" "center" "bottom"
        printf 'input-field {\n    monitor =\n    size = 290, 44\n    outline_thickness = 2\n    rounding = %s\n    dots_size = 0.26\n    dots_spacing = 0.20\n    dots_center = true\n    fade_on_empty = false\n    font_color = rgb(%s)\n    inner_color = rgba(%s, 0.94)\n    outer_color = rgb(%s)\n    check_color = rgb(9ece6a)\n    fail_color = rgb(f7768e)\n    fail_text = <b>Incorrect password ($ATTEMPTS)</b>\n    capslock_color = rgb(e0af68)\n    placeholder_text = Password\n    position = 0, 46\n    halign = center\n    valign = bottom\n}\n' "$lock_round" "$LOCK_FG" "$LOCK_IN" "$ACCENT"
    } > "$HOME/.config/hypr/hyprlock.conf"

    # 3. Hyprland Borders, Rounding & Groupbar
    [[ -f "$HOME/.config/hypr/conf/looknfeel.conf" ]] && sed -i \
        -e "s/col\.active_border = .*/col.active_border = rgb($ACCENT)/" \
        -e "s/col\.inactive_border = .*/col.inactive_border = rgba(${BORDER}aa)/" \
        -e "s/col\.border_active = .*/col.border_active = rgb($ACCENT)/" \
        -e "s/col\.border_inactive = .*/col.border_inactive = rgba(${BORDER}aa)/" \
        -e "s/text_color = .*/text_color = rgb($FG)/" \
        -e "s/col\.active = .*/col.active = rgba(${ACCENT}cc)/" \
        -e "s/col\.inactive = .*/col.inactive = rgba(${BG_ALT}cc)/" \
        -e "s/rounding = .*/rounding = $hypr_round/" "$HOME/.config/hypr/conf/looknfeel.conf"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl keyword general:col.active_border "rgb($ACCENT)" >/dev/null 2>&1 || true
        hyprctl keyword general:col.inactive_border "rgba(${BORDER}aa)" >/dev/null 2>&1 || true
        hyprctl keyword decoration:rounding "$hypr_round" >/dev/null 2>&1 || true
        hyprctl keyword misc:allow_session_lock_restore 1 >/dev/null 2>&1 || true
    fi

    # 4. Quickshell Top Bar, SuperDeck, Docks, OSD & Notifications (live IPC update)
    local nl_bool="false"; [[ "$nl" == "on" ]] && nl_bool="true"
    printf '{"theme":"%s","name":"%s","mode":"%s","bg":"#%s","bgAlt":"#%s","bgHover":"#%s","border":"#%s","fg":"#%s","fgDim":"#%s","muted":"#%s","blue":"#%s","cyan":"#%s","corners":"%s","nightlight":%s,"radius":%s,"radiusSm":%s}\n' \
        "$color" "$NAME" "$mode" "$BG" "$BG_ALT" "$BG_HOV" "$BORDER" "$FG" "$FG_DIM" "$MUTED" "$ACCENT" "$HOT" "$corners" "$nl_bool" "$qs_rad" "$qs_rad_sm" > "$STATE_DIR/quickshell-theme.json"
    command -v qs >/dev/null 2>&1 && qs ipc call theme reload >/dev/null 2>&1 || true

    # 5. Fuzzel, Kitty, Ghostty, Tmux & Neovim Terminal Theme Sync
    printf '# Fuzzel Configuration — SuperFedora 16-Bit Theme (%s / %s / %s)\nfont=JetBrainsMono Nerd Font:size=12\ndpi-aware=auto\nprompt="> "\nicon-theme=Adwaita\nterminal=kitty -e\nwidth=36\nlines=10\nhorizontal-pad=24\nvertical-pad=16\ninner-pad=10\n\n[colors]\nbackground=%sf2\ntext=%sff\nmatch=%sff\nselection=%sff\nselection-text=%sff\nselection-match=%sff\nborder=%sff\n\n[border]\nwidth=2\nradius=%s\n' \
        "$NAME" "$mode" "$corners" "$BG" "$FG" "$ACCENT" "$SEL_BG" "$FG" "$HOT" "$ACCENT" "$fuzzel_rad" > "$HOME/.config/fuzzel/fuzzel.ini"
    if [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
        sed -i -e "s/^foreground .*/foreground            $KITTY_FG/" -e "s/^background .*/background            $KITTY_BG/" \
            -e "s/^selection_background .*/selection_background   #$ACCENT/" -e "s/^cursor  .*/cursor                #$ACCENT/" \
            -e "s/^cursor_text_color .*/cursor_text_color     $KITTY_BG/" -e "s/^color0 .*/color0                $KITTY_C0/" \
            -e "s/^color7 .*/color7                $KITTY_C7/" -e "s/^color8 .*/color8                $KITTY_C8/" \
            -e "s/^color15 .*/color15               $KITTY_C15/" "$HOME/.config/kitty/kitty.conf"
        pkill -USR1 -x kitty 2>/dev/null || true
    fi
    printf 'background = #%s\nforeground = #%s\ncursor-color = #%s\nselection-background = #%s\n' "$BG" "$FG" "$ACCENT" "$SEL_BG" > "$STATE_DIR/ghostty-theme.conf"
    printf 'set -g status-style "bg=#%s,fg=#%s"\nset -g pane-active-border-style "fg=#%s"\nset -g pane-border-style "fg=#%s"\n' "$BG_ALT" "$FG" "$ACCENT" "$BORDER" > "$STATE_DIR/tmux-theme.conf"
    command -v tmux >/dev/null 2>&1 && tmux source-file "$STATE_DIR/tmux-theme.conf" 2>/dev/null || true
    printf 'vim.o.background = "%s"\n' "$mode" > "$STATE_DIR/nvim-theme.lua"

    # 6. IdleScreen, GTK/Portal, Night Light & Greetd
    printf '[general]\nidle_timeout_secs = 120\nprimary_output = ""\n\n[saver]\nactive = "superfedora"\n\n[saver.ascii]\nmode = "superfedora"\ntargets = ["superfedora"]\ntext = ""\nfps = 0\ndwell_secs = 5.0\ndissolve_duration_secs = 0.699999988079071\n' > "$HOME/.config/idlescreen/config.toml"
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme "$PORTAL_SCHEME" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
    fi
    if [[ "$nl" == "on" ]]; then
        if ! pgrep -x wlsunset >/dev/null 2>&1 && ! pgrep -x hyprsunset >/dev/null 2>&1; then
            if command -v hyprsunset >/dev/null 2>&1; then nohup hyprsunset -t 4200 >/dev/null 2>&1 &
            elif command -v wlsunset >/dev/null 2>&1; then nohup wlsunset -t 4200 -T 6500 >/dev/null 2>&1 & fi
        fi
    else
        pkill -x wlsunset 2>/dev/null || true; pkill -x hyprsunset 2>/dev/null || true
    fi
    local tui_theme="border=$TUI_C;title=$TUI_C;prompt=$TUI_C;time=$TUI_TEXT;action=$TUI_C;button=$TUI_C;container=$TUI_BG;input=$TUI_TEXT"
    if [[ -w /etc/greetd/config.toml ]]; then
        printf '# SuperFedora login screen: greetd + tuigreet on tty1.\n[terminal]\nvt = 1\n\n[default_session]\ncommand = "tuigreet --time --asterisks --remember --remember-session --theme '\''%s'\'' --sessions /usr/share/wayland-sessions --cmd '\''uwsm start -e -D Hyprland hyprland.desktop'\'' --greeting '\''SUPER FEDORA'\''"\nuser = "greetd"\n' "$tui_theme" > /etc/greetd/config.toml
    fi
    local mode_disp="night"; [[ "$mode" == "light" ]] && mode_disp="day"
    printf '[OK] Active 16-bit theme: %s (%s/%s mode, %s corners, nightlight: %s)\n' "$NAME" "$mode_disp" "$mode" "$corners" "$nl"
}

load_state
POS_ARGS=(); OPT_MODE=""; OPT_CORNERS=""; OPT_NL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) OPT_MODE="${2:-toggle}"; shift ;; --mode=*) OPT_MODE="${1#*=}" ;;
        --corners) OPT_CORNERS="${2:-toggle}"; shift ;; --corners=*) OPT_CORNERS="${1#*=}" ;;
        --nightlight|--night-light) OPT_NL="${2:-toggle}"; shift ;; --nightlight=*|--night-light=*) OPT_NL="${1#*=}" ;;
        *) POS_ARGS+=("$1") ;;
    esac
    shift
done
set -- "${POS_ARGS[@]}"

[[ -n "$OPT_MODE" ]] && THEME_MODE="$(resolve_mode "$OPT_MODE" || { echo "invalid mode: $OPT_MODE" >&2; exit 2; })"
[[ -n "$OPT_CORNERS" ]] && { [[ "$OPT_CORNERS" == "toggle" ]] && { [[ "$THEME_CORNERS" == "rounded" ]] && THEME_CORNERS="square" || THEME_CORNERS="rounded"; } || THEME_CORNERS="$OPT_CORNERS"; }
[[ -n "$OPT_NL" ]] && { [[ "$OPT_NL" == "toggle" ]] && { [[ "$THEME_NIGHTLIGHT" == "on" ]] && THEME_NIGHTLIGHT="off" || THEME_NIGHTLIGHT="on"; } || THEME_NIGHTLIGHT="$OPT_NL"; }

CMD="${1:-status}"
if [[ $# -eq 0 && ( -n "$OPT_MODE" || -n "$OPT_CORNERS" || -n "$OPT_NL" ) ]]; then
    apply_all "$THEME_COLOR" "$THEME_MODE" "$THEME_CORNERS" "$THEME_NIGHTLIGHT"; exit 0
fi

case "$CMD" in
    set)
        c="$(resolve_color "${2:-$THEME_COLOR}")" || { echo "unknown color: ${2:-}" >&2; exit 2; }
        m="$THEME_MODE"; [[ -n "${3:-}" ]] && m="$(resolve_mode "$3")" || true
        apply_all "$c" "$m" "${4:-$THEME_CORNERS}" "$THEME_NIGHTLIGHT" ;;
    next|prev)
        idx=0; for i in "${!COLORS[@]}"; do [[ "${COLORS[$i]}" == "$THEME_COLOR" ]] && idx=$i; done
        step=1; [[ "$CMD" == "prev" ]] && step=$(( ${#COLORS[@]} - 1 ))
        apply_all "${COLORS[$(( (idx + step) % ${#COLORS[@]} ))]}" "$THEME_MODE" "$THEME_CORNERS" "$THEME_NIGHTLIGHT" ;;
    toggle|mode|day|night|light|dark)
        target="${2:-$CMD}"; [[ "$CMD" == "toggle" || "$CMD" == "mode" ]] && target="${2:-toggle}"
        m="$(resolve_mode "$target")" || { echo "mode must be night, day, dark, light, or toggle" >&2; exit 2; }
        apply_all "$THEME_COLOR" "$m" "$THEME_CORNERS" "$THEME_NIGHTLIGHT" ;;
    corners)
        target="${2:-toggle}"
        [[ "$target" == "toggle" ]] && { [[ "$THEME_CORNERS" == "rounded" ]] && target="square" || target="rounded"; }
        [[ "$target" == "rounded" || "$target" == "square" ]] || { echo "corners must be square, rounded, or toggle" >&2; exit 2; }
        apply_all "$THEME_COLOR" "$THEME_MODE" "$target" "$THEME_NIGHTLIGHT" ;;
    nightlight|night-light)
        target="${2:-toggle}"
        [[ "$target" == "toggle" ]] && { [[ "$THEME_NIGHTLIGHT" == "on" ]] && target="off" || target="on"; }
        apply_all "$THEME_COLOR" "$THEME_MODE" "$THEME_CORNERS" "$target" ;;
    reload)
        apply_all "$THEME_COLOR" "$THEME_MODE" "$THEME_CORNERS" "$THEME_NIGHTLIGHT" >/dev/null ;;
    pick)
        other_m="day"; [[ "$THEME_MODE" == "light" ]] && other_m="night"
        other_c="rounded"; [[ "$THEME_CORNERS" == "rounded" ]] && other_c="square"
        choice="$(printf '%s\n' "[*] Toggle mode ($THEME_MODE -> $other_m)" "[*] Toggle corners ($THEME_CORNERS -> $other_c)" "${COLORS[@]}" | fuzzel --dmenu --prompt "16-Bit Theme > " --lines 12 --width 42)" || exit 0
        if [[ "$choice" == "[*] Toggle mode"* ]]; then apply_all "$THEME_COLOR" "$(resolve_mode toggle)" "$THEME_CORNERS" "$THEME_NIGHTLIGHT"
        elif [[ "$choice" == "[*] Toggle corners"* ]]; then apply_all "$THEME_COLOR" "$THEME_MODE" "$other_c" "$THEME_NIGHTLIGHT"
        else apply_all "$(resolve_color "$choice")" "$THEME_MODE" "$THEME_CORNERS" "$THEME_NIGHTLIGHT"; fi ;;
    status|list)
        palette_tokens "$THEME_COLOR" "$THEME_MODE"
        printf 'Active Theme : %s (%s) [mode: %s, corners: %s, nightlight: %s]\nPalettes     : %s\n' "$NAME" "$THEME_COLOR" "$THEME_MODE" "$THEME_CORNERS" "$THEME_NIGHTLIGHT" "${COLORS[*]}" ;;
    *)
        if c="$(resolve_color "$CMD" 2>/dev/null)"; then apply_all "$c" "$THEME_MODE" "$THEME_CORNERS" "$THEME_NIGHTLIGHT"
        else sed -n '6,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; fi ;;
esac
