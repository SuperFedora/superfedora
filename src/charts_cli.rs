// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::{PALETTES, WorkstationState};
use crate::telemetry::Telemetry;
use std::io::{self, Write};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

pub fn ansi_rgb(rgb: (u8, u8, u8)) -> String {
    format!("\x1b[38;2;{};{};{}m", rgb.0, rgb.1, rgb.2)
}

pub fn bar_str(pct: u64, width: usize, fill_rgb: (u8, u8, u8)) -> String {
    let clamped = pct.min(100);
    let filled = ((clamped as usize) * width) / 100;
    let empty = width.saturating_sub(filled);
    let col = ansi_rgb(fill_rgb);
    format!(
        "{col}{}\x1b[38;5;238m{}\x1b[0m \x1b[1m{:>3}%\x1b[0m",
        "█".repeat(filled),
        "░".repeat(empty),
        clamped
    )
}

pub fn print_cartridge_banner(st: &WorkstationState, tel: &Telemetry) {
    let p = ansi_rgb(st.primary_rgb);
    let s = ansi_rgb(st.secondary_rgb);
    let b = "\x1b[1m";
    let r = "\x1b[0m";
    let forged_cnt = st.forge_items.iter().filter(|i| i.installed).count();
    let webapp_cnt = st.webapps.len();
    let sfx_lbl = if st.sfx_on { "on" } else { "off" };
    println!("{p}{b}╔══════════════════════════════════════════════════════════════════════════════╗{r}");
    println!(
        "{p}{b}║  [::] SUPER FEDORA 16-BIT RUST ENGINE & WORKSTATION DECK      v{:<12} ║{r}",
        st.version
    );
    println!("{p}{b}╠══════════════════════════════════════════════════════════════════════════════╣{r}");
    println!(
        "{p}{b}║{r}  {s}{b}CPU{r}    : {:<44} {s}{b}FREQ{r}: {:>5} MHz   {p}{b}║{r}",
        tel.cpu_model.chars().take(44).collect::<String>(),
        tel.cpu_mhz
    );
    println!(
        "{p}{b}║{r}  {s}{b}Theme{r}  : {:<18} {s}{b}Mode{r}: {:<8} {s}{b}Corners{r}: {:<10} {s}{b}SFX{r}: {:<4} {p}{b}║{r}",
        st.theme_color, st.theme_mode, st.theme_corners, sfx_lbl
    );
    println!(
        "{p}{b}║{r}  {s}{b}Forge{r}  : {:<2} native binaries  {s}{b}WebApps{r}: {:<5} {s}{b}Guard{r}  : {:<8} (#{:<4}) {p}{b}║{r}",
        forged_cnt, webapp_cnt, st.guard_status, st.baseline_snap
    );
    println!("{p}{b}╚══════════════════════════════════════════════════════════════════════════════╝{r}");
}

pub fn print_vitals_charts(st: &WorkstationState, tel: &mut Telemetry) {
    thread::sleep(Duration::from_millis(120));
    tel.refresh();
    print_cartridge_banner(st, tel);
    let p = ansi_rgb(st.primary_rgb);
    let s = ansi_rgb(st.secondary_rgb);
    let b = "\x1b[1m";
    let r = "\x1b[0m";

    println!("\n{p}{b}━━ 16-BIT HARDWARE TELEMETRY & BAR CHARTS{r}");
    println!(
        "  {s}{b}CPU Total   {r} {}  ({} MHz, up {})",
        bar_str(tel.cpu_avg, 32, st.primary_rgb),
        tel.cpu_mhz,
        tel.uptime_str
    );
    println!(
        "  {s}{b}Memory RAM  {r} {}  ({} / {} MiB)",
        bar_str(tel.ram_pct as u64, 32, st.secondary_rgb),
        tel.ram_used_mb,
        tel.ram_total_mb
    );
    println!(
        "  {s}{b}ZRAM / Swap {r} {}  ({} / {} MiB)",
        bar_str(tel.swap_pct as u64, 32, (115, 218, 202)),
        tel.swap_used_mb,
        tel.swap_total_mb
    );
    println!(
        "  {s}{b}GPU Engine  {r} {}  (Thermal: {} C)",
        bar_str(tel.gpu_pct as u64, 32, (224, 175, 104)),
        tel.temp_c
    );
    println!(
        "  {s}{b}Battery Tank{r} {}  (Status: {})",
        bar_str(tel.bat_pct as u64, 32, (158, 206, 106)),
        tel.bat_status
    );
    println!(
        "  {s}{b}Btrfs Root /{r} {}  ({})",
        bar_str(tel.disk_root_pct as u64, 32, st.primary_rgb),
        tel.disk_root_lbl
    );

    if !tel.core_loads.is_empty() {
        println!("\n{p}{b}━━ PER-CORE CPU LOAD BAR CHART{r}");
        for chunk in tel.core_loads.chunks(2) {
            print!("  ");
            for (lbl, pct) in chunk {
                print!("{s}{b}{:<4}{r} {}    ", lbl, bar_str(*pct, 18, st.primary_rgb));
            }
            println!();
        }
    }
}

