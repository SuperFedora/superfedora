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
COLORS=("01-crimson" "02-scarlet" "03-ember" "04-amber" "05-topaz" "06-citrine" "07-peridot" "08-emerald" "09-verdant" "10-lagoon" "11-glacier" "12-cobalt" "13-indigo" "14-violet" "15-orchid" "16-fuchsia")

resolve_color() {
    case "${1,,}" in
        1|01|crimson|01-crimson|ruby|red|03-super-ruby)           echo "01-crimson" ;; 2|02|scarlet|02-scarlet)                     echo "02-scarlet" ;;
        3|03|ember|03-ember)                                      echo "03-ember" ;;   4|04|amber|04-amber|orange|07-flame-orange)  echo "04-amber" ;;
        5|05|topaz|05-topaz|gold|05-star-gold)                    echo "05-topaz" ;;   6|06|citrine|06-citrine|yellow)              echo "06-citrine" ;;
        7|07|peridot|07-peridot|lime)                             echo "07-peridot" ;; 8|08|emerald|08-emerald|green|04-emerald-green) echo "08-emerald" ;;
        9|09|verdant|09-verdant|mint)                             echo "09-verdant" ;; 10|lagoon|10-lagoon|teal)                    echo "10-lagoon" ;;
        11|glacier|11-glacier|cyan|06-electric-cyan|nord)         echo "11-glacier" ;; 12|cobalt|12-cobalt|blue|01-super-blue|tokyo|tokyo-night) echo "12-cobalt" ;;
        13|indigo|13-indigo)                                      echo "13-indigo" ;;  14|violet|14-violet|purple|02-metroid-violet|snes) echo "14-violet" ;;
        15|orchid|15-orchid|catppuccin)                           echo "15-orchid" ;;  16|fuchsia|16-fuchsia|coral|magenta|08-neon-coral) echo "16-fuchsia" ;;
        *) return 1 ;;
    esac
}

resolve_mode() {
    case "${1,,}" in day|light) echo "light" ;; night|dark) echo "dark" ;; toggle) [[ "${THEME_MODE:-dark}" == "light" ]] && echo "dark" || echo "light" ;; *) return 1 ;; esac
}

