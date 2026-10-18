# shellcheck shell=bash
# desc: Base system a minimal install lacks (network, audio, power, fonts, codecs)

module_run() {
    need_pkgs "$SF_ROOT/packages/base.txt"

    # Full codecs & VA-API hardware video acceleration (Wave 2)
    rpm -q --quiet ffmpeg-free && need_swap ffmpeg-free ffmpeg
    rpm -q --quiet ffmpeg-free || need_pkgs <(printf 'ffmpeg\nlibva-utils\nvulkan-tools\n')
    if [[ -x "$SF_ROOT/bin/superfedora" ]]; then
        _hw_t() { [[ -f "$HOME/.config/superfedora/firefox-vaapi.js" ]]; }
        _hw_i() { "$SF_ROOT/bin/superfedora" hardware optimize; }
        need "GPU VA-API & Firefox DMABUF hardware acceleration" _hw_t _hw_i
    fi

    # SuperFedora workstation identity markers & multi-user /usr/share/superfedora + /etc/skel seeding
    if is_install; then
        as_root mkdir -p /etc/superfedora /usr/share/superfedora /etc/skel/.config/superfedora/cast
        as_root sh -c "echo 'SUPERFEDORA=1' > /etc/superfedora/release"
        as_root sh -c "printf 'export SUPERFEDORA=1\ncase \":\$PATH:\" in *\":\$HOME/.local/bin:\"*);; *) export PATH=\"\$HOME/.local/bin:/usr/local/bin:\$PATH\";; esac\n' > /etc/profile.d/superfedora.sh"
        as_root cp -rf "$SF_ROOT/VERSION" "$SF_ROOT/lib" "$SF_ROOT/modules" "$SF_ROOT/packages" /usr/share/superfedora/ 2>/dev/null || true
        [[ -d "$SF_ROOT/dotfiles/.config/superfedora/cast" ]] && as_root cp -rf "$SF_ROOT/dotfiles/.config/superfedora/cast" /usr/share/superfedora/ 2>/dev/null || true
        [[ -d "$SF_ROOT/dotfiles/.config" ]] && as_root cp -rn "$SF_ROOT/dotfiles/.config/." /etc/skel/.config/ 2>/dev/null || true
        [[ ! -f /etc/skel/.config/superfedora/theme.env ]] && as_root sh -c 'printf "THEME_COLOR=\"12-cobalt\"\nTHEME_MODE=\"dark\"\nTHEME_CORNERS=\"square\"\nTHEME_NIGHTLIGHT=\"off\"\n" > /etc/skel/.config/superfedora/theme.env' || true
        [[ -x "$SF_ROOT/bin/superfedora" ]] && { as_root install -m 755 "$SF_ROOT/bin/superfedora" /usr/local/bin/superfedora; as_root rm -f /usr/local/bin/sf 2>/dev/null || true; } || true
        command -v restorecon >/dev/null 2>&1 && as_root restorecon -Rv /usr/local/bin /usr/share/superfedora /etc/superfedora /etc/profile.d/superfedora.sh >/dev/null 2>&1 || true
    fi

    need_service NetworkManager.service
    need_service bluetooth.service
    need_service tuned.service
    need_service fwupd-refresh.timer
}
