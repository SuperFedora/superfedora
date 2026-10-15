// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::charts_cli::{
    ansi_rgb, bar_str, print_cartridge_banner, print_forge_charts, print_theme_swatches,
    print_vitals_charts, run_forge_update_graphical,
};
use crate::state::WorkstationState;
use crate::telemetry::Telemetry;
use crate::tui::run_tui;
use std::env;
use std::io::{self, IsTerminal};
use std::process::Command;

pub fn print_usage(st: &WorkstationState) {
    let p = ansi_rgb(st.primary_rgb);
    let s = ansi_rgb(st.secondary_rgb);
    let b = "\x1b[1m";
    let r = "\x1b[0m";
    println!("{p}{b}SuperFedora v{} — Native Rust 16-Bit Workstation Engine & TUI{r}", st.version);
    println!("Usage: {b}sf{r} [command] [options]   or   {b}superfedora{r} [command] [options]\n");
    println!("{s}{b}Graphical TUI & Telemetry Commands:{r}");
    println!("  {b}tui | welcome | deck{r} Launch full-screen 16-Bit Rust Graphical TUI (default in TTY)");
    println!("  {b}vitals | charts{r}      Render live 16-bit CPU per-core, RAM, GPU, Thermal & Disk bar charts");
    println!("  {b}forge [target]{r}       Graphical Forge manager, binary size chart, 4-stage update & WebApps");
    println!("  {b}theme [action]{r}       16-Bit Rainbow Palette Studio & truecolor swatch matrix\n");
    println!("{s}{b}Workstation Orchestrator Commands:{r}");
    println!("  {b}install{r}              Check every module and install whatever is missing");
    println!("  {b}status | doctor{r}      Audit workstation modules & print readiness bar chart");
    println!("  {b}update{r}               Fetch the latest SuperFedora release, then run install");
    println!("  {b}build [action]{r}       Compile & tune core stack from source (-march=native)");
    println!("  {b}dotfiles [--check]{r}   Deploy desktop configs (or list drift from this release)");
    println!("  {b}dock [action]{r}        SuperDock position, autohide, pin & workspace layout");
    println!("  {b}notify [action]{r}      Notification Center, DND, banners & cast comms");
    println!("  {b}session [action]{r}     Select or switch Desktop Environment (DE) session");
    println!("  {b}sfx [action]{r}         16-bit sound effects engine (status, on, off, toggle, play)");
    println!("  {b}ai [action]{r}          Quake AI console, Ollama ip:port & custom agents");
    println!("  {b}modules{r}              List installer modules in execution order");
    println!("  {b}rollback [action]{r}    Btrfs snapshot manager, grub-btrfs & Boot-Guard rollback");
    println!("  {b}version{r}              Print the SuperFedora Rust engine version\n");
    println!("{s}{b}Install / Audit Options:{r}");
    println!("  --quick              Use prebuilt binary packages (default)");
    println!("  --build-from-source  Compile & tune for localhost hardware (-march=native)");
    println!("  --dry-run            Show what would be installed without changes");
    println!("  --only a,b           Run only these modules (e.g. 40,desktop)");
    println!("  --skip a,b           Skip these modules");
    println!("  -v, --verbose        Show verbose command output");
    println!("  -h, --help           Show this help");
}

