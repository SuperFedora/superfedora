# shellcheck shell=bash
# ==============================================================================
# lib/core.sh — shared state, logging and privilege helpers
# ==============================================================================
# Every module calls the same idempotent helpers (lib/check.sh). What those
# helpers do depends on the global MODE:
#   install  check each item; install only what is missing
#   status   check and report only (never changes the system)
#   dry-run  check and report what install would do
# ==============================================================================

MODE="${MODE:-status}"
SF_ROOT="${SF_ROOT:?SF_ROOT must point at the SuperFedora source tree}"
SF_VERSION="$(tr -d '[:space:]' < "$SF_ROOT/VERSION" 2>/dev/null || echo unknown)"
SF_STATE="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
SF_LOG="$SF_STATE/install.log"

# Counters for the final summary
SF_OK=0 SF_ADDED=0 SF_MISSING=0 SF_FAILED=0 SF_MANUAL=0
SF_FAILURES=()
SF_MANUAL_ITEMS=()

if [[ -t 1 && "${NO_COLOR:-}" != 1 ]]; then
    C_B=$'\033[1m' C_DIM=$'\033[2m' C_R=$'\033[0m'
    C_GRN=$'\033[32m' C_YLW=$'\033[33m' C_RED=$'\033[31m' C_BLU=$'\033[34m' C_CYN=$'\033[36m'
else
    C_B="" C_DIM="" C_R="" C_GRN="" C_YLW="" C_RED="" C_BLU="" C_CYN=""
fi

_log_file() { [[ -d "$SF_STATE" ]] && printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$SF_LOG"; return 0; }

section() { printf '\n%s━━ %s%s\n' "$C_B$C_BLU" "$*" "$C_R"; _log_file "== $*"; }
info()    { printf '  %s·%s %s\n' "$C_DIM" "$C_R" "$*"; _log_file "info $*"; }
warn()    { printf '  %s!%s %s\n' "$C_YLW" "$C_R" "$*"; _log_file "warn $*"; }
die()     { printf '%serror:%s %s\n' "$C_RED$C_B" "$C_R" "$*" >&2; _log_file "error $*"; exit 1; }

# Item results (one line per checked item)
r_ok()      { SF_OK=$((SF_OK + 1));           printf '  %s✓%s %s\n' "$C_GRN" "$C_R" "$*"; }
r_added()   { SF_ADDED=$((SF_ADDED + 1));     printf '  %s+%s %s\n' "$C_CYN" "$C_R" "$*"; _log_file "added $*"; }
r_missing() { SF_MISSING=$((SF_MISSING + 1)); printf '  %s✗%s %s\n' "$C_YLW" "$C_R" "$*"; }
r_failed()  { SF_FAILED=$((SF_FAILED + 1));   SF_FAILURES+=("$*"); printf '  %s✗ FAILED%s %s\n' "$C_RED" "$C_R" "$*"; _log_file "failed $*"; }
r_manual()  { SF_MANUAL=$((SF_MANUAL + 1));   SF_MANUAL_ITEMS+=("$*"); printf '  %s?%s %s %s(manual)%s\n' "$C_YLW" "$C_R" "$*" "$C_DIM" "$C_R"; }

# "would install" in dry-run, "missing" in status
r_need() {
    if [[ "$MODE" == dry-run ]]; then
        SF_MISSING=$((SF_MISSING + 1)); printf '  %s→%s would install %s\n' "$C_CYN" "$C_R" "$*"
    else
        r_missing "$*"
    fi
}

is_install() { [[ "$MODE" == install ]]; }

# Run a command as root (the installer itself runs as the target user)
as_root() {
    if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# Run a command, logging output; returns its status
run_logged() {
    _log_file "run $*"
    if [[ -n "${SF_VERBOSE:-}" ]]; then
        "$@" 2>&1 | tee -a "$SF_LOG"
        return "${PIPESTATUS[0]}"
    fi
    "$@" >> "$SF_LOG" 2>&1
}

summary() {
    printf '\n%s━━ Summary (SuperFedora v%s, %s)%s\n' "$C_B" "$SF_VERSION" "$MODE" "$C_R"
    printf '  %s✓ %d present%s' "$C_GRN" "$SF_OK" "$C_R"
    [[ $SF_ADDED -gt 0 ]]   && printf '   %s+ %d installed%s' "$C_CYN" "$SF_ADDED" "$C_R"
    if [[ $SF_MISSING -gt 0 ]]; then
        if [[ "$MODE" == dry-run ]]; then printf '   %s→ %d to install%s' "$C_CYN" "$SF_MISSING" "$C_R"
        else printf '   %s✗ %d missing%s' "$C_YLW" "$SF_MISSING" "$C_R"; fi
    fi
    [[ $SF_MANUAL -gt 0 ]]  && printf '   %s? %d manual%s' "$C_YLW" "$SF_MANUAL" "$C_R"
    [[ $SF_FAILED -gt 0 ]]  && printf '   %s✗ %d failed%s' "$C_RED" "$SF_FAILED" "$C_R"
    printf '\n'
    if [[ $SF_MANUAL -gt 0 ]]; then
        printf '\n  Manual steps:\n'
        printf '    - %s\n' "${SF_MANUAL_ITEMS[@]}"
    fi
    if [[ $SF_FAILED -gt 0 ]]; then
        printf '\n  %sFailures%s (details in %s):\n' "$C_RED" "$C_R" "$SF_LOG"
        printf '    - %s\n' "${SF_FAILURES[@]}"
    fi
}
