#!/usr/bin/env bash
# ==============================================================================
# SuperFedora web installer
#
#   curl -fsSL https://superfedora.github.io/install.sh | bash
#   curl -fsSL https://superfedora.github.io/install.sh | bash -s -- --dry-run
#
# Start from a Fedora "Minimal Install" (Everything netinstall) or any existing
# Fedora system. This script:
#   1. checks that this is Fedora and that you can use sudo
#   2. downloads the latest SuperFedora release to ~/.local/share/superfedora
#   3. installs the `superfedora` and `sf` commands to ~/.local/bin
#   4. runs `superfedora install`, which checks every component and installs
#      only what is missing (safe to re-run at any time)
#
# Arguments:
#   -h, --help                   show this help message
#   --dry-run                    preview what would be installed without changes
#   --only <modules>             run only specified modules (e.g. 40,desktop)
#   --skip <modules>             skip specified modules
#   -v, --verbose                show verbose command execution
#
# Environment:
#   SUPERFEDORA_VERSION=v0.1.0   install a specific release (default: latest)
#   SUPERFEDORA_REF=main         install a branch instead of a release
#   SUPERFEDORA_NO_RUN=1         fetch and install the command only
#   SUPERFEDORA_ARGS="--dry-run" extra arguments for `superfedora install`
# ==============================================================================
set -euo pipefail

usage() {
    cat << 'EOF'
==============================================================================
SuperFedora web installer

  curl -fsSL https://superfedora.github.io/install.sh | bash
  curl -fsSL https://superfedora.github.io/install.sh | bash -s -- --dry-run

Start from a Fedora "Minimal Install" (Everything netinstall) or any existing
Fedora system. This script:
  1. checks that this is Fedora and that you can use sudo
  2. downloads the latest SuperFedora release to ~/.local/share/superfedora
  3. installs the `superfedora` and `sf` commands to ~/.local/bin
  4. runs `superfedora install`, which checks every component and installs
     only what is missing (safe to re-run at any time)

Arguments:
  -h, --help                   show this help message
  --dry-run                    preview what would be installed without changes
  --only <modules>             run only specified modules (e.g. 40,desktop)
  --skip <modules>             skip specified modules
  -v, --verbose                show verbose command execution

Environment:
  SUPERFEDORA_VERSION=v0.2.0   install a specific release (default: latest)
  SUPERFEDORA_REF=main         install a branch instead of a release
  SUPERFEDORA_NO_RUN=1         fetch and install the command only
  SUPERFEDORA_ARGS="--dry-run" extra arguments for `superfedora install`
==============================================================================
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
esac

REPO="SuperFedora/superfedora"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/superfedora"
BIN_DIR="$HOME/.local/bin"

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------------------------
[[ -r /etc/os-release ]] && . /etc/os-release
[[ "${ID:-}" == fedora ]] || fail "SuperFedora needs Fedora (found ${PRETTY_NAME:-unknown})"
[[ $EUID -ne 0 ]] || fail "run this as your normal user, not root (sudo is used when needed)"
command -v sudo >/dev/null || fail "sudo is not installed; as root run: dnf install -y sudo && usermod -aG wheel $USER"
command -v curl >/dev/null || fail "curl is required"

# tar + gzip are not part of every minimal image
if ! command -v tar >/dev/null || ! command -v gzip >/dev/null; then
    say "installing tar and gzip…"
    sudo dnf install -y tar gzip
fi

# ------------------------------------------------------------------------------
if [[ -n "${SUPERFEDORA_REF:-}" ]]; then
    REF="$SUPERFEDORA_REF"
    URL="https://github.com/$REPO/archive/refs/heads/$REF.tar.gz"
else
    REF="${SUPERFEDORA_VERSION:-}"
    if [[ -z "$REF" ]]; then
        # 1. Fast, un-rate-limited CDN resolution from superfedora.github.io
        REF="$(curl -fsSL "https://superfedora.github.io/VERSION" 2>/dev/null | tr -d '[:space:]' || true)"
        if [[ -n "$REF" ]]; then
            [[ "$REF" =~ ^v ]] || REF="v$REF"
        else
            # 2. Fallback to GitHub REST API
            REF="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
                   | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
        fi
        [[ -n "$REF" ]] || fail "could not determine the latest release (network or GitHub API error)"
    fi
    URL="https://github.com/$REPO/archive/refs/tags/$REF.tar.gz"
fi

say "downloading SuperFedora $REF…"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" | tar -xz -C "$TMP" || fail "download failed: $URL"
SRC="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"
[[ -x "$SRC/bin/superfedora" ]] || fail "release $REF does not contain bin/superfedora"

mkdir -p "$(dirname "$DEST")" "$BIN_DIR"
rm -rf "$DEST.new"
mv "$SRC" "$DEST.new"
rm -rf "$DEST"
mv "$DEST.new" "$DEST"

cat > "$BIN_DIR/superfedora" <<EOF
#!/bin/sh
# Installed by the SuperFedora web installer. Source: $DEST
exec "$DEST/bin/superfedora" "\$@"
EOF
chmod +x "$BIN_DIR/superfedora"
ln -sf "$BIN_DIR/superfedora" "$BIN_DIR/sf"
say "installed SuperFedora $(cat "$DEST/VERSION") → $BIN_DIR/sf (and $BIN_DIR/superfedora)"

[[ "${SUPERFEDORA_NO_RUN:-}" == 1 ]] && exit 0

# ------------------------------------------------------------------------------
# Collect arguments to forward to `superfedora install`
FORWARD_ARGS=()
if [[ -n "${SUPERFEDORA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    FORWARD_ARGS+=($SUPERFEDORA_ARGS)
fi
FORWARD_ARGS+=("$@")

# Re-attach stdin to the terminal so sudo can prompt when piped from curl
if [[ -t 1 && -r /dev/tty ]]; then
    exec "$BIN_DIR/superfedora" install "${FORWARD_ARGS[@]}" < /dev/tty
else
    exec "$BIN_DIR/superfedora" install "${FORWARD_ARGS[@]}"
fi
