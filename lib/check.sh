# shellcheck shell=bash
# ==============================================================================
# lib/check.sh — idempotent "make sure X is present" helpers
# ==============================================================================
# Each helper checks first and reports ✓ when the item is already there. In
# install mode it installs only what is missing, then re-checks. In status and
# dry-run modes it only reports.
# ==============================================================================

# Print the entries of package list files: one per line, '#' comments allowed
read_list() {
    local f
    for f in "$@"; do
        [[ -r "$f" ]] || die "package list not found: $f"
        sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$f"
    done
}

# Generic: need LABEL TEST_FN INSTALL_FN
need() {
    local label="$1" test_fn="$2" install_fn="$3"
    if "$test_fn"; then
        r_ok "$label"
    elif is_install; then
        info "installing $label…"
        if run_logged "$install_fn" && "$test_fn"; then
            r_added "$label"
        else
            r_failed "$label"
        fi
    else
        r_need "$label"
    fi
}

# ------------------------------------------------------------------------------
# Packages
# ------------------------------------------------------------------------------
_pkg_forged() {
    case "$1" in
        hyprland)   [[ -x "$HOME/.local/bin/Hyprland" || -x /usr/local/bin/Hyprland ]] ;;
        quickshell) [[ -x "$HOME/.local/bin/quickshell" || -x /usr/local/bin/quickshell ]] ;;
        fuzzel)     [[ -x "$HOME/.local/bin/fuzzel" || -x /usr/local/bin/fuzzel ]] ;;
        helix)      [[ -x "$HOME/.local/bin/hx" || -x /usr/local/bin/hx ]] ;;
        neovim)     [[ -x "$HOME/.local/bin/nvim" || -x /usr/local/bin/nvim ]] ;;
        zathura-pdf-mupdf) [[ -x "$HOME/.local/bin/zathura" || -x /usr/local/bin/zathura ]] ;;
        *) [[ -x "$HOME/.local/bin/$1" || -x "/usr/local/bin/$1" || -f "$HOME/.local/share/superfedora/forge/stamps/$1.stamp" ]] ;;
    esac
}

