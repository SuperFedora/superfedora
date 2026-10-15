// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

pub mod hardware;
pub mod mode;
pub mod snapshot;
pub mod workstation;

use crate::state::WorkstationState;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

pub const SYSTEM_UNITS: &[(&str, &str)] = &[
    ("greetd.service", "Login manager (tuigreet + uwsm)"),
    ("superfedora-boot-guard.service", "Btrfs Boot-Guard health & auto-rollback"),
    ("systemd-oomd.service", "Userspace out-of-memory killer"),
    ("fstrim.timer", "Weekly NVMe/SSD TRIM timer"),
    ("btrfs-scrub@-.timer", "Monthly Btrfs root scrub timer"),
    ("snapper-timeline.timer", "Hourly Btrfs snapshot timeline timer"),
    ("snapper-cleanup.timer", "Daily Btrfs snapshot retention cleanup"),
    ("cups.socket", "CUPS printing socket activation (0 MB idle)"),
    ("sssd-kcm.socket", "Kerberos credentials socket activation"),
    ("packagekit.service", "PackageKit D-Bus service (ShutdownTimeout=30s)"),
    ("ModemManager.service", "Cellular modem manager (udev hardware-triggered)"),
];

pub const USER_UNITS: &[(&str, &str)] = &[
    ("superfedora-session.target", "SuperFedora Wayland session target"),
    ("hyprland-session.target", "Hyprland compositor session target"),
    ("supershell.service", "Quickshell 16-bit Wayland shell & dock"),
    ("superagent.service", "Autonomous telemetry & Cast Comms daemon"),
    ("idlescreen.service", "16-bit IdleScreen Wayland screensaver"),
    ("supertheme-sun.timer", "Solar day/night palette sync timer (15m)"),
    ("superforge-check.timer", "Weekly native binary & toolchain audit"),
];

pub const ORG_REPOS: &[&str] = &[
    "superfedora",
    "superforge",
    "supertheme",
    "supernotify",
    "supershell",
    "superagent",
    "superfedora.github.io",
    ".github",
];

fn unit_state(user: bool, unit: &str) -> (String, String, &'static str) {
    let mut cmd = Command::new("systemctl");
    if user { cmd.arg("--user"); }
    let active = cmd.args(["is-active", unit]).output().ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .filter(|s| !s.is_empty()).unwrap_or_else(|| "inactive".into());
    let mut cmd2 = Command::new("systemctl");
    if user { cmd2.arg("--user"); }
    let enabled = cmd2.args(["is-enabled", unit]).output().ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .filter(|s| !s.is_empty()).unwrap_or_else(|| "disabled".into());
    let mode_lbl = if unit.ends_with(".socket") || unit == "packagekit.service" || unit == "ModemManager.service" {
        if active == "active" { "Active" } else { "On-Demand (Socket)" }
    } else if active == "active" {
        "Active"
    } else {
        "Stopped"
    };
    (active, enabled, mode_lbl)
}