pub fn dispatch(cmd: &str, args: &[String], st: &mut WorkstationState) -> i32 {
    match cmd {
        "" => {
            if io::stdin().is_terminal() && io::stdout().is_terminal() {
                run_tui(0)
            } else {
                print_usage(st);
                0
            }
        }
        "-h" | "--help" | "help" => {
            print_usage(st);
            0
        }
        "version" | "--version" | "-V" => {
            println!("SuperFedora {} (SuperFedora/superfedora — Rust 1.99 Native Engine)", st.version);
            0
        }
        "vitals" | "charts" | "top" | "telemetry" => {
            let mut tel = Telemetry::new();
            print_vitals_charts(st, &mut tel);
            0
        }
        "tui" | "welcome" | "deck" => match args.first().map(|s| s.as_str()) {
            Some("status" | "banner") => {
                let mut tel = Telemetry::new();
                print_vitals_charts(st, &mut tel);
                0
            }
            Some("forge") => run_tui(1),
            Some("theme" | "themes") => run_tui(2),
            Some("rollback" | "snapshots") => exec_script(st, "lib/tui.sh", &prepend("rollback", &args[1..])),
            Some("-h" | "--help" | "help") => exec_script(st, "lib/tui.sh", args),
            _ => {
                if io::stdin().is_terminal() && io::stdout().is_terminal() {
                    run_tui(0)
                } else {
                    print_cartridge_banner(st, &Telemetry::new());
                    0
                }
            }
        },
        "forge" => match args.first().map(|s| s.as_str()) {
            None | Some("status" | "list") => {
                print_forge_charts(st);
                0
            }
            Some("tui") => run_tui(1),
            Some("update" | "upgrade") => run_forge_update_graphical(st),
            _ => {
                let code = exec_script(st, "lib/forge.sh", args);
                st.refresh();
                code
            }
        },
        "theme" | "themes" => match args.first().map(|s| s.as_str()) {
            None | Some("list" | "swatches") => {
                print_theme_swatches(st);
                0
            }
            Some("tui") => run_tui(2),
            _ => exec_script(st, "lib/apply-theme.sh", args),
        },
        "dock" | "panel" | "panels" => exec_script(st, "lib/panel-ctl.sh", args),
        "notify" | "notifications" | "notif" => exec_script(st, "lib/notify-ctl.sh", args),
        "session" | "de" => exec_script(st, "lib/session-ctl.sh", args),
        "build" | "source" => exec_script(st, "lib/build-source.sh", args),
        "sfx" | "sound" => exec_script(st, "lib/sfx.sh", args),
        "dotfiles" => exec_script(st, "lib/install-dotfiles.sh", args),
        "rollback" | "snapshots" => exec_script(st, "lib/tui.sh", &prepend("rollback", args)),
        "ai" | "quake" => exec_script(st, "dotfiles/.config/hypr/scripts/quake-ai.sh", args),
        "webcam" | "camera" | "mic" | "speaker" => {
            exec_script(st, "dotfiles/.config/hypr/scripts/toggle-touchpad.sh", &prepend(cmd, args))
        }
        "io" => exec_script(st, "dotfiles/.config/hypr/scripts/toggle-touchpad.sh", args),
        "settings-probe" => {
            crate::settings_engine::print_probe();
            0
        }
        "settings-apply" => crate::settings_engine::apply_setting(args),
        "settings" | "config" => {
            if let Some(sub) = args.first().map(|s| s.as_str()) {
                if sub == "probe" {
                    crate::settings_engine::print_probe();
                    return 0;
                } else if sub == "apply" {
                    return crate::settings_engine::apply_setting(&args[1..]);
                }
            }
            let mut c = Command::new("qs");
            c.args(["ipc", "call", "settings"]);
            if let Some(tab) = args.first() {
                c.args(["open", tab]);
            } else {
                c.arg("toggle");
            }
            c.status().map(|s| s.code().unwrap_or(0)).unwrap_or(1)
        }
        "modules" | "list" => {
            let p = ansi_rgb(st.primary_rgb);
            let s = ansi_rgb(st.secondary_rgb);
            println!("{p}\x1b[1m━━ SUPERFEDORA WORKSTATION MODULES ({})\x1b[0m", st.modules.len());
            for (num, name, desc, _) in &st.modules {
                println!("  {s}\x1b[1m{num}\x1b[0m  \x1b[1m{name:<14}\x1b[0m {}  {desc}", bar_str(100, 10, st.primary_rgb));
            }
            0
        }
        "install" | "status" | "check" | "audit" | "doctor" | "update" => run_module_engine(cmd, args, st),
        _ => {
            eprintln!("unknown command: {cmd}");
            print_usage(st);
            2
        }
    }
}

fn prepend(first: &str, rest: &[String]) -> Vec<String> {
    let mut v = Vec::with_capacity(rest.len() + 1);
    v.push(first.to_string());
    v.extend_from_slice(rest);
    v
}

fn exec_script(st: &WorkstationState, rel: &str, args: &[String]) -> i32 {
    Command::new(st.sf_root.join(rel))
        .env("SF_ROOT", &st.sf_root)
        .args(args)
        .status()
        .map(|s| s.code().unwrap_or(0))
        .unwrap_or(1)
}