palette_tokens() {
    case "$1" in
        01-crimson) NAME="Crimson"; WALL_KEY="03-super-ruby";     D_ACC="f7768e"; D_HOT="ffbac7"; L_ACC="b91c3c"; L_HOT="e11d48"; TUI_C="red" ;;
        02-scarlet) NAME="Scarlet"; WALL_KEY="08-neon-coral";     D_ACC="ff5a5f"; D_HOT="ff8fa3"; L_ACC="c81e32"; L_HOT="e11d48"; TUI_C="lightred" ;;
        03-ember)   NAME="Ember";   WALL_KEY="07-flame-orange";   D_ACC="ff7b54"; D_HOT="ffb26b"; L_ACC="c2410c"; L_HOT="ea580c"; TUI_C="lightred" ;;
        04-amber)   NAME="Amber";   WALL_KEY="07-flame-orange";   D_ACC="ff9e64"; D_HOT="ffc98b"; L_ACC="b84309"; L_HOT="ea580c"; TUI_C="yellow" ;;
        05-topaz)   NAME="Topaz";   WALL_KEY="05-star-gold";      D_ACC="e0af68"; D_HOT="ffdf9e"; L_ACC="946210"; L_HOT="ca8a04"; TUI_C="yellow" ;;
        06-citrine) NAME="Citrine"; WALL_KEY="05-star-gold";      D_ACC="f9e2af"; D_HOT="fff3b0"; L_ACC="854d0e"; L_HOT="ca8a04"; TUI_C="yellow" ;;
        07-peridot) NAME="Peridot"; WALL_KEY="04-emerald-green";  D_ACC="a6e3a1"; D_HOT="d8f3dc"; L_ACC="15803d"; L_HOT="16a34a"; TUI_C="lightgreen" ;;
        08-emerald) NAME="Emerald"; WALL_KEY="04-emerald-green";  D_ACC="9ece6a"; D_HOT="cbf0a3"; L_ACC="2d7a31"; L_HOT="16a34a"; TUI_C="green" ;;
        09-verdant) NAME="Verdant"; WALL_KEY="04-emerald-green";  D_ACC="73daca"; D_HOT="a8f9ff"; L_ACC="0f766e"; L_HOT="0d9488"; TUI_C="cyan" ;;
        10-lagoon)  NAME="Lagoon";  WALL_KEY="06-electric-cyan";  D_ACC="2ac3de"; D_HOT="89dceb"; L_ACC="0e7490"; L_HOT="0891b2"; TUI_C="cyan" ;;
        11-glacier) NAME="Glacier"; WALL_KEY="06-electric-cyan";  D_ACC="7dcfff"; D_HOT="bfeaff"; L_ACC="0369a1"; L_HOT="0284c7"; TUI_C="lightcyan" ;;
        12-cobalt)  NAME="Cobalt";  WALL_KEY="01-super-blue";     D_ACC="7aa2f7"; D_HOT="bcd3ff"; L_ACC="2554a3"; L_HOT="3c6eb4"; TUI_C="blue" ;;
        13-indigo)  NAME="Indigo";  WALL_KEY="01-super-blue";     D_ACC="6c71c4"; D_HOT="a5abff"; L_ACC="3730a3"; L_HOT="4f46e5"; TUI_C="lightblue" ;;
        14-violet)  NAME="Violet";  WALL_KEY="02-metroid-violet"; D_ACC="bb9af7"; D_HOT="decbff"; L_ACC="6b38b8"; L_HOT="8b5cf6"; TUI_C="magenta" ;;
        15-orchid)  NAME="Orchid";  WALL_KEY="02-metroid-violet"; D_ACC="cba6f7"; D_HOT="f5c2e7"; L_ACC="7e22ce"; L_HOT="a855f7"; TUI_C="lightmagenta" ;;
        16-fuchsia) NAME="Fuchsia"; WALL_KEY="08-neon-coral";     D_ACC="f43f5e"; D_HOT="ff99ac"; L_ACC="9f1239"; L_HOT="be123c"; TUI_C="lightmagenta" ;;
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
    THEME_COLOR="12-cobalt"; THEME_MODE="dark"; THEME_CORNERS="square"; THEME_NIGHTLIGHT="off"
    # shellcheck disable=SC1090
    [[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
    THEME_COLOR="$(resolve_color "${THEME_COLOR:-12-cobalt}" || echo "12-cobalt")"
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
        write_lock_lbl "<b>󰍹 Screen Off</b>" "rgba($LOCK_FG, 1.0)" "12" "-390, -24" "right" "top" $'    onclick = ~/.config/hypr/scripts/toggle-touchpad.sh dpms off\n'
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
        -e "s/col\.active_border = .*/col.active_border = rgb($ACCENT)/" -e "s/col\.inactive_border = .*/col.inactive_border = rgba(${BORDER}aa)/" \
        -e "s/col\.border_active = .*/col.border_active = rgb($ACCENT)/" -e "s/col\.border_inactive = .*/col.border_inactive = rgba(${BORDER}aa)/" \
        -e "s/text_color = .*/text_color = rgb($FG)/" -e "s/col\.active = .*/col.active = rgba(${ACCENT}cc)/" \
        -e "s/col\.inactive = .*/col.inactive = rgba(${BG_ALT}cc)/" -e "s/rounding = .*/rounding = $hypr_round/" \
        -e "s/animation = layers,.*/animation = layers, 1, 1.2, quick, fade/" -e "s/animation = layersIn,.*/animation = layersIn, 1, 1.2, quick, fade/" \
        -e "s/animation = specialWorkspace,.*/animation = specialWorkspace, 1, 1.2, quick, fade/" "$HOME/.config/hypr/conf/looknfeel.conf"
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

    # 6. IdleScreen, GTK/Qt6/Portal, Night Light, OpenRGB & Greetd
    [[ ! -f "$HOME/.config/idlescreen/config.toml" ]] && { mkdir -p "$HOME/.config/idlescreen"; printf '[general]\nidle_enabled = true\nidle_timeout_secs = 120\ndpms_timeout_secs = 0\nprimary_output = ""\n\n[saver]\nactive = "superfedora"\n\n[saver.ascii]\nmode = "superfedora"\ntargets = ["superfedora"]\ntext = ""\nfps = 0\ndwell_secs = 5.0\ndissolve_duration_secs = 0.7\n' > "$HOME/.config/idlescreen/config.toml"; }
    command -v gsettings >/dev/null 2>&1 && { gsettings set org.gnome.desktop.interface color-scheme "$PORTAL_SCHEME" 2>/dev/null || true; gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true; }
    local p_dark=1; [[ "$mode" == "light" ]] && p_dark=0
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    printf '[Settings]\ngtk-theme-name=%s\ngtk-icon-theme-name=Adwaita\ngtk-font-name=JetBrainsMono Nerd Font 11\ngtk-cursor-theme-name=Adwaita\ngtk-cursor-theme-size=24\ngtk-application-prefer-dark-theme=%s\n' "$GTK_THEME" "$p_dark" | tee "$HOME/.config/gtk-3.0/settings.ini" > "$HOME/.config/gtk-4.0/settings.ini"
    printf '[ColorScheme]\nactive_colors=#%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #000000, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s\ninactive_colors=#%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #000000, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s\ndisabled_colors=#%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #000000, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s, #%s\n' \
        "$FG" "$BG_ALT" "$BG_HOV" "$BG_ALT" "$BG" "$BORDER" "$FG" "$HOT" "$FG" "$BG" "$BG" "$ACCENT" "$BG" "$ACCENT" "$HOT" "$BG_ALT" "$BG" "$BG_ALT" "$FG" "$MUTED" "$ACCENT" \
        "$FG_DIM" "$BG_ALT" "$BG_HOV" "$BG_ALT" "$BG" "$BORDER" "$FG_DIM" "$HOT" "$FG_DIM" "$BG" "$BG" "$BORDER" "$FG" "$ACCENT" "$HOT" "$BG_ALT" "$BG" "$BG_ALT" "$FG_DIM" "$MUTED" "$BORDER" \
        "$MUTED" "$BG" "$BG_ALT" "$BG" "$BG" "$BORDER" "$MUTED" "$MUTED" "$MUTED" "$BG" "$BG" "$BORDER" "$MUTED" "$MUTED" "$MUTED" "$BG" "$BG" "$BG_ALT" "$MUTED" "$MUTED" "$BORDER" > "$STATE_DIR/qt6-colorscheme.conf"
    printf '# SuperFedora Qt6 Theme Provider Configuration (hyprqt6engine)\ntheme {\n    color_scheme = %s/qt6-colorscheme.conf\n    icon_theme = Adwaita\n    style = Fusion\n    font = JetBrainsMono Nerd Font\n    font_size = 11\n    font_fixed = JetBrainsMono Nerd Font\n    font_fixed_size = 11\n}\n\nmisc {\n    single_click_activate = false\n    menus_have_icons = true\n    shortcuts_for_context_menus = true\n}\n' "$STATE_DIR" > "$HOME/.config/hypr/hyprqt6engine.conf"
    if [[ "$nl" == "on" ]]; then
        if ! pgrep -x wlsunset >/dev/null 2>&1 && ! pgrep -x hyprsunset >/dev/null 2>&1; then
            command -v hyprsunset >/dev/null 2>&1 && { nohup hyprsunset -t 4200 >/dev/null 2>&1 & } || { command -v wlsunset >/dev/null 2>&1 && nohup wlsunset -t 4200 -T 6500 >/dev/null 2>&1 & } || true
        fi
    else pkill -x wlsunset 2>/dev/null || true; pkill -x hyprsunset 2>/dev/null || true; fi
    echo "$ACCENT" > "$STATE_DIR/rgb-color"
    [[ -s "$STATE_DIR/rgb-devices" ]] && command -v openrgb >/dev/null 2>&1 && (openrgb --noautoconnect -m direct -c "$ACCENT" >/dev/null 2>&1 &) || true
    local tui_theme="border=$TUI_C;title=$TUI_C;prompt=$TUI_C;time=$TUI_TEXT;action=$TUI_C;button=$TUI_C;container=$TUI_BG;input=$TUI_TEXT"
    [[ -w /etc/greetd/config.toml ]] && printf '# SuperFedora login screen: greetd + tuigreet on tty1.\n[terminal]\nvt = 1\n\n[default_session]\ncommand = "tuigreet --time --asterisks --remember --remember-session --theme '\''%s'\'' --sessions /usr/share/wayland-sessions --cmd '\''uwsm start -e -D Hyprland hyprland.desktop'\'' --greeting '\''SUPER FEDORA'\''"\nuser = "greetd"\n' "$tui_theme" > /etc/greetd/config.toml
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
[[ $# -eq 0 && ( -n "$OPT_MODE" || -n "$OPT_CORNERS" || -n "$OPT_NL" ) ]] && { apply_all "$THEME_COLOR" "$THEME_MODE" "$THEME_CORNERS" "$THEME_NIGHTLIGHT"; exit 0; }

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
        target="${2:-toggle}"; [[ "$target" == "toggle" ]] && { [[ "$THEME_CORNERS" == "rounded" ]] && target="square" || target="rounded"; }
        [[ "$target" == "rounded" || "$target" == "square" ]] || { echo "corners must be square, rounded, or toggle" >&2; exit 2; }
        apply_all "$THEME_COLOR" "$THEME_MODE" "$target" "$THEME_NIGHTLIGHT" ;;
    nightlight|night-light)
        target="${2:-toggle}"; [[ "$target" == "toggle" ]] && { [[ "$THEME_NIGHTLIGHT" == "on" ]] && target="off" || target="on"; }
        apply_all "$THEME_COLOR" "$THEME_MODE" "$THEME_CORNERS" "$target" ;;
    rgb|openrgb)
        palette_tokens "$THEME_COLOR" "$THEME_MODE"; hex="${2:-$ACCENT}"; hex="${hex#\#}"; [[ "${hex,,}" == "off" ]] && hex="000000"
        mkdir -p "$STATE_DIR" && echo "$hex" > "$STATE_DIR/rgb-color"
        command -v openrgb >/dev/null 2>&1 && openrgb --noautoconnect -m direct -c "$hex" >/dev/null 2>&1 || true ;;
    reload) apply_all "$THEME_COLOR" "$THEME_MODE" "$THEME_CORNERS" "$THEME_NIGHTLIGHT" >/dev/null ;;
    pick)
        other_m="day"; [[ "$THEME_MODE" == "light" ]] && other_m="night"; other_c="rounded"; [[ "$THEME_CORNERS" == "rounded" ]] && other_c="square"
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