pub fn run_service_cmd(_st: &WorkstationState, args: &[String]) -> i32 {
    let sub = args.first().map(|s| s.as_str()).unwrap_or("status");
    match sub {
        "status" | "list" => {
            println!("\x1b[1;38;5;141m[::] SUPERFEDORA COMPATIBILITY-FIRST SYSTEMD SERVICE TELEMETRY\x1b[0m");
            println!("\n  \x1b[1;36mSYSTEM & ON-DEMAND SOCKET UNITS (systemd)\x1b[0m");
            for (u, desc) in SYSTEM_UNITS {
                let (act, en, mode_lbl) = unit_state(false, u);
                let ok = act == "active" || en == "enabled" || en == "static" || mode_lbl == "On-Demand (Socket)";
                let badge = if ok { "\x1b[1;32m[OK]\x1b[0m" } else { "\x1b[1;33m[--]\x1b[0m" };
                println!("  {badge} {:<30} {:<18} {:<10} {}", u, mode_lbl, en, desc);
            }
            println!("\n  \x1b[1;36mUSER SESSION UNITS (systemd --user)\x1b[0m");
            for (u, desc) in USER_UNITS {
                let (act, en, mode_lbl) = unit_state(true, u);
                let badge = if act == "active" || en == "enabled" || en == "static" { "\x1b[1;32m[OK]\x1b[0m" } else { "\x1b[1;33m[--]\x1b[0m" };
                println!("  {badge} {:<30} {:<18} {:<10} {}", u, mode_lbl, en, desc);
            }
            println!("\n  \x1b[1;36mDECLARATIVE OS TUNING & HOOKS\x1b[0m");
            for (label, path) in [
                ("zram-generator", "/etc/systemd/zram-generator.conf.d/superfedora.conf"),
                ("journald-bound", "/etc/systemd/journald.conf.d/superfedora.conf"),
                ("packagekit-30s", "/etc/systemd/system/packagekit.service.d/superfedora-timeout.conf"),
                ("dnf5-snapper", "/etc/dnf/libdnf5-plugins/actions.d/superfedora-snapper.actions"),
                ("sysctl-tuning", "/etc/sysctl.d/90-superfedora.conf"),
                ("polkit-rules", "/etc/polkit-1/rules.d/50-superfedora.rules"),
            ] {
                let present = Path::new(path).exists();
                let badge = if present { "\x1b[1;32m[OK]\x1b[0m" } else { "\x1b[1;33m[--]\x1b[0m" };
                println!("  {badge} {:<30} {}", label, path);
            }
            0
        }
        "start" | "stop" | "restart" | "enable" | "disable" => {
            let unit = args.get(1).map(|s| s.as_str()).unwrap_or("superfedora-session.target");
            let is_sys = SYSTEM_UNITS.iter().any(|(u, _)| *u == unit);
            let status = if is_sys {
                Command::new("sudo").args(["systemctl", sub, unit]).status()
            } else {
                Command::new("systemctl").args(["--user", sub, unit]).status()
            };
            status.ok().and_then(|s| s.code()).unwrap_or(1)
        }
        "logs" | "journal" => {
            let unit = args.get(1).map(|s| s.as_str()).unwrap_or("supershell.service");
            let is_sys = SYSTEM_UNITS.iter().any(|(u, _)| *u == unit);
            let mut cmd = Command::new("journalctl");
            if !is_sys {
                cmd.arg("--user");
            }
            cmd.args(["-u", unit, "-n", "50", "--no-pager"]).status().ok().and_then(|s| s.code()).unwrap_or(1)
        }
        "-h" | "--help" | "help" => {
            println!("Usage: superfedora service [status|start|stop|restart|enable|logs] [unit]");
            0
        }
        _ => {
            eprintln!("error: unknown service action '{sub}' (expected: status, start, stop, restart, logs)");
            2
        }
    }
}

pub fn run_system_upgrade(st: &WorkstationState, args: &[String]) -> i32 {
    let mut dry = false;
    let mut rebuild_only = false;
    let mut target_rel: Option<String> = None;
    for a in args {
        match a.as_str() {
            "--dry-run" | "-n" | "--check" | "status" => dry = true,
            "--rebuild" | "rebuild" | "post-upgrade" => rebuild_only = true,
            "-h" | "--help" | "help" => {
                println!("Usage: superfedora system-upgrade [<releasever>|--dry-run|--rebuild]");
                println!("  Wraps dnf5 system-upgrade with a pre-upgrade Btrfs Snapper checkpoint");
                println!("  (ARCHIVIST Cast Comms) and post-upgrade superforge native binary rebuild.");
                return 0;
            }
            v if v.chars().all(|c| c.is_ascii_digit()) => target_rel = Some(v.to_string()),
            _ => {}
        }
    }
    let cur_rel = Command::new("rpm")
        .args(["-E", "%fedora"])
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "42".into());
    let next_rel = target_rel.unwrap_or_else(|| {
        cur_rel.parse::<u32>().map(|n| (n + 1).to_string()).unwrap_or_else(|_| "43".into())
    });

    println!("\x1b[1;38;5;141m[::] SUPERFEDORA RELEASE UPGRADE ENGINE (Fedora {cur_rel} -> Fedora {next_rel})\x1b[0m");
    if rebuild_only {
        println!("  [+] Rebuilding forged native binaries for Fedora {cur_rel} (-march=native)...");
        let forge_sh = st.sf_root.join("lib/forge.sh");
        return Command::new("bash").arg(forge_sh).arg("rebuild").status().ok().and_then(|s| s.code()).unwrap_or(0);
    }
    if dry {
        println!("  [DRY-RUN] 1. Pre-Upgrade Checkpoint : snapper -c root create -d \"SuperFedora pre-upgrade F{cur_rel}->F{next_rel}\"");
        println!("  [DRY-RUN] 2. Cast Comms Relay       : supernotify --cast archivist \"ARCHIVIST: Pre-upgrade snapshot verified\"");
        println!("  [DRY-RUN] 3. DNF5 System Upgrade    : sudo dnf5 system-upgrade download --releasever={next_rel} --allowerasing -y");
        println!("  [DRY-RUN] 4. Post-Upgrade Rebuild   : superfedora system-upgrade --rebuild (recompiles native binaries)");
        return 0;
    }

    println!("  [1/3] Creating pre-upgrade Btrfs snapshot via Snapper (ARCHIVIST)...");
    let desc = format!("SuperFedora pre-upgrade Fedora {cur_rel} -> {next_rel}");
    let _ = Command::new("sudo").args(["snapper", "-c", "root", "create", "-t", "single", "-d", &desc]).status();
    let _ = Command::new("bash").arg(st.sf_root.join("lib/notify-ctl.sh")).args(["--cast", "archivist"]).stdout(Stdio::null()).status();

    println!("  [2/3] Downloading Fedora {next_rel} system-upgrade packages via dnf5...");
    let dnf_bin = if Path::new("/usr/bin/dnf5").is_file() { "dnf5" } else { "dnf" };
    let _ = Command::new("sudo").args([dnf_bin, "install", "-y", "dnf5-plugin-system-upgrade"]).status();
    let dl = Command::new("sudo")
        .args([dnf_bin, "system-upgrade", "download", &format!("--releasever={next_rel}"), "--allowerasing", "-y"])
        .status();
    if !dl.map(|s| s.success()).unwrap_or(false) {
        eprintln!("  [FAIL] {dnf_bin} system-upgrade download failed for Fedora {next_rel}");
        return 1;
    }
    println!("  [3/3] Download complete. Run 'sudo {dnf_bin} system-upgrade reboot' to apply, then 'superfedora system-upgrade --rebuild'.");
    0
}

