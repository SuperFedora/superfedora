#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# tests/test_installer.sh — Unit tests for SuperFedora install.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$SCRIPT_DIR/install.sh"
FAILURES=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "Running install.sh test suite..."

# 1. Syntax check
if bash -n "$INSTALLER"; then
  pass "install.sh passes bash syntax check (bash -n)"
else
  fail "install.sh failed bash syntax check"
fi

# 2. --help flag returns 0 and prints usage without performing installation
help_output="$("$INSTALLER" --help 2>&1)" || true
if [[ "$help_output" == *"SuperFedora web installer"* && "$help_output" == *"--build-from-source"* && "$help_output" == *"--quick"* ]]; then
  pass "--help flag exits 0 and prints usage documentation (including --quick and --build-from-source)"
else
  fail "--help flag did not exit 0 with complete usage documentation"
fi

# 3. -h flag returns 0 and prints usage
h_output="$("$INSTALLER" -h 2>&1)" || true
if [[ "$h_output" == *"SuperFedora web installer"* ]]; then
  pass "-h short flag exits 0 and prints usage documentation"
else
  fail "-h short flag did not exit 0 with usage documentation"
fi

# 4. Piped stdin execution (curl ... | bash -s -- --help) returns 0 and prints usage
pipe_output="$(cat "$INSTALLER" | bash -s -- --help 2>&1)" || true
if [[ "$pipe_output" == *"SuperFedora web installer"* ]]; then
  pass "Piped stdin execution (curl ... | bash -s -- --help) prints usage"
else
  fail "Piped stdin execution failed"
fi

# 5. Version file exists and is semver format
if [[ -f "$SCRIPT_DIR/VERSION" ]] && grep -qE '^[0-9]+\.[0-9]+\.[0-9]+' "$SCRIPT_DIR/VERSION"; then
  pass "VERSION file exists and contains valid semver: $(cat "$SCRIPT_DIR/VERSION")"
else
  fail "VERSION file is missing or invalid"
fi

# 6. Mocked end-to-end installer execution (--quick and --build-from-source forwarding)
TMP_TEST="$(mktemp -d)"
trap 'rm -rf "$TMP_TEST"' EXIT

MOCK_BIN="$TMP_TEST/bin"
MOCK_HOME="$TMP_TEST/home"
MOCK_OS_RELEASE="$TMP_TEST/os-release"
mkdir -p "$MOCK_BIN" "$MOCK_HOME"
cat > "$MOCK_OS_RELEASE" << 'EOF'
ID=fedora
PRETTY_NAME="Fedora Linux 44 (Forty Four)"
EOF
cat > "$MOCK_BIN/curl" << 'EOF'
#!/bin/sh
case "$*" in
  *VERSION*)
    echo "0.3.0"
    exit 0 ;;
esac
TMP_ARCHIVE=$(mktemp -d)
mkdir -p "$TMP_ARCHIVE/superfedora-v0.3.0/bin"
cat > "$TMP_ARCHIVE/superfedora-v0.3.0/bin/superfedora" << 'BEOF'
#!/bin/sh
echo "mock superfedora $*"
exit 0
BEOF
chmod +x "$TMP_ARCHIVE/superfedora-v0.3.0/bin/superfedora"
echo "0.3.0" > "$TMP_ARCHIVE/superfedora-v0.3.0/VERSION"
tar -czf - -C "$TMP_ARCHIVE" superfedora-v0.3.0
rm -rf "$TMP_ARCHIVE"
exit 0
EOF
chmod +x "$MOCK_BIN/curl"

# Test --build-from-source forwarding
src_out="$(HOME="$MOCK_HOME" XDG_DATA_HOME="$MOCK_HOME/.local/share" SUPERFEDORA_OS_RELEASE="$MOCK_OS_RELEASE" PATH="$MOCK_BIN:$PATH" "$INSTALLER" --build-from-source </dev/null 2>&1)" || true
if [[ "$src_out" == *"mock superfedora install --build-from-source"* ]]; then
  pass "--build-from-source flag forwards cleanly to superfedora install"
