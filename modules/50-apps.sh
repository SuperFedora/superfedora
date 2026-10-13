# shellcheck shell=bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# desc: Applications (terminals, browsers, files, Tailscale, PyCharm)

module_run() {
    need_pkgs "$SF_ROOT/packages/apps.txt"
    need_service tailscaled.service

    # Optional vendor desktop suites (report status and install instructions when absent)
    _syn_t() { [[ -x /opt/Synology/SynologyDrive/bin/launcher ]]; }
    manual "Synology Drive Client" _syn_t "download the Fedora package from https://www.synology.com/support/download"

    _msty_t() { [[ -x "$HOME/.local/share/MstyStudio/mstystudio" || -d /opt/Msty ]]; }
    manual "Msty Studio" _msty_t "download from https://msty.ai"
}
