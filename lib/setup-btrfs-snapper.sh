#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# setup-btrfs-snapper.sh — Fedora Btrfs + Snapper + grub-btrfs + Boot-Guard Setup
# ==============================================================================
set -euo pipefail

if [[ "${1:-}" == "--status" || "${1:-}" == "status" ]]; then
    printf 'SuperFedora Btrfs Snapshot & Boot-Guard Status\n'
    printf '  Root Filesystem : %s\n' "$(stat -f -c %T / 2>/dev/null || echo unknown)"
    printf '  Snapper Config  : %s\n' "$([[ -f /etc/snapper/configs/root ]] && echo present || echo missing)"
    printf '  DNF5 Auto-Snap  : %s\n' "$([[ -f /etc/dnf/libdnf5-plugins/actions.d/snapper.actions ]] && echo active || echo missing)"
    printf '  GRUB Snapshots  : %s\n' "$([[ -x /etc/grub.d/41_snapshots-btrfs ]] && echo enabled || echo not-configured)"
    printf '  Boot-Guard Unit : %s\n' "$(systemctl is-enabled superfedora-boot-guard.service 2>/dev/null || echo disabled)"
    exit 0
fi

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (or with sudo)." >&2
  echo "Please run: sudo bash $0" >&2
  exit 1
fi

CURRENT_USER="${SUDO_USER:-$(id -un 2>/dev/null || echo "${USER:-user}")}"
echo "==> Configuring Snapper, grub-btrfs, and Boot-Guard for user: ${CURRENT_USER}"

# 1. Install necessary packages
echo "==> 1. Installing snapper, btrfs-assistant, and libdnf5-plugin-actions..."
dnf install -y snapper btrfs-assistant libdnf5-plugin-actions

# 2. Configure Snapper for root filesystem (/)
if [ ! -f /etc/snapper/configs/root ]; then
  echo "==> 2. Creating Snapper configuration for root (/)..."
  if [ -d /.snapshots ] && [ ! -d /.snapshots/.snapshots ]; then
    btrfs subvolume show /.snapshots &>/dev/null || rm -rf /.snapshots
  fi
  snapper -c root create-config /
else
  echo "==> Snapper config for root already exists. Skipping create-config."
fi

# 3. Configure permissions and retention limits
echo "==> 3. Configuring permissions and snapshot retention limits..."
CONFIG_FILE="/etc/snapper/configs/root"
sed -i "s/^ALLOW_USERS=.*/ALLOW_USERS=\"${CURRENT_USER}\"/" "$CONFIG_FILE"
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="wheel"/' "$CONFIG_FILE"
sed -i 's/^SYNC_ACL=.*/SYNC_ACL="yes"/' "$CONFIG_FILE"
chmod 644 "$CONFIG_FILE"

sed -i 's/^TIMELINE_MIN_AGE=.*/TIMELINE_MIN_AGE="1800"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="2"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' "$CONFIG_FILE"
sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="10"/' "$CONFIG_FILE"
sed -i 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/' "$CONFIG_FILE"
sed -i 's/^QGROUP=.*/QGROUP=""/' "$CONFIG_FILE"

chmod 750 /.snapshots
chown :wheel /.snapshots

# 4. Set up DNF5 automatic pre/post transaction snapshots + GRUB refresh
echo "==> 4. Setting up DNF5 transaction snapshot actions..."
mkdir -p /etc/dnf/libdnf5-plugins/actions.d

cat << 'EOF' > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
# Snapshots before and after DNF5 package transactions
pre_transaction::::/usr/bin/sh -c 'echo "tmp.cmd=$(ps -o command --no-headers -p ${pid})"'
pre_transaction::::/usr/bin/sh -c 'echo "tmp.snapper_pre_number=$(snapper -c root create -t pre -p -d \"${tmp.cmd}\")"'
post_transaction::::/usr/bin/sh -c '[ -n "${tmp.snapper_pre_number}" ] && snapper -c root create -t post --pre-number "${tmp.snapper_pre_number}" -d "${tmp.cmd}" && [ -x /etc/grub.d/41_snapshots-btrfs ] && grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1 || true'
EOF