fn run_module_engine(cmd: &str, args: &[String], st: &WorkstationState) -> i32 {
    let mut build_mode = env::var("SUPERFEDORA_BUILD_MODE").unwrap_or_default();
    let (mut only, mut skip, mut dry, mut verbose, mut i) = (String::new(), String::new(), false, false, 0);
    while i < args.len() {
        match args[i].as_str() {
            "--quick" | "--binary" => build_mode = "quick".into(),
            "--build-from-source" | "--from-source" | "--source" | "--native" => build_mode = "source".into(),
            "--dry-run" => dry = true,
            "--only" => { i += 1; only = args.get(i).cloned().unwrap_or_default(); }
            s if s.starts_with("--only=") => only = s["--only=".len()..].to_string(),
            "--skip" => { i += 1; skip = args.get(i).cloned().unwrap_or_default(); }
            s if s.starts_with("--skip=") => skip = s["--skip=".len()..].to_string(),
            "-v" | "--verbose" => verbose = true,
            "-h" | "--help" => { print_usage(st); return 0; }
            other => { eprintln!("unknown option: {other}"); print_usage(st); return 2; }
        }
        i += 1;
    }

    let script = r#"
set -uo pipefail
source "$SF_ROOT/lib/core.sh"; source "$SF_ROOT/lib/check.sh"
[[ -z "${SF_BUILD_MODE:-}" ]] && { [[ -f "$SF_STATE/build-mode" ]] && SF_BUILD_MODE="$(tr -d '[:space:]' < "$SF_STATE/build-mode")" || SF_BUILD_MODE="quick"; }
export SF_BUILD_MODE
module_files() { find "$SF_ROOT/modules" -maxdepth 1 -name '[0-9][0-9]-*.sh' | sort; }
module_name()  { local b; b="$(basename "$1" .sh)"; echo "${b#[0-9][0-9]-}"; }
module_num()   { basename "$1" | cut -c1-2; }
module_desc()  { sed -n 's/^# desc: //p' "$1" | head -1; }
in_list() {
    local f="$1" item; IFS=',' read -ra items <<< "$2"
    for item in "${items[@]}"; do [[ "$item" == "$(module_name "$f")" || "$item" == "$(module_num "$f")" ]] && return 0; done
    return 1
}
run_modules() {
    local f; for f in $(module_files); do
        [[ -n "$ONLY" ]] && ! in_list "$f" "$ONLY" && continue
        [[ -n "$SKIP" ]] && in_list "$f" "$SKIP" && continue
        section "$(module_num "$f") $(module_name "$f") — $(module_desc "$f")"
        source "$f"; module_run; unset -f module_run
    done
}
if [[ "$CMD_NAME" == "install" ]]; then
    [[ $EUID -eq 0 ]] && die "run as your normal user (sudo is used when needed)"
    mkdir -p "$SF_STATE"; mode_lbl="quick install"
    [[ "$SF_BUILD_MODE" == "source" ]] && mode_lbl="build-from-source (-march=native / target-cpu=native)"
    printf '%sSuperFedora v%s%s — %s [%s]\n' "$C_B" "$SF_VERSION" "$C_R" "$([[ $MODE == dry-run ]] && echo 'dry run, nothing will change' || echo 'installing what is missing')" "$mode_lbl"
    _log_file "superfedora $MODE v$SF_VERSION ($SF_BUILD_MODE)"
    run_modules; summary
    [[ $MODE == install ]] && { echo "$SF_VERSION" > "$SF_STATE/version"; echo "$SF_BUILD_MODE" > "$SF_STATE/build-mode"; [[ $SF_FAILED -eq 0 ]] || exit 1; }
else
    printf '%sSuperFedora v%s%s — status (installed: %s, mode: %s)\n' "$C_B" "$SF_VERSION" "$C_R" "$(cat "$SF_STATE/version" 2>/dev/null || echo none)" "$SF_BUILD_MODE"
    run_modules; summary
    tot=$((SF_OK + SF_MISSING + SF_FAILED)); [[ $tot -le 0 ]] && tot=1; pct=$((SF_OK * 100 / tot))
    printf '\n  \033[1;36mReadiness Score\033[0m  [\033[1;32m%d/%d checks passed (%d%%)\033[0m]\n' "$SF_OK" "$tot" "$pct"
    [[ $SF_MISSING -eq 0 && $SF_FAILED -eq 0 ]]
fi
"#;

    let mode = if cmd == "install" { if dry { "dry-run" } else { "install" } } else { "status" };
    let mut c = Command::new("bash");
    c.arg("-c").arg(script).env("SF_ROOT", &st.sf_root).env("CMD_NAME", cmd).env("MODE", mode).env("ONLY", only).env("SKIP", skip);
    if !build_mode.is_empty() { c.env("SF_BUILD_MODE", build_mode); }
    if verbose { c.env("SF_VERBOSE", "1"); }
    c.status().map(|s| s.code().unwrap_or(1)).unwrap_or(1)
}
