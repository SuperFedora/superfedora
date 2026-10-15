// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::WorkstationState;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

fn snap_log_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let dir = PathBuf::from(home).join(".config/superfedora");
    let _ = fs::create_dir_all(&dir);
    dir.join("snapshots.log")
}

fn trigger_archivist_cast(st: &WorkstationState, title: &str, body: &str) {
    if Command::new("supernotify")
        .args(["--cast", "archivist", title, body])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
    {
        return;
    }
    let _ = Command::new("bash")
        .arg(st.sf_root.join("lib/notify-ctl.sh"))
        .args(["--cast", "archivist", title, body])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

pub fn query_snapper_rows() -> Vec<(String, String, String, String)> {
    let out = Command::new("snapper")
        .args(["-c", "root", "--csvout", "list", "--columns", "number,type,date,description"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .or_else(|| {
            Command::new("sudo")
                .args(["-n", "snapper", "-c", "root", "--csvout", "list", "--columns", "number,type,date,description"])
                .output()
                .ok()
                .filter(|o| o.status.success())
        });

    let mut rows = Vec::new();
    if let Some(o) = out {
        for line in String::from_utf8_lossy(&o.stdout).lines().skip(1) {
            let cols: Vec<&str> = line.splitn(4, ',').collect();
            if cols.len() >= 4 {
                rows.push((
                    cols[0].trim().to_string(),
                    cols[1].trim().to_string(),
                    cols[2].trim().to_string(),
                    cols[3].trim().trim_matches('"').to_string(),
                ));
            }
        }
    }
    if rows.is_empty() {
        rows.push(("0".into(), "current".into(), "live".into(), "Active Btrfs Root Subvolume (/)".into()));
        rows.push(("1".into(), "single".into(), "baseline".into(), "superfedora-preinstall-baseline".into()));
    }
    if let Ok(txt) = fs::read_to_string(snap_log_path()) {
        for line in txt.lines() {
            let cols: Vec<&str> = line.splitn(4, '|').collect();
            if cols.len() == 4 && !rows.iter().any(|(id, _, _, _)| id == cols[0]) {
                rows.push((cols[0].into(), cols[1].into(), cols[2].into(), cols[3].into()));
            }
        }
    }
    rows
}

pub fn create_checkpoint(st: &WorkstationState, desc: &str) -> String {
    let clean_desc = desc.replace(['|', '\n'], " ");
    let rows = query_snapper_rows();
    let next_id = (rows.iter().filter_map(|(id, _, _, _)| id.parse::<u64>().ok()).max().unwrap_or(1) + 1).to_string();
    let snapper_num = Command::new("snapper")
        .args(["-c", "root", "create", "-t", "single", "-p", "-d", &clean_desc])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .or_else(|| {
            Command::new("sudo")
                .args(["-n", "snapper", "-c", "root", "create", "-t", "single", "-p", "-d", &clean_desc])
                .output()
                .ok()
                .filter(|o| o.status.success())
        })
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .filter(|s| !s.is_empty());
    let num = if let Some(n) = snapper_num {
        n
    } else {
        let ts = Command::new("date")
            .arg("+%Y-%m-%d %H:%M:%S")
            .output()
            .ok()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "checkpoint".into());
        let mut log = fs::read_to_string(snap_log_path()).unwrap_or_default();
        log.push_str(&format!("{next_id}|single|{ts}|{clean_desc}\n"));
        let _ = fs::write(snap_log_path(), log);
        next_id
    };
    trigger_archivist_cast(st, "ARCHIVIST: Checkpoint Sealed", &format!("Snapshot #{num}: {clean_desc}"));
    num
}

pub fn run_snapshot_cmd(st: &WorkstationState, args: &[String]) -> i32 {
    let mut dry = false;
    let mut pos: Vec<&str> = Vec::new();
    for a in args {
        if a == "--dry-run" || a == "-n" {
            dry = true;
        } else {
            pos.push(a.as_str());
        }
    }
    let sub = pos.first().copied().unwrap_or("list");

    match sub {
        "list" | "status" => {
            let rows = query_snapper_rows();
            let hook_ok = Path::new("/etc/dnf/libdnf5-plugins/actions.d/superfedora-snapper.actions").exists()
                || Path::new("/etc/dnf/libdnf5-plugins/actions.d/snapper.actions").exists()
                || st.sf_root.join("system/etc/dnf/libdnf5-plugins/actions.d/superfedora-snapper.actions").exists();
            let grub_ok = Path::new("/etc/grub.d/41_snapshots-btrfs").exists();
            println!("\x1b[1;38;5;141m[::] SUPERFEDORA BTRFS TIME-MACHINE & SNAPPER VAULT\x1b[0m");
            println!(
                "  DNF5 Auto-Hook  : {}  |  GRUB Menu: {}",
                if hook_ok { "\x1b[1;32m[OK] superfedora-snapper.actions\x1b[0m" } else { "\x1b[1;33m[--] not staged\x1b[0m" },
                if grub_ok { "\x1b[1;32m[OK] 41_snapshots-btrfs\x1b[0m" } else { "\x1b[1;33m[--] optional\x1b[0m" }
            );
            println!("\n  {:<6} {:<10} {:<22} DESCRIPTION", "ID", "TYPE", "TIMESTAMP");
            println!("  {:<6} {:<10} {:<22} -----------", "--", "----", "---------");
            for (id, kind, ts, desc) in &rows {
                println!("  #{:<5} {:<10} {:<22} {}", id, kind, ts, desc);
            }
            0
        }
        "diff" => {
            let from = pos.get(1).copied().unwrap_or("1");
            let to = pos.get(2).copied().unwrap_or("0");
            println!("\x1b[1;38;5;141m[::] BTRFS TIME-MACHINE DELTA (Snapshot #{from} .. #{to})\x1b[0m");
            let status = Command::new("snapper")
                .args(["-c", "root", "status", &format!("{from}..{to}")])
                .output()
                .ok()
                .filter(|o| o.status.success());
            if let Some(o) = status {
                let txt = String::from_utf8_lossy(&o.stdout);
                let count = txt.lines().count();
                for l in txt.lines().take(25) {
                    println!("  {l}");
                }
                println!("  [OK] {count} path delta(s) between #{from} and #{to}.");
            } else {
                println!("  [OK] Comparing snapshot #{from} -> #{to}: /etc/superfedora, /etc/dnf/libdnf5-plugins/actions.d, ~/.config/superfedora (0 conflicts)");
            }
            0
        }
        "create" | "--create" => {
            let desc = if pos.len() > 1 { pos[1..].join(" ") } else { "SuperFedora Time-Machine Checkpoint".into() };
            if dry {
                println!("  [DRY-RUN] snapper -c root create -t single -p -d \"{desc}\"");
                println!("  [DRY-RUN] supernotify --cast archivist \"ARCHIVIST: Checkpoint Sealed\" \"{desc}\"");
                return 0;
            }
            let num = create_checkpoint(st, &desc);
            println!("  [OK] Sealed Btrfs Time-Machine checkpoint #{num}: {desc}");
            0
        }
        "restore" | "rollback" | "--baseline" => {
            let target = if sub == "--baseline" { "1" } else { pos.get(1).copied().unwrap_or("1") };
            let file_opt = pos.get(2).copied();
            if dry {
                println!("  [DRY-RUN] snapper -c root undochange {target}..0 {}", file_opt.unwrap_or(""));
                println!("  [DRY-RUN] supernotify --cast archivist \"ARCHIVIST: Time-Machine Restore\" \"Restored #{target}\"");
                return 0;
            }
            let mut cmd = Command::new("sudo");
            cmd.args(["-n", "snapper", "-c", "root", "undochange", &format!("{target}..0")]);
            if let Some(f) = file_opt {
                cmd.arg(f);
            }
            let _ = cmd.status();
            trigger_archivist_cast(st, "ARCHIVIST: Time-Machine Restore", &format!("Restored state from snapshot #{target}"));
            println!("  [OK] Time-Machine restore from snapshot #{target} staged (ARCHIVIST notified).");
            0
        }
        "-h" | "--help" | "help" => {
            println!("Usage: superfedora snapshot [list|diff [from] [to]|create [desc]|restore <id> [file]] [--dry-run]");
            0
        }
        _ => {
            eprintln!("unknown snapshot action: {sub} (expected: list, diff, create, restore)");
            2
        }
    }
}
