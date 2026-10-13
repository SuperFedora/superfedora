# shellcheck shell=bash
# desc: Base system a minimal install lacks (network, audio, power, fonts, codecs)

module_run() {
    need_pkgs "$SF_ROOT/packages/base.txt"

    # Full codecs from RPM Fusion instead of Fedora's patent-free builds
    rpm -q --quiet ffmpeg-free && need_swap ffmpeg-free ffmpeg
    rpm -q --quiet ffmpeg-free || need_pkgs <(echo ffmpeg)

    need_service NetworkManager.service
    need_service bluetooth.service
    need_service tuned.service
    need_service fwupd-refresh.timer
}
