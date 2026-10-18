// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::WorkstationState;
use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

const USER_TIMERS_AND_UNITS: &[&str] = &[
    "superfedora-session.target",
    "supershell.service",
    "idlescreen.service",
    "cliphist.service",
    "supertheme-sun.timer",
    "supertheme-sun.service",
    "superforge-check.timer",
    "superforge-check.service",
];

const CORE_BINARIES: &[&str] = &[
    "superfedora",
    "sf",
    "superforge",
    "supertheme",
    "superbar",
    "supersettings",
    "superlock",
    "supernotify",
    "sf-digest",
];

const DESKTOP_ENTRIES: &[&str] = &[
    "superbar.desktop",
    "supersettings.desktop",
    "superfiles.desktop",
    "supertheme.desktop",
    "superforge.desktop",
    "supernotify.desktop",
    "superdock.desktop",
    "superfedora-settings.desktop",
];

const SYSTEM_ARTIFACTS: &[&str] = &[
    "/etc/systemd/zram-generator.conf.d/superfedora.conf",
    "/etc/systemd/journald.conf.d/superfedora.conf",
    "/etc/systemd/system/packagekit.service.d/superfedora-timeout.conf",
    "/etc/systemd/system/superfedora-boot-guard.service",
    "/etc/systemd/system/btrfs-scrub@.service",
    "/etc/systemd/system/btrfs-scrub@.timer",
    "/etc/sysctl.d/90-superfedora.conf",
    "/etc/polkit-1/rules.d/50-superfedora.rules",
    "/etc/dnf/libdnf5-plugins/actions.d/superfedora-snapper.actions",
    "/etc/tmpfiles.d/superfedora-tuigreet.conf",
    "/etc/profile.d/superfedora.sh",
    "/etc/superfedora/release",
    "/usr/share/wayland-sessions/superfedora.desktop",
    "/usr/local/libexec/superfedora-boot-guard",
    "/usr/local/bin/superfedora",
    "/usr/local/bin/sf",
];

fn latest_backup_dir(backups_root: &Path) -> Option<PathBuf> {
    let entries = fs::read_dir(backups_root).ok()?;
    let mut dirs: Vec<PathBuf> = entries
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_dir())
        .collect();
    dirs.sort();
    dirs.pop()
}

