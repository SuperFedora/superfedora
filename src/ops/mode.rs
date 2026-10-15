// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::WorkstationState;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};

pub const MODES: &[(&str, &str, &str)] = &[
    ("stealth", "STEALTH // BATTERY", "Power-saver EPP, pauses 60fps sprite animations, dims RGB, caps cargo jobs"),
    ("balanced", "BALANCED // DAILY", "Default daily driver profile, animations enabled, normal audio & RGB"),
    ("forge", "FORGE // COMPUTE", "Performance EPP, full CPU thread boost for -march=native & AI workloads"),
    ("arcade", "ARCADE // GAMING", "Low-latency PipeWire 64/48000 quantum, DND on, compositor blur/shadows off"),
];

fn cfg_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let dir = PathBuf::from(home).join(".config/superfedora");
    let _ = fs::create_dir_all(&dir);
    dir
}

pub fn active_mode() -> String {
    fs::read_to_string(cfg_dir().join("workstation-mode"))
        .ok()
        .map(|s| s.trim().to_ascii_lowercase())
        .filter(|s| MODES.iter().any(|(id, _, _)| *id == s.as_str()))
        .unwrap_or_else(|| "balanced".into())
}

fn run_quiet(bin: &str, args: &[&str]) {
    let _ = Command::new(bin).args(args).stdout(Stdio::null()).stderr(Stdio::null()).status();
}

fn notify_cast(st: &WorkstationState, role: &str, title: &str, body: &str) {
    if Command::new("supernotify")
        .args(["--cast", role, title, body])
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
        .args(["--cast", role, title, body])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

pub fn run_mode_cmd(st: &WorkstationState, args: &[String]) -> i32 {
    let mut dry = false;
    let mut target = "status";
    for a in args {
        match a.as_str() {
            "--dry-run" | "-n" => dry = true,
            "status" | "list" | "get" => target = "status",
            "cycle" | "next" => target = "cycle",
            "stealth" | "battery" | "powersave" => target = "stealth",
            "balanced" | "default" | "normal" => target = "balanced",
            "forge" | "compute" | "performance" => target = "forge",
            "arcade" | "gaming" | "game" => target = "arcade",
            "-h" | "--help" | "help" => {
                println!("Usage: superfedora mode [stealth|balanced|forge|arcade|cycle|status] [--dry-run]");
                for (id, lbl, desc) in MODES {
                    println!("  {:<10} {:<20} {}", id, lbl, desc);
                }
                return 0;
            }
            other => {
                eprintln!("unknown workstation mode: {other} (expected: stealth, balanced, forge, arcade, status)");
                return 2;
            }
        }
    }

    let cur = active_mode();
    if target == "status" {
        println!("\x1b[1;38;5;141m[::] SUPERFEDORA 16-BIT WORKSTATION MODE ENGINE (Active: {})\x1b[0m", cur.to_uppercase());
        for (id, lbl, desc) in MODES {
            let mark = if *id == cur { "\x1b[1;32m[ACTIVE]\x1b[0m" } else { "        " };
            println!("  {mark} {:<10} {:<20} {}", id, lbl, desc);
        }
        return 0;
    }

    let next_mode = if target == "cycle" {
        let idx = MODES.iter().position(|(id, _, _)| *id == cur).unwrap_or(1);
        MODES[(idx + 1) % MODES.len()].0
    } else {
        target
    };

    if dry {
        println!("  [DRY-RUN] Switching workstation mode: {} -> {}", cur, next_mode);
        return 0;
    }

    let dir = cfg_dir();
    let _ = fs::write(dir.join("workstation-mode"), format!("{next_mode}\n"));

    match next_mode {
        "stealth" => {
            let _ = fs::write(dir.join("animations"), "0\n");
            let _ = fs::write(dir.join("cargo-jobs"), "2\n");
            run_quiet("powerprofilesctl", &["set", "power-saver"]);
            run_quiet("hyprctl", &["keyword", "animations:enabled", "false"]);
            run_quiet("supertheme", &["rgb", "off"]);
            notify_cast(st, "commander", "COMMANDER: STEALTH MODE", "Battery EPP engaged, animations paused, RGB dimmed.");
        }
        "balanced" => {
            let _ = fs::write(dir.join("animations"), "1\n");
            let _ = fs::remove_file(dir.join("cargo-jobs"));
            run_quiet("powerprofilesctl", &["set", "balanced"]);
            run_quiet("hyprctl", &["keyword", "animations:enabled", "true"]);
            run_quiet("hyprctl", &["keyword", "decoration:blur:enabled", "true"]);
            run_quiet("hyprctl", &["keyword", "decoration:shadow:enabled", "true"]);
            run_quiet("pw-metadata", &["-n", "settings", "0", "clock.force-quantum", "0"]);
            run_quiet("supernotify", &["dnd", "off"]);
            run_quiet("supertheme", &["rgb"]);
            notify_cast(st, "commander", "COMMANDER: BALANCED MODE", "Daily driver workstation profile restored.");
        }
        "forge" => {
            let _ = fs::write(dir.join("animations"), "1\n");
            run_quiet("powerprofilesctl", &["set", "performance"]);
            run_quiet("hyprctl", &["keyword", "animations:enabled", "true"]);
            notify_cast(st, "builder", "BUILDER: FORGE COMPUTE MODE", "Full CPU boost unlocked for -march=native & AI workloads.");
        }
        "arcade" => {
            let _ = fs::write(dir.join("animations"), "0\n");
            run_quiet("powerprofilesctl", &["set", "performance"]);
            run_quiet("supernotify", &["dnd", "on"]);
            run_quiet("pw-metadata", &["-n", "settings", "0", "clock.force-quantum", "64"]);
            run_quiet("pw-metadata", &["-n", "settings", "0", "clock.force-rate", "48000"]);
            run_quiet("hyprctl", &["keyword", "decoration:blur:enabled", "false"]);
            run_quiet("hyprctl", &["keyword", "decoration:shadow:enabled", "false"]);
            notify_cast(st, "synth", "AUDIO SYNTH: ARCADE MODE", "PipeWire 64/48000 low-latency quantum locked & DND enabled.");
        }
        _ => {}
    }

    run_quiet("qs", &["ipc", "call", "status", "refresh"]);
    println!("  [OK] Active workstation mode: {} ({})", next_mode.to_uppercase(), next_mode);
    0
}