# need_pkgs LIST_FILE... — every package in the lists must be installed
need_pkgs() {
    local -a want missing=()
    mapfile -t want < <(read_list "$@")
    [[ ${#want[@]} -eq 0 ]] && return 0

    local p
    for p in "${want[@]}"; do
        if rpm -q --quiet "$p" 2>/dev/null || rpm -q --quiet --whatprovides "$p" 2>/dev/null || _pkg_forged "$p"; then
            r_ok "$p"
        else
            missing+=("$p")
        fi
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0

    if ! is_install; then
        for p in "${missing[@]}"; do r_need "$p"; done
        return 0
    fi

    info "dnf install ${missing[*]}"
    if ! run_logged as_root dnf install -y "${missing[@]}"; then
        # One bad name must not block the rest: retry individually
        for p in "${missing[@]}"; do
            rpm -q --quiet "$p" 2>/dev/null || run_logged as_root dnf install -y "$p" || true
        done
    fi
    for p in "${missing[@]}"; do
        if rpm -q --quiet "$p" 2>/dev/null || rpm -q --quiet --whatprovides "$p" 2>/dev/null || _pkg_forged "$p"; then
            r_added "$p"
        elif [[ ( "${SF_COPR_FALLBACK:-0}" == "1" || -f "$SF_STATE/copr-fallback" ) && "$p" =~ ^(hyprland|quickshell|fuzzel)$ ]] && run_logged "$SF_ROOT/lib/forge.sh" "$p"; then
            r_added "$p (superforge source fallback)"
        else
            r_failed "$p (dnf install)"
        fi
    done
}

# need_swap FROM TO — replace a package with an alternative (e.g. ffmpeg-free → ffmpeg)
need_swap() {
    local from="$1" to="$2"
    _t() { rpm -q --quiet "$to"; }
    _i() { as_root dnf swap -y "$from" "$to" --allowerasing; }
    need "$to (replaces $from)" _t _i
}

# ------------------------------------------------------------------------------
# Repositories
# ------------------------------------------------------------------------------
_repo_enabled() { dnf repolist --enabled 2>/dev/null | awk 'NR>1{print $1}' | grep -x >/dev/null "$1"; }

need_rpmfusion() {
    local ver; ver="$(rpm -E %fedora)"
    _rf_t() { rpm -q --quiet rpmfusion-free-release && rpm -q --quiet rpmfusion-nonfree-release; }
    _rf_i() {
        as_root dnf install -y \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${ver}.noarch.rpm" \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm" \
        || as_root dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${ver}.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm"
    }
    need "RPM Fusion free + nonfree" _rf_t _rf_i
}

# need_copr OWNER/PROJECT — falls back to superforge source compilation on new Fedora releases
need_copr() {
    local copr="$1" id="copr:copr.fedorainfracloud.org:${1/\//:}" slug="${1/\//-}" ver
    ver="$(rpm -E %fedora 2>/dev/null || echo 42)"
    _copr_t() { _repo_enabled "$id" || [[ -f "$SF_STATE/copr-fallback-$slug" ]]; }
    _copr_i() {
        as_root dnf install -y dnf5-plugins >/dev/null 2>&1 || true
        if ! as_root dnf copr enable -y "$copr" && ! as_root dnf copr enable -y "$copr" "fedora-${ver}-$(uname -m)" 2>/dev/null; then
            warn "COPR $copr not yet published for Fedora $ver; falling back to superforge source compilation"
            mkdir -p "$SF_STATE" && touch "$SF_STATE/copr-fallback-$slug" "$SF_STATE/copr-fallback"
            export SF_COPR_FALLBACK=1
            return 0
        fi
    }
    need "COPR $copr" _copr_t _copr_i
}

# need_repofile ID URL|LOCAL_FILE [GPG_KEY_URL] — drop a .repo file into /etc/yum.repos.d
need_repofile() {
    local id="$1" url="$2" key="${3:-}"
    _rfile_t() { [[ -f "/etc/yum.repos.d/$id.repo" ]]; }
    _rfile_i() {
        if [[ -n "$key" ]]; then as_root rpm --import "$key" || return 1; fi
        if [[ -f "$url" ]]; then
            as_root install -m 644 "$url" "/etc/yum.repos.d/$id.repo"
        else
            curl -fsSL "$url" | as_root tee "/etc/yum.repos.d/$id.repo" >/dev/null
        fi
    }
    need "repo $id" _rfile_t _rfile_i
}

# ------------------------------------------------------------------------------
# Services and targets
# ------------------------------------------------------------------------------
have_systemd() { [[ -d /run/systemd/system ]]; }

# need_service UNIT — system unit enabled
need_service() {
    local unit="$1"
    if ! have_systemd; then warn "systemd not running; skipping $unit"; return 0; fi
    _svc_t() { systemctl is-enabled --quiet "$unit" 2>/dev/null; }
    _svc_i() { as_root systemctl enable "$unit"; }
    need "service $unit enabled" _svc_t _svc_i
}

# need_service_off UNIT — system unit disabled (e.g. a competing login manager)
need_service_off() {
    local unit="$1"
    have_systemd || return 0
    systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep >/dev/null . || return 0
    _off_t() { ! systemctl is-enabled --quiet "$unit" 2>/dev/null; }
    _off_i() { as_root systemctl disable "$unit"; }
    need "service $unit disabled" _off_t _off_i
}

# need_user_service UNIT — user unit enabled for the installing user
need_user_service() {
    local unit="$1"
    _usvc_t() { systemctl --user is-enabled --quiet "$unit" 2>/dev/null; }
    _usvc_i() { systemctl --user daemon-reload 2>/dev/null; systemctl --user enable "$unit"; }
    if ! systemctl --user show-environment >/dev/null 2>&1; then
        warn "no user systemd instance; skipping $unit"; return 0
    fi
    need "user service $unit enabled" _usvc_t _usvc_i
}

need_default_target() {
    local target="$1"
    have_systemd || return 0
    _tgt_t() { [[ "$(systemctl get-default 2>/dev/null)" == "$target" ]]; }
    _tgt_i() { as_root systemctl set-default "$target"; }
    need "boot target $target" _tgt_t _tgt_i
}

# ------------------------------------------------------------------------------
# Files and tools
# ------------------------------------------------------------------------------
same_file() {
    if command -v cmp >/dev/null 2>&1; then
        cmp -s "$1" "$2"
    else
        [[ "$(sha256sum "$1" | cut -d' ' -f1)" == "$(sha256sum "$2" | cut -d' ' -f1)" ]]
    fi
}

# need_root_file SRC DEST [MODE] — system file identical to the repo copy
need_root_file() {
    local src="$SF_ROOT/$1" dest="$2" mode="${3:-644}"
    _rf2_t() { [[ -f "$dest" ]] && same_file "$src" "$dest"; }
    _rf2_i() {
        [[ -f "$dest" ]] && as_root cp -a "$dest" "$dest.superfedora-backup"
        as_root install -D -m "$mode" "$src" "$dest"
    }
    need "$dest" _rf2_t _rf2_i
}

# need_script_tool LABEL BINARY URL [SHELL] [ARGS...] — curl-piped vendor installer
need_script_tool() {
    local label="$1" bin="$2" url="$3" sh="${4:-bash}"
    shift 4 2>/dev/null || shift $#
    local -a args=("$@")
    _st_t() {
        command -v "$bin" >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/$bin" || -x "$HOME/.minimax-code/bin/$bin" || -x "$HOME/.grok/bin/$bin" || -x "$HOME/.cargo/bin/$bin" ]]
    }
    _st_i() {
        local attempt
        for attempt in 1 2 3; do
            if curl -fsSL --retry 3 "$url" | "$sh" -s -- "${args[@]}"; then break; fi
            sleep "$attempt"
        done
        mkdir -p "$HOME/.local/bin"
        for dir in "$HOME/.minimax-code/bin" "$HOME/.grok/bin" "$HOME/.cargo/bin"; do
            if [[ -x "$dir/$bin" && ! -e "$HOME/.local/bin/$bin" ]]; then
                ln -sf "$dir/$bin" "$HOME/.local/bin/$bin"
            fi
        done
        hash -r 2>/dev/null || true
        _st_t
    }
    need "$label" _st_t _st_i
}

# manual LABEL TEST_FN HOWTO — can't be automated; report status and instructions
manual() {
    local label="$1" test_fn="$2" howto="$3"
    if "$test_fn"; then r_ok "$label"; else r_manual "$label: $howto"; fi
}
