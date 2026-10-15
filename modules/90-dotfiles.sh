# shellcheck shell=bash
# desc: Desktop configs, default applications and user services

module_run() {
    # Desktop configs: real copies of dotfiles/, previous versions backed up
    local drift
    drift="$("$SF_ROOT/lib/install-dotfiles.sh" --check 2>/dev/null | grep -v '^untracked' | grep -v '^In sync')"
    if [[ -z "$drift" ]]; then
        r_ok "desktop configs (dotfiles v$SF_VERSION)"
    elif is_install; then
        if run_logged "$SF_ROOT/lib/install-dotfiles.sh" --no-reload; then
            r_added "desktop configs (dotfiles v$SF_VERSION)"
        else
            r_failed "desktop configs"
        fi
    else
        while IFS= read -r line; do r_need "config $line"; done <<< "$drift"
    fi

    # Default applications used by Super+B / Super+F / Super+T
    local ff=firefox.desktop
    [[ -f /usr/share/applications/org.mozilla.firefox.desktop ]] && ff=org.mozilla.firefox.desktop
    _browser_t() {
        [[ "$(xdg-settings get default-web-browser 2>/dev/null)" == "$ff" ]] &&
        [[ "$(xdg-mime query default x-scheme-handler/http 2>/dev/null)" == "$ff" ]] &&
        [[ "$(xdg-mime query default x-scheme-handler/https 2>/dev/null)" == "$ff" ]]
    }
    _browser_i() {
        xdg-mime default "$ff" x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml
        xdg-settings set default-web-browser "$ff" 2>/dev/null || true
    }
    command -v xdg-mime >/dev/null && need "default browser: Firefox" _browser_t _browser_i

    _ensure_yazi_desktop() {
        mkdir -p "$HOME/.local/share/applications"
        cat > "$HOME/.local/share/applications/yazi.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Yazi File Manager
Comment=Blazing fast terminal file manager written in Rust
Exec=kitty --class superfiles --title="Yazi File Manager" -e yazi %u
Icon=system-file-manager
Terminal=false
Categories=System;FileTools;FileManager;
MimeType=inode/directory;
EOF
    }
    _fm_t() {
        [[ -f "$HOME/.local/share/applications/yazi.desktop" || -f /usr/share/applications/yazi.desktop ]] &&
        [[ "$(xdg-mime query default inode/directory 2>/dev/null)" == yazi.desktop ]]
    }
    _fm_i() {
        _ensure_yazi_desktop
        grep -q '^inode/directory=yazi.desktop' "$HOME/.config/mimeapps.list" 2>/dev/null || \
            xdg-mime default yazi.desktop inode/directory
    }
    command -v xdg-mime >/dev/null && need "default file manager: Yazi" _fm_t _fm_i

    _dirs_t() { [[ -f "$HOME/.config/user-dirs.dirs" ]]; }
    _dirs_i() { xdg-user-dirs-update; }
    command -v xdg-user-dirs-update >/dev/null && need "XDG user folders" _dirs_t _dirs_i

    need_user_service superfedora-session.target
    need_user_service supershell.service
    need_user_service superagent.service
    need_user_service supertheme-sun.timer
    need_user_service superforge-check.timer
}
