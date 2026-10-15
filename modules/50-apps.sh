# shellcheck shell=bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# desc: DE-independent applications (LibreOffice, Yazi, Zathura, MPV, Helix, SuperForge suite)

module_run() {
    need_pkgs "$SF_ROOT/packages/apps.txt"
    need_service tailscaled.service

    # Flathub remote + Bazaar Flatpak GUI Store (io.github.kolunmi.Bazaar)
    _flathub_t() {
        command -v flatpak >/dev/null 2>&1 &&
        (flatpak remotes --columns=name 2>/dev/null | grep -qx flathub || [[ -x "$HOME/.local/bin/bazaar" ]])
    }
    _flathub_i() {
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
        "$SF_ROOT/lib/forge.sh" build bazaar
    }
    need "Flathub + Bazaar Store (io.github.kolunmi.Bazaar)" _flathub_t _flathub_i

    # DE-Independent SuperForge Source-Built Application Suite
    local item name bin label
    for item in \
        "yazi:yazi:File Manager TUI (yazi)" \
        "dua-cli:dua:Disk Usage Analyzer (dua)" \
        "ouch:ouch:Archive Compressor (ouch)" \
        "oculante:oculante:GPU Image Viewer & Editor (oculante)" \
        "imv:imv:Wayland Image Viewer (imv)" \
        "satty:satty:Screenshot Annotator (satty)" \
        "hyprpicker:hyprpicker:Wayland Pixel Color Picker (hyprpicker)" \
        "wl-screenrec:wl-screenrec:VA-API Screen Recorder (wl-screenrec)" \
        "zathura:zathura:Document & PDF Viewer (zathura)" \
        "typst:typst:Typesetter & PDF Compiler (typst)" \
        "csvlens:csvlens:TUI CSV Spreadsheet Viewer (csvlens)" \
        "helix:hx:Modal Code Editor (hx)" \
        "fend:fend:Unit-Aware Calculator (fend)" \
        "termusic:termusic:Terminal Music & Podcast Player (termusic)" \
        "cava:cava:PipeWire Spectrum Visualizer (cava)" \
        "mpv:mpv:GPU Media Player (mpv)" \
        "cliphist:cliphist:Wayland Clipboard Manager (cliphist)" \
        "bazarr:bazarr:Media Subtitle Manager (bazarr)"
    do
        name="${item%%:*}"
        bin="${item#*:}"; bin="${bin%%:*}"
        label="${item##*:}"
        _app_t() {
            command -v "$bin" >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/$bin" ]] || return 1
            [[ -f "$HOME/.local/share/superfedora/forge/stamps/$name.stamp" || -f "$SF_STATE/source-built/$name.stamp" ]]
        }
        _app_i() {
            if command -v superforge >/dev/null 2>&1; then
                superforge build "$name"
            else
                "$SF_ROOT/lib/forge.sh" build "$name"
            fi
        }
        need "$label" _app_t _app_i
    done

    # Optional vendor desktop suites (report status and install instructions when absent)
    _syn_t() { [[ -x /opt/Synology/SynologyDrive/bin/launcher ]]; }
    manual "Synology Drive Client" _syn_t "download the Fedora package from https://www.synology.com/support/download"

    _msty_t() { [[ -x "$HOME/.local/share/MstyStudio/mstystudio" || -d /opt/Msty ]]; }
    manual "Msty Studio" _msty_t "download from https://msty.ai"
}
