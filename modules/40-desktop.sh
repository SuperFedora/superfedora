# shellcheck shell=bash
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
}
