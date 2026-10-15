# shellcheck shell=bash
# desc: Base system a minimal install lacks (network, audio, power, fonts, codecs)

module_run() {
    need_pkgs "$SF_ROOT/packages/base.txt"

    # Full codecs from RPM Fusion instead of Fedora's patent-free builds
    rpm -q --quiet ffmpeg-free && need_swap ffmpeg-free ffmpeg
    rpm -q --quiet ffmpeg-free || need_pkgs <(echo ffmpeg)

    # SuperFedora workstation identity markers & multi-user /usr/share/superfedora + /etc/skel seeding
    if is_install; then
        as_root mkdir -p /etc/superfedora /usr/share/superfedora /etc/skel/.config/superfedora
        as_root sh -c "echo 'SUPERFEDORA=1' > /etc/superfedora/release"
        as_root sh -c "printf 'export SUPERFEDORA=1\ncase \":\$PATH:\" in *\":\$HOME/.local/bin:\"*);; *) export PATH=\"\$HOME/.local/bin:/usr/local/bin:\$PATH\";; esac\n' > /etc/profile.d/superfedora.sh"
        [[ -d "$SF_ROOT/dotfiles/.config" ]] && as_root cp -rn "$SF_ROOT/dotfiles/.config/." /etc/skel/.config/ 2>/dev/null || true
        [[ -x "$SF_ROOT/bin/superfedora" ]] && { as_root install -m 755 "$SF_ROOT/bin/superfedora" /usr/local/bin/superfedora; as_root ln -sf superfedora /usr/local/bin/sf; } || true
        command -v restorecon >/dev/null 2>&1 && as_root restorecon -Rv /usr/local/bin /etc/superfedora /etc/profile.d/superfedora.sh >/dev/null 2>&1 || true
    fi

    need_service NetworkManager.service
    need_service bluetooth.service
    need_service tuned.service
    need_service fwupd-refresh.timer
}
