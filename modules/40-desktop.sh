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

    # Omarchy-style Ratatui TUIs for NetworkManager Wi-Fi (wlctl) and Bluetooth (bluetui)
    _wl_t() { command -v wlctl >/dev/null; }
    _wl_i() {
        mkdir -p "$HOME/.local/bin" &&
        curl -fsSL https://github.com/aashish-thapa/wlctl/releases/latest/download/wlctl-x86_64-unknown-linux-musl \
            -o "$HOME/.local/bin/wlctl" &&
        chmod +x "$HOME/.local/bin/wlctl"
    }
    need "Wi-Fi TUI (wlctl)" _wl_t _wl_i

    _bt_t() { command -v bluetui >/dev/null; }
    _bt_i() {
        mkdir -p "$HOME/.local/bin" &&
        curl -fsSL https://github.com/pythops/bluetui/releases/latest/download/bluetui-x86_64-linux-musl \
            -o "$HOME/.local/bin/bluetui" &&
        chmod +x "$HOME/.local/bin/bluetui"
    }
    need "Bluetooth TUI (bluetui)" _bt_t _bt_i
}
