# shellcheck shell=bash
# desc: IdleScreen screensaver (started by hypridle with 16-bit SuperFedora theme)

module_run() {
    need_pkgs "$SF_ROOT/packages/idlescreen.txt"
    need_user_service idlescreen.service

    # idlescreen-extras is optional (may require exact idlescreen version match)
    if is_install && ! rpm -q --quiet idlescreen-extras 2>/dev/null; then
        as_root dnf install -y idlescreen-extras >/dev/null 2>&1 || true
    fi

    # Activate exclusive 16-bit SuperFedora pixel art screensaver if not yet configured
    if is_install && [[ ! -f "$HOME/.config/idlescreen/config.toml" ]] && command -v idlescreen >/dev/null 2>&1; then
        idlescreen set superfedora >/dev/null 2>&1 || true
    fi
}
