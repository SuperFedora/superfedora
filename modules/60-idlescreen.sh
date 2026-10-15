# shellcheck shell=bash
# desc: IdleScreen screensaver (unified 50-scene 16-bit SuperFedora arcade engine)

module_run() {
    need_pkgs "$SF_ROOT/packages/idlescreen.txt"
    need_user_service idlescreen.service

    _is_cfg_t() { [[ -f "$HOME/.config/idlescreen/config.toml" ]]; }
    _is_cfg_i() {
        mkdir -p "$HOME/.config/idlescreen"
        printf '[general]\nidle_enabled = true\nidle_timeout_secs = 120\ndpms_timeout_secs = 0\nprimary_output = ""\n\n[saver]\nactive = "superfedora"\n\n[saver.ascii]\nmode = "superfedora"\ntargets = ["superfedora"]\ntext = ""\nfps = 0\ndwell_secs = 5.0\ndissolve_duration_secs = 0.7\n' > "$HOME/.config/idlescreen/config.toml"
        command -v idlescreen >/dev/null 2>&1 && idlescreen set superfedora >/dev/null 2>&1 || true
    }
    need "IdleScreen SuperFedora config" _is_cfg_t _is_cfg_i
}