pub fn run_repo_cmd(st: &WorkstationState, args: &[String]) -> i32 {
    let sub = args.first().map(|s| s.as_str()).unwrap_or("status");
    let ws = st.sf_root.parent().map(Path::to_path_buf).unwrap_or_else(|| PathBuf::from("/home/jeryd/Projects/superfedora"));
    match sub {
        "status" | "list" => {
            println!("\x1b[1;38;5;141m[::] @SUPERFEDORA MULTI-REPOSITORY ORCHESTRATION ({})\x1b[0m", ws.display());
            println!("  {:<22} {:<10} {:<10} {:<10} STATUS", "REPOSITORY", "VERSION", "TAG", "BRANCH");
            println!("  {:<22} {:<10} {:<10} {:<10} ------", "----------", "-------", "---", "------");
            for r in ORG_REPOS {
                let dir = ws.join(r);
                if !dir.join(".git").exists() {
                    println!("  {:<22} {:<10} {:<10} {:<10} missing", r, "-", "-", "-");
                    continue;
                }
                let ver = fs::read_to_string(dir.join("VERSION")).unwrap_or_else(|_| "-".into()).trim().to_string();
                let tag = Command::new("git").arg("-C").arg(&dir).args(["describe", "--tags", "--abbrev=0"]).output().ok().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).filter(|s| !s.is_empty()).unwrap_or_else(|| "-".into());
                let br = Command::new("git").arg("-C").arg(&dir).args(["rev-parse", "--abbrev-ref", "HEAD"]).output().ok().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_else(|| "main".into());
                let dirty = Command::new("git").arg("-C").arg(&dir).args(["status", "--porcelain"]).output().ok().map(|o| !o.stdout.is_empty()).unwrap_or(false);
                let st_txt = if dirty { "\x1b[1;33mmodified\x1b[0m" } else { "\x1b[1;32mclean\x1b[0m" };
                println!("  {:<22} {:<10} {:<10} {:<10} {}", r, ver, tag, br, st_txt);
            }
            0
        }
        "test" | "check" => {
            let mut failed = 0;
            for r in ORG_REPOS {
                let test_py = ws.join(r).join("tests/test_page_rules.py");
                if test_py.is_file() {
                    let ok = Command::new("python3").arg(&test_py).status().map(|s| s.success()).unwrap_or(false);
                    if !ok { failed += 1; }
                }
            }
            if failed == 0 { 0 } else { 1 }
        }
        "sync" | "pull" => {
            for r in ORG_REPOS {
                let dir = ws.join(r);
                if dir.join(".git").exists() {
                    println!(":: syncing {r}...");
                    let _ = Command::new("git").arg("-C").arg(&dir).args(["pull", "--ff-only"]).status();
                }
            }
            0
        }
        "-h" | "--help" | "help" => {
            println!("Usage: superfedora repo [status|test|sync]");
            0
        }
        _ => {
            eprintln!("error: unknown repo subcommand '{sub}' (expected: status, test, sync)");
            2
        }
    }
}
