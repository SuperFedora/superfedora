# shellcheck shell=bash
# desc: Fedora version, SELinux, systemd OS tuning, sudo and Btrfs safety snapshot

module_run() {
    # shellcheck source=/dev/null
    . /etc/os-release
    if [[ "${ID:-}" == fedora && "${VERSION_ID:-0}" -ge 42 ]]; then
        r_ok "Fedora $VERSION_ID ($(uname -m))"
    else
        r_failed "Fedora 42 or newer required (found ${PRETTY_NAME:-unknown})"
        is_install && die "unsupported system"
    fi

    if command -v getenforce >/dev/null 2>&1; then
        local se_mode; se_mode="$(getenforce 2>/dev/null || echo Enforcing)"
        if [[ "$se_mode" == "Enforcing" ]]; then
            r_ok "SELinux ($se_mode)"
        else
            warn "SELinux is $se_mode (SuperFedora supports Enforcing mode)"
        fi
    fi

    if curl -fsS --max-time 10 -o /dev/null https://github.com; then
        r_ok "network"
    else
        r_failed "network (cannot reach github.com)"
        is_install && die "network required"
    fi

    if is_install; then
        sudo -n true 2>/dev/null || sudo -v || die "sudo access required"
        # keep sudo alive for the rest of the run
        ( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
        r_ok "sudo"
    fi

    # Declarative systemd OS drop-ins (ZRAM, bounded journald, sysctl inotify/swappiness)
    need_root_file system/etc/systemd/zram-generator.conf.d/superfedora.conf /etc/systemd/zram-generator.conf.d/superfedora.conf
    need_root_file system/etc/systemd/journald.conf.d/superfedora.conf /etc/systemd/journald.conf.d/superfedora.conf
    need_root_file system/etc/sysctl.d/90-superfedora.conf /etc/sysctl.d/90-superfedora.conf
    need_service fstrim.timer
    need_service systemd-oomd.service

    # Safety snapshot before the first change (Btrfs root + snapper)
    local fstype; fstype="$(stat -f -c %T / 2>/dev/null)"
    if [[ "$fstype" != btrfs ]]; then
        info "root is $fstype, not Btrfs: no snapshot"
        return 0
    fi
    _snapper_t() { command -v snapper >/dev/null && (sudo -n snapper -c root list >/dev/null 2>&1 || snapper -c root list >/dev/null 2>&1); }
    _snapper_i() { as_root bash "$SF_ROOT/lib/setup-btrfs-snapper.sh"; }
    need "Snapper on Btrfs root" _snapper_t _snapper_i
    need_service snapper-timeline.timer
    need_service snapper-cleanup.timer

    if is_install && command -v snapper >/dev/null && [[ ! -s "$SF_STATE/last_pre_install_snapshot" ]]; then
        local n
        n="$(as_root snapper -c root create -p --description "SuperFedora: before install" \
             --userdata "purpose=superfedora-baseline" 2>/dev/null)"
        if [[ -n "$n" ]]; then
            echo "$n" > "$SF_STATE/last_pre_install_snapshot"
            r_added "baseline snapshot #$n (superfedora rollback)"
        fi
    elif [[ -s "$SF_STATE/last_pre_install_snapshot" ]]; then
        r_ok "baseline snapshot #$(cat "$SF_STATE/last_pre_install_snapshot")"
    fi
}
