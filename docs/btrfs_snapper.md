# Btrfs & Snapper Snapshot Architecture

This document details the filesystem layout, automated snapshot mechanisms, DNF5 transaction hooks, and rollback procedures implemented on **Fedora Linux 44**.

---

## 1. Filesystem & Snapshot Architecture

The host filesystem runs on **Btrfs** (`/` on `/dev/mapper/luks-...` or native nvme subvolume).
To ensure safety during system updates and package operations, **Snapper** is configured to automate snapshots.

### Snapshot Policies & Configuration: `/etc/snapper/configs/root`

```ini
# Subvolume path
SUBVOLUME="/"

# Permissions allowing workstation user and wheel group management without sudo
ALLOW_USERS="$USER"
ALLOW_GROUPS="wheel"
SYNC_ACL="yes"

# Timeline Snapshot Limits (Periodic snapshots)
TIMELINE_CREATE="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="2"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"

# DNF Transaction Snapshot Limits (Pre/Post pairs)
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="5"

# Disable QGroups (Prevents severe Btrfs performance degradation on large snapshot sets)
QGROUP=""
```

---

## 2. Automated DNF5 Transaction Snapshots

When packages are installed, updated, or removed using Fedora 44's `dnf5`, snapshot hooks are executed automatically via `libdnf5-plugin-actions`.

Configuration location: `/etc/dnf/libdnf5-plugins/actions.d/snapper.actions`
```ini
# Snapshots before and after DNF5 package transactions
pre_transaction::::/usr/bin/sh -c 'echo "tmp.cmd=$(ps -o command --no-headers -p ${pid})"'
pre_transaction::::/usr/bin/sh -c 'echo "tmp.snapper_pre_number=$(snapper -c root create -t pre -p -d \"${tmp.cmd}\")"'
post_transaction::::/usr/bin/sh -c '[ -n "${tmp.snapper_pre_number}" ] && snapper -c root create -t post --pre-number "${tmp.snapper_pre_number}" -d "${tmp.cmd}"'
```

Every `dnf install`, `dnf update`, or `dnf rm` creates:
1. A **Pre** snapshot capturing the state immediately before transaction execution.
2. A **Post** snapshot linked directly to the Pre snapshot ID, capturing the delta.

---

## 3. Systemd Automation Timers

The following timers run in the background to handle periodic snapshot creation and automated pruning:

```bash
# Check status of Snapper timers
systemctl status snapper-timeline.timer
systemctl status snapper-cleanup.timer
```

- `snapper-timeline.timer`: Triggers hourly snapshot generation.
- `snapper-cleanup.timer`: Runs daily cleanup tasks to prune snapshots outside retention policies (`TIMELINE_LIMIT_*` and `NUMBER_LIMIT`).

---

## 4. Disaster Recovery & Rollback Playbook

### 4.1 Listing Existing Snapshots
```bash
snapper -c root list
```
Output columns indicate:
- `#`: Snapshot index number
- `Type`: `single`, `pre`, `post`
- `Pre #`: Linked pre-transaction ID
- `Date`: Timestamp
- `Description`: The command or reason (e.g., `dnf install kitty`, `Baseline Setup`, `timeline`)

### 4.2 Inspecting Differences Between Snapshots
To compare files changed between a pre/post transaction:
```bash
# Show file list
snapper -c root status <pre_num>..<post_num>

# Show line-by-line diff of modifications
snapper -c root diff <pre_num>..<post_num>
```

### 4.3 Reverting Specific Files
To revert modified files between two snapshots without rolling back the entire operating system:
```bash
snapper -c root undochange <pre_num>..<post_num> /path/to/file
```

### 4.4 Full Root Rollback
If an update renders the system unbootable or unstable:
1. Boot into an earlier snapshot from the GRUB boot menu or rescue environment.
2. Once booted into the working snapshot:
   ```bash
   sudo snapper -c root rollback
   ```
3. Reboot into the restored baseline:
   ```bash
   sudo reboot
   ```

### 4.5 Graphical Management: Btrfs Assistant
A desktop application is installed to visually inspect subvolumes, timeline graphs, and manage rollbacks:
```bash
btrfs-assistant
```
Available in GNOME / Hyprland application launchers.

### 4.6 SuperFedora Turnkey Rollback & Uninstall
The SuperFedora installer records the pre-installation baseline snapshot ID in `~/.config/superfedora/last_pre_install_snapshot`.
To revert all changes made during installation:
```bash
superfedora rollback
```
This automates `snapper undochange` back to the baseline snapshot and purges installed desktop dotfiles.

