# shellcheck shell=bash
# desc: Base system a minimal install lacks (network, audio, power, fonts, codecs)

module_run() {
    need_pkgs "$SF_ROOT/packages/base.txt"

    # Full codecs from RPM Fusion instead of Fedora's patent-free builds
    rpm -q --quiet ffmpeg-free && need_swap ffmpeg-free ffmpeg
    rpm -q --quiet ffmpeg-free || need_pkgs <(echo ffmpeg)

    # SuperFedora workstation identity markers
    if is_install; then
        as_root mkdir -p /etc/superfedora
        as_root sh -c "echo 'SUPERFEDORA=1' > /etc/superfedora/release"
        as_root sh -c "echo 'export SUPERFEDORA=1' > /etc/profile.d/superfedora.sh"
    fi

    need_service NetworkManager.service
    need_service bluetooth.service
    need_service tuned.service
    need_service fwupd-refresh.timer
}
