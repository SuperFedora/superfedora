# shellcheck shell=bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# desc: Hyprland desktop, Quickshell bar, portals and desktop helpers

module_run() {
    local forge_cmd
    forge_cmd="$(command -v superforge 2>/dev/null || echo "$SF_ROOT/lib/forge.sh")"

    _sf_t() { command -v superforge >/dev/null 2>&1; }
    _sf_i() {
        if [[ "${SF_BUILD_MODE:-race}" == "source" ]]; then
            "$SF_ROOT/lib/forge.sh" build superforge
        else
            "$SF_ROOT/lib/forge.sh" fetch-bin superforge || "$SF_ROOT/lib/forge.sh" build superforge
        fi
    }
    need "SuperForge Compiler (superforge)" _sf_t _sf_i
    forge_cmd="$(command -v superforge 2>/dev/null || echo "$SF_ROOT/lib/forge.sh")"

    need_pkgs "$SF_ROOT/packages/desktop.txt"

    # JetBrainsMono Nerd Font: bar icons, fuzzel, hyprlock
    local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"
    _nf_t() { fc-list 2>/dev/null | grep >/dev/null "JetBrainsMono Nerd Font"; }
    _nf_i() {
        mkdir -p "$font_dir" &&
        curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz \
            | tar -xJ -C "$font_dir" --wildcards '*.ttf' &&
        fc-cache -f "$font_dir"
    }
    need "JetBrainsMono Nerd Font" _nf_t _nf_i

    # Omarchy-style Ratatui TUIs for PipeWire Audio (wiremix), Wi-Fi (wlctl) and Bluetooth (bluetui)
    _wm_t() {
        command -v wiremix >/dev/null || return 1
        [[ "${SF_BUILD_MODE:-race}" != "source" || -f "$SF_STATE/source-built/wiremix.stamp" ]]
    }
    _wm_i() {
        if [[ "${SF_BUILD_MODE:-race}" == "source" ]]; then
            "$forge_cmd" build wiremix
        else
            as_root dnf install -y wiremix || "$forge_cmd" fetch-bin wiremix
        fi
    }
    need "Audio TUI (wiremix)" _wm_t _wm_i

    _wl_t() {
        command -v wlctl >/dev/null || return 1
        [[ "${SF_BUILD_MODE:-race}" != "source" || -f "$SF_STATE/source-built/wlctl.stamp" ]]
    }
    _wl_i() {
        if [[ "${SF_BUILD_MODE:-race}" == "source" ]]; then
            "$forge_cmd" build wlctl
        else
            "$forge_cmd" fetch-bin wlctl
        fi
    }
    need "Wi-Fi TUI (wlctl)" _wl_t _wl_i

    _bt_t() {
        command -v bluetui >/dev/null || return 1
        [[ "${SF_BUILD_MODE:-race}" != "source" || -f "$SF_STATE/source-built/bluetui.stamp" ]]
    }
    _bt_i() {
        if [[ "${SF_BUILD_MODE:-race}" == "source" ]]; then
            "$forge_cmd" build bluetui
        else
            "$forge_cmd" fetch-bin bluetui
        fi
    }
    need "Bluetooth TUI (bluetui)" _bt_t _bt_i

    _st_t() { command -v supertheme >/dev/null 2>&1; }
    _st_i() {
        if [[ "${SF_BUILD_MODE:-race}" == "source" ]]; then "$forge_cmd" build supertheme; else "$forge_cmd" fetch-bin supertheme; fi
    }
    need "SuperTheme Engine (supertheme)" _st_t _st_i

    _ss_t() {
        command -v superbar >/dev/null 2>&1 &&
        command -v supersettings >/dev/null 2>&1 &&
        command -v supernotify >/dev/null 2>&1 &&
        command -v superlock >/dev/null 2>&1
    }
    _ss_i() {
        if [[ "${SF_BUILD_MODE:-race}" == "source" ]]; then
            "$forge_cmd" build superbar && "$forge_cmd" build supershell && "$forge_cmd" build supernotify
        else
            "$forge_cmd" fetch-bin superbar && "$forge_cmd" fetch-bin supershell && "$forge_cmd" fetch-bin supernotify
        fi
    }
    need "SuperShell Suite (superbar/settings/notify/lock)" _ss_t _ss_i
}
