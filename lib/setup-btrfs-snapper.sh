#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Fedora Btrfs + Snapper + Btrfs Assistant Setup Script
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (or with sudo)." >&2
  echo "Please run: sudo bash $0" >&2
  exit 1
fi

CURRENT_USER="${SUDO_USER:-$(id -un 2>/dev/null || echo "${USER:-user}")}"
echo "==> Configuring Snapper and Btrfs Assistant for user: ${CURRENT_USER}"

# 1. Install necessary packages
echo "==> 1. Installing snapper, btrfs-assistant, and libdnf5-plugin-actions..."
dnf install -y snapper btrfs-assistant libdnf5-plugin-actions

# 2. Configure Snapper for root filesystem (/)
if [ ! -f /etc/snapper/configs/root ]; then
  echo "==> 2. Creating Snapper configuration for root (/)..."
  # If /.snapshots exists as a non-btrfs directory, back it up or remove it
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

# Allow user and wheel group to manage snapshots without typing sudo every time
sed -i "s/^ALLOW_USERS=.*/ALLOW_USERS=\"${CURRENT_USER}\"/" "$CONFIG_FILE"
sed -i 's/^ALLOW_GROUPS=.*/ALLOW_GROUPS="wheel"/' "$CONFIG_FILE"
sed -i 's/^SYNC_ACL=.*/SYNC_ACL="yes"/' "$CONFIG_FILE"

# Make the config file readable by wheel / current user
chmod 644 "$CONFIG_FILE"

# Sane timeline retention limits to avoid filling up disk
sed -i 's/^TIMELINE_MIN_AGE=.*/TIMELINE_MIN_AGE="1800"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="2"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' "$CONFIG_FILE"
sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' "$CONFIG_FILE"

# Number limit for manual/command snapshots (pre/post)
sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="10"/' "$CONFIG_FILE"
sed -i 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/' "$CONFIG_FILE"

# Ensure qgroups are disabled to prevent Btrfs performance degradation
sed -i 's/^QGROUP=.*/QGROUP=""/' "$CONFIG_FILE"

# Set permissions on /.snapshots so wheel users can browse
chmod 750 /.snapshots
chown :wheel /.snapshots

# 4. Set up DNF5 automatic pre/post transaction snapshots
echo "==> 4. Setting up DNF5 transaction snapshot actions..."
mkdir -p /etc/dnf/libdnf5-plugins/actions.d

cat << 'EOF' > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
# Snapshots before and after DNF5 package transactions
pre_transaction::::/usr/bin/sh -c 'echo "tmp.cmd=$(ps -o command --no-headers -p ${pid})"'
pre_transaction::::/usr/bin/sh -c 'echo "tmp.snapper_pre_number=$(snapper -c root create -t pre -p -d \"${tmp.cmd}\")"'
post_transaction::::/usr/bin/sh -c '[ -n "${tmp.snapper_pre_number}" ] && snapper -c root create -t post --pre-number "${tmp.snapper_pre_number}" -d "${tmp.cmd}"'
EOF

# 5. Enable and start Snapper systemd timers
echo "==> 5. Enabling and starting Snapper systemd timers..."
systemctl daemon-reload
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

# 6. Verify and create initial baseline snapshot
echo "==> 6. Creating initial baseline snapshot..."
snapper -c root create -t single -d "Baseline Setup"

echo "=============================================================================="
echo " Setup complete!"
echo " - Snapper configuration: /etc/snapper/configs/root"
echo " - DNF5 auto-snapshot action: /etc/dnf/libdnf5-plugins/actions.d/snapper.actions"
echo " - Systemd timers active: snapper-timeline.timer, snapper-cleanup.timer"
echo " - Btrfs Assistant GUI is installed and ready in your GNOME Applications."
echo "=============================================================================="
snapper -c root list
