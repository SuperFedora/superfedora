# shellcheck shell=bash
# desc: Package repositories (RPM Fusion, Hyprland COPR, IdleScreen, vendors)

module_run() {
    need_rpmfusion
    need_copr lionheartp/Hyprland
    need_copr phracek/PyCharm

    _is_key_t() { [[ -f /etc/pki/rpm-gpg/idlescreen-key.gpg ]]; }
    _is_key_i() {
        local tmp_k rc=0; tmp_k="$(mktemp)"
        curl -fsSL https://idlescreen.github.io/packages/rpm/idlescreen-key.gpg -o "$tmp_k" \
            && gpg --show-keys --with-colons "$tmp_k" 2>/dev/null | grep -q '^fpr:::::::::549E73C9BC9229C786E538E2FBD8FC52C7817DD2:' \
            && as_root install -D -m 644 "$tmp_k" /etc/pki/rpm-gpg/idlescreen-key.gpg \
            && as_root rpm --import /etc/pki/rpm-gpg/idlescreen-key.gpg || rc=$?
        rm -f "$tmp_k"; return "$rc"
    }
    need "IdleScreen signing key" _is_key_t _is_key_i
    need_repofile idlescreen     https://idlescreen.github.io/packages/rpm/idlescreen.repo
    if [[ -f /etc/yum.repos.d/idlescreen.repo && "${XDG_CURRENT_DESKTOP:-}" != *COSMIC* ]] && ! grep -q '^excludepkgs=' /etc/yum.repos.d/idlescreen.repo 2>/dev/null; then
        as_root sh -c 'printf "\nexcludepkgs=idle-cosmic\n" >> /etc/yum.repos.d/idlescreen.repo' || true
    fi
    need_repofile google-chrome  "$SF_ROOT/system/etc/yum.repos.d/google-chrome.repo"  https://dl.google.com/linux/linux_signing_key.pub
    need_repofile microsoft-edge "$SF_ROOT/system/etc/yum.repos.d/microsoft-edge.repo" https://packages.microsoft.com/keys/microsoft.asc
    need_repofile tailscale      https://pkgs.tailscale.com/stable/fedora/tailscale.repo
}