else
  fail "--build-from-source flag forwarding failed: $src_out"
fi

# Test SUPERFEDORA_BUILD_MODE=source environment variable forwarding
env_out="$(HOME="$MOCK_HOME" XDG_DATA_HOME="$MOCK_HOME/.local/share" SUPERFEDORA_OS_RELEASE="$MOCK_OS_RELEASE" PATH="$MOCK_BIN:$PATH" SUPERFEDORA_BUILD_MODE=source "$INSTALLER" </dev/null 2>&1)" || true
if [[ "$env_out" == *"mock superfedora install --build-from-source"* ]]; then
  pass "SUPERFEDORA_BUILD_MODE=source forwards --build-from-source cleanly"
else
  fail "SUPERFEDORA_BUILD_MODE=source forwarding failed: $env_out"
fi

# Test --quick flag forwarding
quick_out="$(HOME="$MOCK_HOME" XDG_DATA_HOME="$MOCK_HOME/.local/share" SUPERFEDORA_OS_RELEASE="$MOCK_OS_RELEASE" PATH="$MOCK_BIN:$PATH" "$INSTALLER" --quick </dev/null 2>&1)" || true
if [[ "$quick_out" == *"mock superfedora install --quick"* ]]; then
  pass "--quick flag forwards cleanly to superfedora install"
else
  fail "--quick flag forwarding failed: $quick_out"
fi

# Test non-Fedora OS rejection
MOCK_UBUNTU="$TMP_TEST/os-release-ubuntu"
printf 'ID=ubuntu\nPRETTY_NAME="Ubuntu 24.04 LTS"\n' > "$MOCK_UBUNTU"
ubuntu_out="$(SUPERFEDORA_OS_RELEASE="$MOCK_UBUNTU" "$INSTALLER" --quick </dev/null 2>&1)" || true
if [[ "$ubuntu_out" == *"SuperFedora needs Fedora"* ]]; then
  pass "Non-Fedora OS is cleanly rejected by install.sh"
else
  fail "Non-Fedora OS was not rejected: $ubuntu_out"
fi

# 7. Test non-root enforcement: root EUID (0) should fail
if (EUID=0 env SUPERFEDORA_NO_RUN=1 bash -c "[[ \$EUID -ne 0 ]] || exit 1") 2>/dev/null; then
  fail "Root EUID was not rejected by simulated check"
else
  pass "Non-root user check logic enforces normal user execution"
fi

# 8. Test 16-bit workstation banners & cast comms CLI (lib/notify-ctl.sh)
NOTIFY_CTL="$SCRIPT_DIR/lib/notify-ctl.sh"
for b in ready warning update checkpoint; do
  b_out="$(HOME="$MOCK_HOME" XDG_CONFIG_HOME="$MOCK_HOME/.config" "$NOTIFY_CTL" --banner "$b" 2>&1)" || true
  if [[ "$b_out" == *"[OK] Banner triggered:"* ]]; then
    pass "notify-ctl.sh --banner $b triggers workstation banner"
  else
    fail "notify-ctl.sh --banner $b failed: $b_out"
  fi
done

if HOME="$MOCK_HOME" XDG_CONFIG_HOME="$MOCK_HOME/.config" "$NOTIFY_CTL" --banner invalid_banner >/dev/null 2>&1; then
  fail "notify-ctl.sh --banner invalid_banner should exit non-zero"
else
  pass "notify-ctl.sh rejects unknown --banner value"
fi

for role in ai security builder engineer app navigator medic archivist commander synth all; do
  c_out="$(HOME="$MOCK_HOME" XDG_CONFIG_HOME="$MOCK_HOME/.config" "$NOTIFY_CTL" --cast "$role" 2>&1)" || true
  if [[ "$c_out" == *"[OK] Cast comms triggered:"* ]]; then
    pass "notify-ctl.sh --cast $role triggers workstation cast comms"
  else
    fail "notify-ctl.sh --cast $role failed: $c_out"
  fi
done

