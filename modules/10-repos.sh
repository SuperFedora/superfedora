# shellcheck shell=bash
# desc: Package repositories (RPM Fusion, Hyprland COPR, IdleScreen, vendors)

module_run() {
    need_rpmfusion
    need_copr lionheartp/Hyprland
    need_copr phracek/PyCharm

    _is_key_t() { [[ -f /etc/pki/rpm-gpg/idlescreen-key.gpg ]]; }
    _is_key_i() {
        curl -fsSL https://idlescreen.github.io/packages/rpm/idlescreen-key.gpg \
            | as_root install -D -m 644 /dev/stdin /etc/pki/rpm-gpg/idlescreen-key.gpg \
            && as_root rpm --import /etc/pki/rpm-gpg/idlescreen-key.gpg
    }
    need "IdleScreen signing key" _is_key_t _is_key_i
    need_repofile idlescreen     https://idlescreen.github.io/packages/rpm/idlescreen.repo
    need_repofile google-chrome  "$SF_ROOT/system/etc/yum.repos.d/google-chrome.repo"  https://dl.google.com/linux/linux_signing_key.pub
    need_repofile microsoft-edge "$SF_ROOT/system/etc/yum.repos.d/microsoft-edge.repo" https://packages.microsoft.com/keys/microsoft.asc
    need_repofile tailscale      https://pkgs.tailscale.com/stable/fedora/tailscale.repo
}
