# shellcheck shell=bash
# desc: Login screen (greetd + tuigreet), Polkit rules, and uwsm Wayland session

module_run() {
    need_pkgs "$SF_ROOT/packages/session.txt"
    need_root_file system/etc/greetd/config.toml /etc/greetd/config.toml
    need_root_file system/etc/tmpfiles.d/superfedora-tuigreet.conf /etc/tmpfiles.d/superfedora-tuigreet.conf
    need_root_file system/etc/polkit-1/rules.d/50-superfedora.rules /etc/polkit-1/rules.d/50-superfedora.rules
    need_root_file system/usr/share/wayland-sessions/superfedora.desktop /usr/share/wayland-sessions/superfedora.desktop

    _cache_t() {
        [[ -d /var/cache/tuigreet && -f /usr/share/wayland-sessions/superfedora.desktop ]]
    }
    _cache_i() {
        as_root systemd-tmpfiles --create /etc/tmpfiles.d/superfedora-tuigreet.conf
        mkdir -p "$HOME/.config/superfedora"
        printf 'SELECTED_SESSION="superfedora"\n' > "$HOME/.config/superfedora/session.env"
        command -v restorecon >/dev/null 2>&1 && as_root restorecon -Rv /etc/greetd /var/cache/tuigreet /etc/polkit-1/rules.d /usr/share/wayland-sessions >/dev/null 2>&1 || true
    }
    need "/var/cache/tuigreet + SuperFedora default DE" _cache_t _cache_i

    # Only one display manager may own display-manager.service
    local dm
    for dm in gdm.service sddm.service lightdm.service; do
        need_service_off "$dm"
    done
    need_service greetd.service
    need_default_target graphical.target
}
