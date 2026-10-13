# shellcheck shell=bash
# desc: IdleScreen screensaver (started by hypridle)

module_run() {
    need_pkgs "$SF_ROOT/packages/idlescreen.txt"
    need_user_service idlescreen.service

    # idlescreen-extras is optional (may require exact idlescreen version match)
    if is_install && ! rpm -q --quiet idlescreen-extras 2>/dev/null; then
        as_root dnf install -y idlescreen-extras >/dev/null 2>&1 || true
    fi
}