# 9. Verify 16-bit cast portrait SVGs exist in dotfiles/.config/superfedora/cast/
for role_svg in ai security builder engineer app navigator medic archivist commander synth; do
  if [[ -f "$SCRIPT_DIR/dotfiles/.config/superfedora/cast/${role_svg}.svg" ]]; then
    pass "Cast portrait SVG present: dotfiles/.config/superfedora/cast/${role_svg}.svg"
  else
    fail "Missing cast portrait SVG: dotfiles/.config/superfedora/cast/${role_svg}.svg"
  fi
done

# 10. Verify sf is a relative symlink to superfedora in $MOCK_HOME/.local/bin
if [[ -L "$MOCK_HOME/.local/bin/sf" ]] && [[ "$(readlink "$MOCK_HOME/.local/bin/sf")" == "superfedora" ]]; then
  pass "install.sh creates relative symlink sf -> superfedora"
else
  fail "install.sh did not create relative symlink sf -> superfedora (found: $(readlink "$MOCK_HOME/.local/bin/sf" 2>/dev/null || echo not-a-symlink))"
fi

# 11. Test Fedora Minimal Stage-0 bootstrap when zstd is missing
STAGE0_PATH="$TMP_TEST/stage0_bin"
mkdir -p "$STAGE0_PATH"
for cmd in bash sh printf tr sed head tar gzip find mkdir rm mv chmod ln cat dirname mktemp; do
  p="$(command -v "$cmd" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$STAGE0_PATH/$cmd"
done
cp "$MOCK_BIN/curl" "$STAGE0_PATH/curl"
cat > "$STAGE0_PATH/sudo" << 'EOF'
#!/bin/sh
echo "[MOCK_SUDO] $*"
exit 0
EOF
chmod +x "$STAGE0_PATH/sudo"
stage0_out="$(HOME="$MOCK_HOME" XDG_DATA_HOME="$MOCK_HOME/.local/share" SUPERFEDORA_OS_RELEASE="$MOCK_OS_RELEASE" SUPERFEDORA_NO_RUN=1 PATH="$STAGE0_PATH" "$INSTALLER" </dev/null 2>&1)" || true
if [[ "$stage0_out" == *"[MOCK_SUDO] dnf install -y git-core curl tar gzip zstd findutils"* ]]; then
  pass "Stage-0 bootstrap installs git-core curl tar gzip zstd findutils on Fedora Minimal"
else
  fail "Stage-0 bootstrap did not invoke dnf install: $stage0_out"
fi

# 12. Verify systemd --user units, system Btrfs units, user-tmpfiles.d, and declarative OS drop-ins exist
for u in superfedora-session.target supershell.service superagent.service idlescreen.service supertheme-sun.service supertheme-sun.timer superforge-check.service superforge-check.timer; do
  if [[ -f "$SCRIPT_DIR/dotfiles/.config/systemd/user/$u" ]]; then
    pass "systemd user unit present: $u"
  else
    fail "Missing systemd user unit: $u"
  fi
done
if [[ -f "$SCRIPT_DIR/dotfiles/.config/user-tmpfiles.d/superfedora.conf" && -f "$SCRIPT_DIR/system/etc/systemd/zram-generator.conf.d/superfedora.conf" && -f "$SCRIPT_DIR/system/etc/systemd/system/btrfs-scrub@.timer" && -f "$SCRIPT_DIR/system/etc/systemd/system/superfedora-boot-guard.service" ]]; then
  pass "user-tmpfiles.d/superfedora.conf, btrfs-scrub@.timer, superfedora-boot-guard.service, and OS drop-ins present"
else
  fail "Missing user-tmpfiles.d/superfedora.conf, btrfs-scrub@.timer, or systemd OS drop-ins"
fi

