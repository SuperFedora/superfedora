# shellcheck shell=bash
# desc: Applications (terminals, browsers, files, Tailscale, PyCharm)

module_run() {
    need_pkgs "$SF_ROOT/packages/apps.txt"
    need_service tailscaled.service

    # No stable public download URL: report only
    _syn_t() { [[ -x /opt/Synology/SynologyDrive/bin/launcher ]]; }
    manual "Synology Drive Client" _syn_t "download the Fedora package from https://www.synology.com/support/download"
    _msty_t() { [[ -x "$HOME/.local/share/MstyStudio/mstystudio" || -d /opt/Msty ]]; }
    manual "Msty Studio" _msty_t "download from https://msty.ai"
}