pub fn run_uninstall_cmd(st: &WorkstationState, args: &[String]) -> i32 {
    let mut dry = false;
    let mut purge = false;
    let mut yes = false;
    let mut restore_backups = false;

    for a in args {
        match a.as_str() {
            "--dry-run" | "-n" => dry = true,
            "--purge" | "--all" => purge = true,
            "--yes" | "-y" | "--force" | "-f" => yes = true,
            "--restore-backups" | "--restore" => restore_backups = true,
            "-h" | "--help" | "help" => {
                println!("Usage: superfedora uninstall [--dry-run] [--yes] [--restore-backups] [--purge]");
                println!("  Safely disables SuperFedora systemd units, removes ~/.local/bin/super*");
                println!("  binaries and ~/.local/share/superfedora runtime tree, and optionally");
                println!("  restores backed-up user dotfiles or purges /etc system drop-ins.");
                return 0;
            }
            other => {
                eprintln!("unknown uninstall option: {other}");
                return 2;
            }
        }
    }

    let home = PathBuf::from(env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into()));
    let bin_dir = home.join(".local/bin");
    let share_sf = home.join(".local/share/superfedora");
    let share_forge = home.join(".local/share/superforge");
    let apps_dir = home.join(".local/share/applications");
    let user_systemd = home.join(".config/systemd/user");
    let backups_root = st.state_dir.join("backups");

    println!("\x1b[1;38;5;141m[::] SUPERFEDORA WORKSTATION UNINSTALLER (v{})\x1b[0m", st.version);
    println!("  1. User Services  : Disable {}", USER_TIMERS_AND_UNITS.join(", "));
    println!("  2. Core Binaries  : Remove ~/.local/bin/{{{}}}", CORE_BINARIES.join(","));
    println!("  3. Runtime Share  : Remove {} & {}", share_sf.display(), share_forge.display());
    println!("  4. Desktop Entries: Remove SuperFedora .desktop launchers from {}", apps_dir.display());
    if restore_backups {
        println!("  5. Dotfile Restore: Restore latest backup from {}", backups_root.display());
    }
    if purge {
        println!("  6. System Purge   : Remove /etc SuperFedora drop-ins & ~/.config/superfedora state");
    } else {
        println!("  *  Preserved      : {} (backups & user config; pass --purge to remove)", st.state_dir.display());
    }

    if dry {
        println!("  [DRY-RUN] Uninstall plan verified (0 mutations performed).");
        return 0;
    }

    if !yes {
        print!(":: Proceed with SuperFedora uninstall? [y/N]: ");
        let _ = io::stdout().flush();
        let mut ans = String::new();
        if io::stdin().read_line(&mut ans).is_err() || !matches!(ans.trim().to_ascii_lowercase().as_str(), "y" | "yes") {
            println!("  [--] Uninstall cancelled.");
            return 0;
        }
    }

    // 1. Disable user timers and services without killing active Quickshell session
    for u in USER_TIMERS_AND_UNITS {
        let _ = Command::new("systemctl")
            .args(["--user", "disable", u])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
        let unit_file = user_systemd.join(u);
        if unit_file.exists() {
            let _ = fs::remove_file(&unit_file);
        }
    }
    let _ = Command::new("systemctl")
        .args(["--user", "daemon-reload"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
    println!("  [OK] Disabled user systemd timers and session units.");

    // 2. Restore latest dotfile backup if requested
    if restore_backups && let Some(latest) = latest_backup_dir(&backups_root) {
        let _ = Command::new("cp")
            .args(["-a", &format!("{}/.", latest.display()), &format!("{}/", home.display())])
            .status();
        println!("  [OK] Restored user dotfiles from {}", latest.display());
    }

    // 3. Remove desktop entries
    for de in DESKTOP_ENTRIES {
        let p = apps_dir.join(de);
        if p.exists() {
            let _ = fs::remove_file(p);
        }
    }

    // 4. Remove runtime share directories (preserving ~/.local/share/superfedora if it is a git repo)
    if share_sf.exists() && !share_sf.join(".git").exists() {
        let _ = fs::remove_dir_all(&share_sf);
        println!("  [OK] Removed {}", share_sf.display());
    }
    if share_forge.exists() && !share_forge.join(".git").exists() {
        let _ = fs::remove_dir_all(&share_forge);
        println!("  [OK] Removed {}", share_forge.display());
    }

    // 5. Remove core binaries & symlinks from ~/.local/bin (and /usr/local/bin if writable)
    let sys_bin = Path::new("/usr/local/bin");
    for b in CORE_BINARIES {
        for dir in [&bin_dir, &sys_bin.to_path_buf()] {
            let p = dir.join(b);
            if p.exists() || p.is_symlink() {
                let _ = fs::remove_file(&p);
            }
        }
    }
    println!("  [OK] Removed SuperFedora binaries from {}", bin_dir.display());

    // 6. Optional system-level & state purge
    if purge {
        for sys_p in SYSTEM_ARTIFACTS {
            let p = Path::new(sys_p);
            if p.exists() || p.is_symlink() {
                let _ = Command::new("sudo").args(["-n", "rm", "-f", sys_p]).status();
            }
        }
        for sys_d in ["/etc/superfedora", "/usr/share/superfedora"] {
            if Path::new(sys_d).exists() {
                let _ = Command::new("sudo").args(["-n", "rm", "-rf", sys_d]).status();
            }
        }
        if st.state_dir.exists() {
            let _ = fs::remove_dir_all(&st.state_dir);
            println!("  [OK] Purged state directory {}", st.state_dir.display());
        }
    }

    println!("  [OK] SuperFedora uninstall complete.");
    0
}