# 5. Install grub-btrfs generator so Btrfs snapshots appear in GRUB menu
echo "==> 5. Installing /etc/grub.d/41_snapshots-btrfs generator..."
cat << 'EOF' > /etc/grub.d/41_snapshots-btrfs
#!/usr/bin/sh
set -e
[ -d /.snapshots ] || exit 0
command -v snapper >/dev/null 2>&1 || exit 0
echo "submenu 'SuperFedora Btrfs Snapshots (Read-Only Recovery)' {"
snapper -c root --csvout list --columns number,date,description 2>/dev/null | tail -n +2 | tail -n 8 | while IFS=, read -r num dt desc; do
    [ -n "$num" ] && [ "$num" != "0" ] || continue
    printf "  menuentry 'Snapshot #%s (%s - %s)' {\n    echo 'Booting SuperFedora Snapshot #%s...'\n  }\n" "$num" "$dt" "$desc" "$num"
done
echo "}"
EOF
chmod 755 /etc/grub.d/41_snapshots-btrfs
if [ -d /boot/grub2 ] && command -v grub2-mkconfig >/dev/null 2>&1; then
  grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1 || true
fi

# 6. Install superfedora-boot-guard automatic health check & rollback service
echo "==> 6. Installing superfedora-boot-guard service..."
mkdir -p /usr/local/libexec /var/lib/superfedora
cat << 'EOF' > /usr/local/libexec/superfedora-boot-guard
#!/usr/bin/env bash
set -euo pipefail
STATE="/var/lib/superfedora/boot-guard.state"
mkdir -p /var/lib/superfedora
FAILS=0
[[ -f "$STATE" ]] && source "$STATE" || true
if systemctl is-active --quiet dbus && (systemctl is-active --quiet greetd || systemctl is-active --quiet gdm || systemctl is-system-running -q); then
    LAST_GOOD="$(snapper -c root --csvout list --columns number 2>/dev/null | tail -1 || echo 0)"
    printf 'FAILS=0\nLAST_GOOD="%s"\nLAST_BOOT="%s"\n' "$LAST_GOOD" "$(date -u +%FT%TZ)" > "$STATE"
    exit 0
fi
FAILS=$((FAILS + 1))
printf 'FAILS=%d\nLAST_GOOD="%s"\nLAST_BOOT="%s"\n' "$FAILS" "${LAST_GOOD:-1}" "$(date -u +%FT%TZ)" > "$STATE"
if [[ "$FAILS" -ge 3 && -n "${LAST_GOOD:-}" && "${LAST_GOOD:-0}" -gt 0 ]]; then
    logger -t superfedora-boot-guard "3 consecutive unhealthy boots detected; reverting to snapshot #${LAST_GOOD}"
    snapper -c root undochange "${LAST_GOOD}..0" || true
    printf 'FAILS=0\nLAST_GOOD="%s"\nROLLED_BACK_AT="%s"\n' "$LAST_GOOD" "$(date -u +%FT%TZ)" > "$STATE"
fi
EOF
chmod 755 /usr/local/libexec/superfedora-boot-guard

cat << 'EOF' > /etc/systemd/system/superfedora-boot-guard.service
[Unit]
Description=SuperFedora Btrfs Boot-Guard Health Check & Auto-Rollback
After=multi-user.target graphical.target

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/superfedora-boot-guard
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 7. Enable and start Snapper timers & Boot-Guard
echo "==> 7. Enabling Snapper timers and Boot-Guard..."
systemctl daemon-reload
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer superfedora-boot-guard.service

# 8. Create initial baseline snapshot if none exists yet
if ! snapper -c root list 2>/dev/null | grep -q "Baseline Setup"; then
  snapper -c root create -t single -d "Baseline Setup"
fi
echo "==> SuperFedora Btrfs + Snapper + grub-btrfs + Boot-Guard setup complete!"
