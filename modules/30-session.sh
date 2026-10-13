# shellcheck shell=bash
# desc: Login screen (greetd + tuigreet) launching Hyprland through uwsm

module_run() {
    need_pkgs "$SF_ROOT/packages/session.txt"
    need_root_file system/etc/greetd/config.toml /etc/greetd/config.toml
    need_root_file system/etc/tmpfiles.d/superfedora-tuigreet.conf /etc/tmpfiles.d/superfedora-tuigreet.conf

    _cache_t() { [[ -d /var/cache/tuigreet ]]; }
    _cache_i() { as_root systemd-tmpfiles --create /etc/tmpfiles.d/superfedora-tuigreet.conf; }
    need "/var/cache/tuigreet" _cache_t _cache_i

    # Only one display manager may own display-manager.service
    local dm
    for dm in gdm.service sddm.service lightdm.service; do
        need_service_off "$dm"
    done
    need_service greetd.service
    need_default_target graphical.target
}