pub fn print_forge_charts(st: &WorkstationState) {
    let p = ansi_rgb(st.primary_rgb);
    let s = ansi_rgb(st.secondary_rgb);
    let b = "\x1b[1m";
    let r = "\x1b[0m";

    println!("{p}{b}━━ SUPERFEDORA FORGE — NATIVE (-march=native) BINARIES & SIZE CHART{r}");
    let max_kb = st.forge_items.iter().map(|i| i.size_kb).max().unwrap_or(1).max(1);
    for item in &st.forge_items {
        let status = if item.installed {
            "\x1b[1;32m[FORGED]\x1b[0m"
        } else {
            "\x1b[2m[AVAIL ]\x1b[0m"
        };
        let ratio = (((item.size_kb as f64).sqrt() * 100.0) / (max_kb as f64).sqrt()).min(100.0) as usize;
        let filled = ((ratio * 18) / 100).max(usize::from(item.installed));
        let bar = format!(
            "{}{}\x1b[38;5;238m{}\x1b[0m",
            if item.installed { &p } else { "\x1b[2m" },
            "█".repeat(filled),
            "░".repeat(18usize.saturating_sub(filled))
        );
        let sz_str = if item.size_kb > 0 {
            format!("{:>6} KB", item.size_kb)
        } else {
            "     --  ".into()
        };
        println!(
            "  {} {s}{b}{:<13}{r} {:<6} {} {}  \x1b[2m{}\x1b[0m",
            status, item.name, item.kind, bar, sz_str, item.desc
        );
    }

    println!("\n{p}{b}━━ CHROMELESS FIREFOX WEBAPPS ({}){r}", st.webapps.len());
    if st.webapps.is_empty() {
        println!("  \x1b[2m(no webapps installed — run: sf forge webapp <url>)\x1b[0m");
    } else {
        for (slug, name, url) in &st.webapps {
            println!("  \x1b[1;36m[WEBAPP]\x1b[0m {b}{:<18}{r} {:<16} \x1b[2m{}\x1b[0m", name, slug, url);
        }
    }
}

pub fn print_theme_swatches(st: &WorkstationState) {
    let b = "\x1b[1m";
    let r = "\x1b[0m";
    println!("{}{b}━━ 16-BIT RAINBOW PALETTE STUDIO (Active: {}){r}", ansi_rgb(st.primary_rgb), st.theme_color);
    for &(id, name, pri, sec) in PALETTES {
        let active = if id == st.theme_color { "\x1b[1;32m▸ ACTIVE\x1b[0m" } else { "        " };
        println!(
            "  {}  {b}{:<14}{r} {:<10} {}████████████{r} {}████████{r}",
            active,
            id,
            name,
            ansi_rgb(pri),
            ansi_rgb(sec)
        );
    }
}

pub fn run_forge_update_graphical(st: &mut WorkstationState) -> i32 {
    let p = ansi_rgb(st.primary_rgb);
    let s = ansi_rgb(st.secondary_rgb);
    let b = "\x1b[1m";
    let r = "\x1b[0m";
    println!("{p}{b}╔══════════════════════════════════════════════════════════════════════════════╗{r}");
    println!("{p}{b}║  [::] SUPERFEDORA FORGE 4-STAGE UPDATE PIPELINE (DNF + GIT + LTO + WEBAPPS)  ║{r}");
    println!("{p}{b}╚══════════════════════════════════════════════════════════════════════════════╝{r}");

    let forge_sh = st.sf_root.join("lib/forge.sh");
    let mut child = match Command::new(&forge_sh)
        .arg("update")
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            eprintln!("error launching forge update: {e}");
            return 1;
        }
    };

    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                st.refresh();
                println!(
                    "\n  {s}{b}Forge Pipeline{r} {}  \x1b[1;32m[COMPLETE]\x1b[0m",
                    bar_str(100, 36, st.primary_rgb)
                );
                let _ = io::stdout().flush();
                return status.code().unwrap_or(0);
            }
            Ok(None) => {
                thread::sleep(Duration::from_millis(250));
            }
            Err(_) => return 1,
        }
    }
}