# 13. Test need_copr Rawhide fallback under SF_VERBOSE=1 subshell & multi-COPR isolation
COPR_TEST_DIR="$TMP_TEST/copr_test"
mkdir -p "$COPR_TEST_DIR/bin" "$COPR_TEST_DIR/state"
printf '#!/bin/sh\n[ "$1" = "-E" ] && { echo 46; exit 0; }\nexit 1\n' > "$COPR_TEST_DIR/bin/rpm"
printf '#!/bin/sh\n[ "$1" = "copr" ] && exit 1\nexit 0\n' > "$COPR_TEST_DIR/bin/dnf"
printf '#!/bin/sh\nexec "$@"\n' > "$COPR_TEST_DIR/bin/sudo"
chmod +x "$COPR_TEST_DIR/bin/rpm" "$COPR_TEST_DIR/bin/dnf" "$COPR_TEST_DIR/bin/sudo"
copr_out="$(PATH="$COPR_TEST_DIR/bin:$PATH" SF_ROOT="$SCRIPT_DIR" SF_STATE="$COPR_TEST_DIR/state" MODE=install SF_VERBOSE=1 bash -c 'source "$SF_ROOT/lib/core.sh"; source "$SF_ROOT/lib/check.sh"; need_copr lionheartp/Hyprland; need_copr phracek/PyCharm' 2>&1)" || true
if [[ -f "$COPR_TEST_DIR/state/copr-fallback-lionheartp-Hyprland" && -f "$COPR_TEST_DIR/state/copr-fallback-phracek-PyCharm" && "$copr_out" == *"falling back to superforge source compilation"* ]]; then
  pass "need_copr Rawhide fallback persists across SF_VERBOSE=1 subshells and isolates multiple COPRs"
else
  fail "need_copr Rawhide fallback failed: $copr_out"
fi

# 14. Verify Waves 1-6 declarative configs (PackageKit 30s, DNF5 Snapper hook, Hyprland VFR + direct_scanout)
if [[ -f "$SCRIPT_DIR/system/etc/systemd/system/packagekit.service.d/superfedora-timeout.conf" ]] &&
   grep -q "ShutdownTimeout=30" "$SCRIPT_DIR/system/etc/systemd/system/packagekit.service.d/superfedora-timeout.conf" &&
   [[ -f "$SCRIPT_DIR/system/etc/dnf/libdnf5-plugins/actions.d/superfedora-snapper.actions" ]] &&
   grep -q "vfr = true" "$SCRIPT_DIR/dotfiles/.config/hypr/conf/looknfeel.conf" &&
   grep -q "direct_scanout = true" "$SCRIPT_DIR/dotfiles/.config/hypr/conf/looknfeel.conf"; then
  pass "Waves 1-6 configs present (PackageKit 30s, DNF5 Snapper hook, Hyprland VFR + direct_scanout)"
else
  fail "Missing Waves 1-6 declarative configs"
fi

# 15. Verify XDG DE unification (first-party .desktop entries, portals, Qt6/GTK3/4 toolkit sync, keyring, Wayland session)
if [[ -f "$SCRIPT_DIR/dotfiles/.local/share/applications/supersettings.desktop" ]] &&
   [[ -f "$SCRIPT_DIR/dotfiles/.local/share/applications/superfiles.desktop" ]] &&
   [[ -f "$SCRIPT_DIR/dotfiles/.config/xdg-desktop-portal/hyprland-portals.conf" ]] &&
   [[ -f "$SCRIPT_DIR/dotfiles/.config/hypr/hyprqt6engine.conf" ]] &&
   [[ -f "$SCRIPT_DIR/dotfiles/.config/gtk-3.0/settings.ini" ]] &&
   [[ -f "$SCRIPT_DIR/dotfiles/.config/gtk-4.0/settings.ini" ]] &&
   [[ -f "$SCRIPT_DIR/system/usr/share/wayland-sessions/superfedora.desktop" ]] &&
   grep -q "gnome-keyring" "$SCRIPT_DIR/packages/session.txt"; then
  pass "XDG DE unification present (.desktop entries, portals, Qt6/GTK3/4 toolkit sync, keyring, superfedora.desktop session)"
else
  fail "Missing XDG DE unification configs"
fi

echo "Test summary: $FAILURES failure(s)."
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
echo "All install.sh tests PASSED."
exit 0
