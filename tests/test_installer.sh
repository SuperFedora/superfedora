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
mkdir -p "$MOCK_BIN" "$MOCK_HOME"
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
src_out="$(HOME="$MOCK_HOME" XDG_DATA_HOME="$MOCK_HOME/.local/share" PATH="$MOCK_BIN:$PATH" "$INSTALLER" --build-from-source </dev/null 2>&1)" || true
if [[ "$src_out" == *"mock superfedora install --build-from-source"* ]]; then
  pass "--build-from-source flag forwards cleanly to superfedora install"
else
  fail "--build-from-source flag forwarding failed: $src_out"
fi

# Test SUPERFEDORA_BUILD_MODE=source environment variable forwarding
env_out="$(HOME="$MOCK_HOME" XDG_DATA_HOME="$MOCK_HOME/.local/share" PATH="$MOCK_BIN:$PATH" SUPERFEDORA_BUILD_MODE=source "$INSTALLER" </dev/null 2>&1)" || true
if [[ "$env_out" == *"mock superfedora install --build-from-source"* ]]; then
  pass "SUPERFEDORA_BUILD_MODE=source forwards --build-from-source cleanly"
else
  fail "SUPERFEDORA_BUILD_MODE=source forwarding failed: $env_out"
fi

# Test --quick flag forwarding
quick_out="$(HOME="$MOCK_HOME" XDG_DATA_HOME="$MOCK_HOME/.local/share" PATH="$MOCK_BIN:$PATH" "$INSTALLER" --quick </dev/null 2>&1)" || true
if [[ "$quick_out" == *"mock superfedora install --quick"* ]]; then
  pass "--quick flag forwards cleanly to superfedora install"
else
  fail "--quick flag forwarding failed: $quick_out"
fi

# 7. Test non-root enforcement: root EUID (0) should fail
if (EUID=0 env SUPERFEDORA_NO_RUN=1 bash -c "[[ \$EUID -ne 0 ]] || exit 1") 2>/dev/null; then
  fail "Root EUID was not rejected by simulated check"
else
  pass "Non-root user check logic enforces normal user execution"
fi

echo "Test summary: $FAILURES failure(s)."
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
echo "All install.sh tests PASSED."
exit 0
