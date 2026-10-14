#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# apply-theme.sh — SuperFedora 16-Bit Theme Engine (8 Jewel Colors x Dark/Light x Square/Rounded)
# ==============================================================================
# Usage:
#   sf theme                                  Show active theme & available palettes
#   sf theme set <color> [dark|light] [square|rounded] Apply color, mode & corners
#   sf theme next | prev                      Cycle through the 8 16-bit jewel colors
#   sf theme toggle                           Flip between dark and light variations
#   sf theme corners [square|rounded|toggle]  Swap between 90-degree square & rounded edges
#   sf theme pick                             Interactive Fuzzel 16-bit theme selector
#   sf theme reload                           Re-apply saved theme from state file
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
    THEME_COLOR="01-super-blue"; THEME_MODE="dark"; THEME_CORNERS="square"
    # shellcheck disable=SC1090
    [[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
    THEME_COLOR="$(resolve_color "${THEME_COLOR:-01-super-blue}" || echo "01-super-blue")"
    [[ "${THEME_MODE:-dark}" == "light" ]] || THEME_MODE="dark"
    [[ "${THEME_CORNERS:-square}" == "rounded" ]] || THEME_CORNERS="square"
}

write_lock_btn() {
    local x="$1" icon="$2" fg="$3" bdr="$4" cmd="$5" r="$6"
    printf 'shape {\n    monitor =\n    size = 42, 42\n    color = rgba(%s, 0.92)\n    rounding = %s\n    border_size = 2\n    border_color = rgb(%s)\n    position = %d, -24\n    halign = right\n    valign = top\n    onclick = %s\n}\n' "$LOCK_IN" "$r" "$bdr" "$x" "$cmd"
    printf 'label {\n    monitor =\n    text = &#160;%s&#160;\n    color = %s\n    font_size = 12\n    font_family = JetBrainsMono Nerd Font Mono\n    position = %d, -34\n    halign = right\n    valign = top\n    onclick = %s\n}\n' "$icon" "$fg" "$(( x - 6 ))" "$cmd"
}

apply_all() {
    local color="$1" mode="$2" corners="${3:-$THEME_CORNERS}"
    [[ "$corners" == "rounded" ]] || corners="square"
    palette_tokens "$color" "$mode"
    mkdir -p "$STATE_DIR" "$HOME/.config/hypr/conf" "$HOME/.config/quickshell" "$HOME/.config/fuzzel" "$HOME/.config/kitty" "$HOME/.config/idlescreen"
    printf 'THEME_COLOR="%s"\nTHEME_MODE="%s"\nTHEME_CORNERS="%s"\n' "$color" "$mode" "$corners" > "$STATE_FILE"

    local lock_round="0" hypr_round="0" qs_rad="0" qs_rad_sm="0" fuzzel_rad="0"
    if [[ "$corners" == "rounded" ]]; then
        lock_round="-1"; hypr_round="10"; qs_rad="10"; qs_rad_sm="6"; fuzzel_rad="10"
    fi

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

    # 2. Lock Screen (hyprlock — GNOME layout: floating lower-third user stack + top-right action buttons)
    {
        printf '# Hyprlock Configuration — SuperFedora 16-Bit Theme (%s / %s / %s)\ngeneral {\n    hide_cursor = false\n    ignore_empty_input = true\n    immediate_render = true\n    fail_timeout = 1200\n}\nauth {\n    pam {\n        enabled = true\n        module = password-auth\n    }\n    fingerprint {\n        enabled = true\n    }\n}\nanimations {\n    enabled = false\n}\nbackground {\n    monitor =\n    path = %s\n    blur_passes = 0\n    blur_size = 0\n}\n' "$NAME" "$mode" "$corners" "$wall_rel"
        write_lock_btn -180 "󰍹" "rgba($LOCK_FG, 1.0)" "$ACCENT" "hyprctl dispatch dpms off" "$lock_round"
        write_lock_btn -128 "󰤄" "rgba($LOCK_FG, 1.0)" "$ACCENT" "systemctl suspend" "$lock_round"
        write_lock_btn -76  "󰜉" "rgba($LOCK_FG, 1.0)" "$ACCENT" "systemctl reboot" "$lock_round"
        write_lock_btn -24  "󰐥" "rgb(f7768e)"         "f7768e"  "systemctl poweroff" "$lock_round"
        printf 'image {\n    monitor =\n    path = ~/Pictures/Wallpapers/avatar.jpg\n    size = 88\n    rounding = %s\n    border_size = 2\n    border_color = rgb(%s)\n    position = 0, 148\n    halign = center\n    valign = bottom\n}\n' "$lock_round" "$ACCENT"
        printf 'label {\n    monitor =\n    text = <b>$USER</b>\n    color = rgba(%s, 1.0)\n    font_size = 16\n    font_family = JetBrainsMono Nerd Font\n    position = 0, 108\n    halign = center\n    valign = bottom\n}\n' "$LOCK_FG"
        printf 'input-field {\n    monitor =\n    size = 290, 44\n    outline_thickness = 2\n    rounding = %s\n    dots_size = 0.26\n    dots_spacing = 0.20\n    dots_center = true\n    fade_on_empty = false\n    font_color = rgb(%s)\n    inner_color = rgba(%s, 0.94)\n    outer_color = rgb(%s)\n    check_color = rgb(9ece6a)\n    fail_color = rgb(f7768e)\n    fail_text = <b>Incorrect password ($ATTEMPTS)</b>\n    capslock_color = rgb(e0af68)\n    placeholder_text = Password\n    position = 0, 46\n    halign = center\n    valign = bottom\n}\n' "$lock_round" "$LOCK_FG" "$LOCK_IN" "$ACCENT"
    } > "$HOME/.config/hypr/hyprlock.conf"

    # 3. Hyprland Borders, Rounding & Groupbar (looknfeel.conf + live hyprctl)
    [[ -f "$HOME/.config/hypr/conf/looknfeel.conf" ]] && sed -i \
        -e "s/col\.active_border = .*/col.active_border = rgb($ACCENT)/" \
        -e "s/col\.inactive_border = .*/col.inactive_border = rgba(${BORDER}aa)/" \
        -e "s/col\.border_active = .*/col.border_active = rgb($ACCENT)/" \
        -e "s/col\.border_inactive = .*/col.border_inactive = rgba(${BORDER}aa)/" \
        -e "s/text_color = .*/text_color = rgb($FG)/" \
        -e "s/col\.active = .*/col.active = rgba(${ACCENT}cc)/" \
        -e "s/col\.inactive = .*/col.inactive = rgba(${BG_ALT}cc)/" \
        -e "s/rounding = .*/rounding = $hypr_round/" \
        "$HOME/.config/hypr/conf/looknfeel.conf"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl keyword general:col.active_border "rgb($ACCENT)" >/dev/null 2>&1 || true
        hyprctl keyword general:col.inactive_border "rgba(${BORDER}aa)" >/dev/null 2>&1 || true
        hyprctl keyword decoration:rounding "$hypr_round" >/dev/null 2>&1 || true
    fi

    # 4. Quickshell Top Bar, Docks, OSD, Notifications & Calendar (live IPC update)
    printf '{"bg":"#%s","bgAlt":"#%s","bgHover":"#%s","border":"#%s","fg":"#%s","fgDim":"#%s","muted":"#%s","blue":"#%s","cyan":"#%s","corners":"%s","radius":%s,"radiusSm":%s}\n' \
        "$BG" "$BG_ALT" "$BG_HOV" "$BORDER" "$FG" "$FG_DIM" "$MUTED" "$ACCENT" "$HOT" "$corners" "$qs_rad" "$qs_rad_sm" > "$STATE_DIR/quickshell-theme.json"
    command -v qs >/dev/null 2>&1 && qs ipc call theme reload >/dev/null 2>&1 || true

    # 5. Fuzzel Launcher & Menus (fuzzel.ini)
    printf '# Fuzzel Configuration — SuperFedora 16-Bit Theme (%s / %s / %s)\nfont=JetBrainsMono Nerd Font:size=12\ndpi-aware=auto\nprompt="> "\nicon-theme=Adwaita\nterminal=kitty -e\nwidth=36\nlines=10\nhorizontal-pad=24\nvertical-pad=16\ninner-pad=10\n\n[colors]\nbackground=%sf2\ntext=%sff\nmatch=%sff\nselection=%sff\nselection-text=%sff\nselection-match=%sff\nborder=%sff\n\n[border]\nwidth=2\nradius=%s\n' \
        "$NAME" "$mode" "$corners" "$BG" "$FG" "$ACCENT" "$SEL_BG" "$FG" "$HOT" "$ACCENT" "$fuzzel_rad" > "$HOME/.config/fuzzel/fuzzel.ini"

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
    printf '[OK] Active 16-bit theme: %s (%s mode, %s corners)\n' "$NAME" "$mode" "$corners"
}

load_state
case "${1:-status}" in
    set)
        c="$(resolve_color "${2:-$THEME_COLOR}")" || { echo "unknown color: ${2:-}" >&2; exit 2; }
        m="${3:-$THEME_MODE}"; [[ "$m" == "light" || "$m" == "dark" ]] || { echo "mode must be dark or light" >&2; exit 2; }
        r="${4:-$THEME_CORNERS}"; [[ "$r" == "rounded" || "$r" == "square" ]] || { echo "corners must be square or rounded" >&2; exit 2; }
        apply_all "$c" "$m" "$r" ;;
    next|prev)
        idx=0; for i in "${!COLORS[@]}"; do [[ "${COLORS[$i]}" == "$THEME_COLOR" ]] && idx=$i; done
        step=1; [[ "$1" == "prev" ]] && step=7
        apply_all "${COLORS[$(( (idx + step) % 8 ))]}" "$THEME_MODE" "$THEME_CORNERS" ;;
    toggle)
        other="light"; [[ "$THEME_MODE" == "light" ]] && other="dark"
        apply_all "$THEME_COLOR" "$other" "$THEME_CORNERS" ;;
    corners)
        target="${2:-toggle}"
        if [[ "$target" == "toggle" ]]; then
            target="rounded"; [[ "$THEME_CORNERS" == "rounded" ]] && target="square"
        fi
        [[ "$target" == "rounded" || "$target" == "square" ]] || { echo "corners must be square, rounded, or toggle" >&2; exit 2; }
        apply_all "$THEME_COLOR" "$THEME_MODE" "$target" ;;
    reload)
        apply_all "$THEME_COLOR" "$THEME_MODE" "$THEME_CORNERS" >/dev/null ;;
    pick)
        other_m="light"; [[ "$THEME_MODE" == "light" ]] && other_m="dark"
        other_c="rounded"; [[ "$THEME_CORNERS" == "rounded" ]] && other_c="square"
        choice="$(printf '%s\n' "[*] Toggle mode ($THEME_MODE -> $other_m)" "[*] Toggle corners ($THEME_CORNERS -> $other_c)" "${COLORS[@]}" | fuzzel --dmenu --prompt "16-Bit Theme > " --lines 10 --width 40)" || exit 0
        if [[ "$choice" == "[*] Toggle mode"* ]]; then apply_all "$THEME_COLOR" "$other_m" "$THEME_CORNERS"
        elif [[ "$choice" == "[*] Toggle corners"* ]]; then apply_all "$THEME_COLOR" "$THEME_MODE" "$other_c"
        else apply_all "$choice" "$THEME_MODE" "$THEME_CORNERS"; fi ;;
    status|list)
        palette_tokens "$THEME_COLOR" "$THEME_MODE"
        printf 'Active Theme : %s (%s) [%s / %s]\nPalettes     : %s\n' "$NAME" "$THEME_COLOR" "$THEME_MODE" "$THEME_CORNERS" "${COLORS[*]}" ;;
    *)
        sed -n '6,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
