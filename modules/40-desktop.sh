# shellcheck shell=bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# desc: Hyprland desktop, Quickshell bar, portals and desktop helpers

module_run() {
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
        [[ "${SF_BUILD_MODE:-quick}" != "source" || -f "$SF_STATE/source-built/wiremix.stamp" ]]
    }
    _wm_i() {
        if [[ "${SF_BUILD_MODE:-quick}" == "source" ]]; then
            "$SF_ROOT/lib/build-source.sh" wiremix
        else
            as_root dnf install -y wiremix
        fi
    }
    need "Audio TUI (wiremix)" _wm_t _wm_i

    _wl_t() {
        command -v wlctl >/dev/null || return 1
        [[ "${SF_BUILD_MODE:-quick}" != "source" || -f "$SF_STATE/source-built/wlctl.stamp" ]]
    }
    _wl_i() {
        if [[ "${SF_BUILD_MODE:-quick}" == "source" ]]; then
            "$SF_ROOT/lib/build-source.sh" wlctl
        else
            mkdir -p "$HOME/.local/bin" &&
            curl -fsSL https://github.com/aashish-thapa/wlctl/releases/latest/download/wlctl-x86_64-unknown-linux-musl \
                -o "$HOME/.local/bin/wlctl" &&
            chmod +x "$HOME/.local/bin/wlctl"
        fi
    }
    need "Wi-Fi TUI (wlctl)" _wl_t _wl_i

    _bt_t() {
        command -v bluetui >/dev/null || return 1
        [[ "${SF_BUILD_MODE:-quick}" != "source" || -f "$SF_STATE/source-built/bluetui.stamp" ]]
    }
    _bt_i() {
        if [[ "${SF_BUILD_MODE:-quick}" == "source" ]]; then
            "$SF_ROOT/lib/build-source.sh" bluetui
        else
            mkdir -p "$HOME/.local/bin" &&
            curl -fsSL https://github.com/pythops/bluetui/releases/latest/download/bluetui-x86_64-linux-musl \
                -o "$HOME/.local/bin/bluetui" &&
            chmod +x "$HOME/.local/bin/bluetui"
        fi
    }
    need "Bluetooth TUI (bluetui)" _bt_t _bt_i

    _sf_t() { command -v superforge >/dev/null 2>&1; }
    _sf_i() { "$SF_ROOT/lib/forge.sh" build superforge; }
    need "SuperForge Compiler (superforge)" _sf_t _sf_i

    _st_t() { command -v supertheme >/dev/null 2>&1; }
    _st_i() { (command -v superforge >/dev/null 2>&1 && superforge build supertheme) || "$SF_ROOT/lib/forge.sh" build supertheme; }
    need "SuperTheme Engine (supertheme)" _st_t _st_i

    _ss_t() {
        command -v superdock >/dev/null 2>&1 &&
        command -v superbar >/dev/null 2>&1 &&
        command -v supersettings >/dev/null 2>&1 &&
        command -v supernotify >/dev/null 2>&1 &&
        command -v superlock >/dev/null 2>&1
    }
    _ss_i() {
        if command -v superforge >/dev/null 2>&1; then
            superforge build supershell && superforge build supernotify
        else
            "$SF_ROOT/lib/forge.sh" build supershell && "$SF_ROOT/lib/forge.sh" build supernotify
        fi
    }
    need "SuperShell Suite (superdock/bar/settings/notify/lock)" _ss_t _ss_i
}
