// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::charts_cli::{
    ansi_rgb, bar_str, print_cartridge_banner, print_forge_charts, print_theme_swatches,
    print_vitals_charts, run_forge_update_graphical,
};
use crate::state::WorkstationState;
use crate::telemetry::Telemetry;
use crate::tui::run_tui;
use std::{env, io::{self, IsTerminal}, process::Command};

pub fn print_usage(st: &WorkstationState) {
    let (p, s, b, r) = (ansi_rgb(st.primary_rgb), ansi_rgb(st.secondary_rgb), "\x1b[1m", "\x1b[0m");
    println!("{p}{b}SuperFedora v{} — Native Rust 16-Bit Workstation Engine & TUI{r}", st.version);
    println!("Usage: {b}superfedora{r} [command] [options]\n");
    println!("{s}{b}Graphical TUI & Telemetry Commands:{r}");
    println!("  {b}tui | welcome | deck{r} Launch full-screen 16-Bit Rust Graphical TUI (default in TTY)");
    println!("  {b}vitals | charts{r}      Render live 16-bit CPU per-core, RAM, GPU, Thermal & Disk bar charts");
    println!("  {b}forge [target]{r}       Graphical Forge manager, binary size chart, 4-stage update & WebApps");
    println!("  {b}theme [action]{r}       16-Bit Rainbow Palette Studio & truecolor swatch matrix\n");
    println!("{s}{b}Workstation Orchestrator Commands:{r}");
    println!("  {b}install{r}              Check every module and install whatever is missing");
    println!("  {b}status | doctor{r}      Audit workstation modules & print readiness bar chart");
    println!("  {b}update{r}               Sync @SuperFedora repos, runtime tree, binaries & install");
    println!("  {b}uninstall{r}            Remove SuperFedora binaries/runtime or restore backups");
    println!("  {b}system-upgrade [ver]{r} Upgrade Fedora release (Snapper + dnf5 + superforge)");
    println!("  {b}hardware [action]{r}    GPU auto-detection, VA-API codecs & Firefox DMABUF tuning");
    println!("  {b}snapshot [action]{r}    Time-Machine Btrfs snapshot browser (list, diff, create, restore)");
    println!("  {b}mode [profile]{r}       16-Bit Workstation Mode (stealth, balanced, forge, arcade)");
    println!("  {b}export | import{r}      Declarative workstation.toml backup, export & clone");
    println!("  {b}service [action]{r}     Inspect/control systemd OS & user session units/timers");
    println!("  {b}repo [status|test]{r}   Multi-repo orchestration across @SuperFedora repos");
    println!("  {b}build [action]{r}       Compile & tune core stack from source (-march=native)");
    println!("  {b}dotfiles [--check]{r}   Deploy desktop configs (or list drift from this release)");
    println!("  {b}bar | notify | ai{r}    Control SuperBar, SuperNotify Cast Comms & AI settings");
    println!("  {b}session | sfx{r}        Switch Desktop Environment session or 16-bit SFX engine");
    println!("  {b}modules | rollback{r}   List installer modules or run Btrfs Boot-Guard rollback");
    println!("  {b}version{r}              Print the SuperFedora Rust engine version\n");
    println!("{s}{b}Install / Audit Options:{r}");
    println!("  --race               Two-Stage Race: easy binaries first, background -march=native builds after (default)");
    println!("  --quick              Use prebuilt binary packages only");
    println!("  --build-from-source  Compile & tune upfront for localhost hardware (-march=native)");
    println!("  --dry-run            Show what would be installed without changes");
    println!("  --only / --skip a,b  Filter installer modules (e.g. 40,desktop)");
    println!("  -v, --verbose        Show verbose command output");
    println!("  -h, --help           Show this help");
}

pub fn dispatch(cmd: &str, args: &[String], st: &mut WorkstationState) -> i32 {
    match cmd {
        "" => if io::stdin().is_terminal() && io::stdout().is_terminal() { run_tui(0) } else { print_usage(st); 0 },
        "-h" | "--help" | "help" => { print_usage(st); 0 }
        "version" | "--version" | "-V" => {
            println!("SuperFedora {} (SuperFedora/superfedora — Rust 1.99 Native Engine)", st.version);
            0
        }
        "vitals" | "charts" | "top" | "telemetry" => { print_vitals_charts(st, &mut Telemetry::new()); 0 }
        "tui" | "welcome" | "deck" => match args.first().map(|s| s.as_str()) {
            Some("status" | "banner") => { print_vitals_charts(st, &mut Telemetry::new()); 0 }
            Some("forge") => run_tui(1),
            Some("theme" | "themes") => run_tui(2),
            Some("snapshot" | "time-machine") => run_tui(3),
            Some("rollback" | "snapshots") => exec_script(st, "lib/tui.sh", &prepend("rollback", &args[1..])),
            Some("-h" | "--help" | "help") => exec_script(st, "lib/tui.sh", args),
            _ => if io::stdin().is_terminal() && io::stdout().is_terminal() { run_tui(0) } else { print_cartridge_banner(st, &Telemetry::new()); 0 },
        },
        "forge" | "superforge" => match args.first().map(|s| s.as_str()) {
            None | Some("status" | "list") => { print_forge_charts(st); 0 }
            Some("tui") => run_tui(1),
            Some("update" | "upgrade") if args.len() == 1 => run_forge_update_graphical(st),
            _ => { let code = exec_bin_or_script(st, "superforge", "lib/forge.sh", args); st.refresh(); code }
        },
        "theme" | "themes" | "supertheme" => match args.first().map(|s| s.as_str()) {
            None | Some("list" | "swatches") => { print_theme_swatches(st); 0 }
            Some("tui") => run_tui(2),
            _ => exec_bin_or_script(st, "supertheme", "lib/apply-theme.sh", args),
        },
        "hardware" | "gpu" | "codecs" | "vaapi" => crate::ops::hardware::run_hardware_cmd(st, args),
        "snapshot" | "time-machine" => crate::ops::snapshot::run_snapshot_cmd(st, args),
        "mode" | "profile" | "power-mode" => crate::ops::mode::run_mode_cmd(st, args),
        "export" | "backup" => crate::ops::workstation::run_export_cmd(st, args),
        "import" | "clone" => crate::ops::workstation::run_import_cmd(st, args),
        "uninstall" | "remove" | "purge" => crate::ops::uninstall::run_uninstall_cmd(st, args),
        "system-upgrade" | "dist-upgrade" | "release-upgrade" => crate::ops::run_system_upgrade(st, args),
        "service" | "services" | "systemd" => crate::ops::run_service_cmd(st, args),
        "repo" | "repos" => crate::ops::run_repo_cmd(st, args),
        "dock" | "superdock" | "panel" | "panels" => exec_script(st, "lib/panel-ctl.sh", args),
        "bar" | "superbar" => exec_bin_or_script(st, "superbar", "lib/panel-ctl.sh", args),
        "notify" | "supernotify" | "notifications" | "notif" => exec_bin_or_script(st, "supernotify", "lib/notify-ctl.sh", args),
        "lock" | "superlock" | "session" | "de" => exec_bin_or_script(st, "superlock", "lib/session-ctl.sh", args),
        "build" | "source" => exec_bin_or_script(st, "superforge", "lib/build-source.sh", args),
        "sfx" | "sound" => exec_bin_or_script(st, "supertheme", "lib/sfx.sh", &prepend("sfx", args)),
        "dotfiles" => exec_script(st, "lib/install-dotfiles.sh", args),
        "rollback" | "snapshots" => {
            if matches!(args.first().map(|s| s.as_str()), Some("list" | "diff" | "create" | "restore")) {
                crate::ops::snapshot::run_snapshot_cmd(st, args)
            } else {
                exec_script(st, "lib/tui.sh", &prepend("rollback", args))
            }
        }
        "agent" | "superagent" | "ai" | "quake" => exec_bin_or_script(st, "supersettings", "lib/panel-ctl.sh", &prepend("ai", args)),
        "webcam" | "camera" | "mic" | "speaker" => exec_bin_or_script(st, "supersettings", "lib/panel-ctl.sh", &prepend("apply", &prepend(cmd, args))),
        "io" => exec_bin_or_script(st, "supersettings", "lib/panel-ctl.sh", &prepend("apply", args)),
        "settings-probe" => { crate::settings_engine::print_probe(); 0 }
        "settings-apply" => crate::settings_engine::apply_setting(args),
        "settings" | "supersettings" | "config" => {
            if let Some(sub) = args.first().map(|s| s.as_str()) {
                if sub == "probe" { crate::settings_engine::print_probe(); return 0; }
                if sub == "apply" { return crate::settings_engine::apply_setting(&args[1..]); }
            }
            exec_bin_or_script(st, "supersettings", "lib/panel-ctl.sh", args)
        }
        "modules" | "list" => {
            let (p, s) = (ansi_rgb(st.primary_rgb), ansi_rgb(st.secondary_rgb));
            println!("{p}\x1b[1m━━ SUPERFEDORA WORKSTATION MODULES ({})\x1b[0m", st.modules.len());
            for (num, name, desc, _) in &st.modules {
                println!("  {s}\x1b[1m{num}\x1b[0m  \x1b[1m{name:<14}\x1b[0m {}  {desc}", bar_str(100, 10, st.primary_rgb));
            }
            0
        }
        "install" | "status" | "check" | "audit" | "doctor" | "update" => run_module_engine(cmd, args, st),
        _ => { eprintln!("unknown command: {cmd}"); print_usage(st); 2 }
    }
}

fn prepend(first: &str, rest: &[String]) -> Vec<String> {
    let mut v = Vec::with_capacity(rest.len() + 1);
    v.push(first.to_string());
    v.extend_from_slice(rest);
    v
}

fn exec_bin_or_script(st: &WorkstationState, bin_name: &str, rel: &str, args: &[String]) -> i32 {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    for cand in [std::path::Path::new(&home).join(".local/bin").join(bin_name), std::path::PathBuf::from("/usr/local/bin").join(bin_name)] {
        if cand.is_file() {
            return Command::new(cand).env("SF_ROOT", &st.sf_root).args(args).status().map(|s| s.code().unwrap_or(0)).unwrap_or(1);
        }
    }
    exec_script(st, rel, args)
}

fn exec_script(st: &WorkstationState, rel: &str, args: &[String]) -> i32 {
    Command::new(st.sf_root.join(rel)).env("SF_ROOT", &st.sf_root).args(args).status().map(|s| s.code().unwrap_or(0)).unwrap_or(1)
}

fn run_module_engine(cmd: &str, args: &[String], st: &WorkstationState) -> i32 {
    let mut build_mode = match env::var("SUPERFEDORA_BUILD_MODE").unwrap_or_default().to_ascii_lowercase().as_str() {
        "race" | "hybrid" | "two-stage" => "race",
        "source" | "native" | "build-from-source" => "source",
        "quick" | "binary" | "prebuilt" => "quick",
        _ => "",
    }
    .to_string();
    let (mut only, mut skip, mut dry, mut verbose, mut i) = (String::new(), String::new(), false, false, 0);
    while i < args.len() {
        match args[i].as_str() {
            "--race" | "--hybrid" => build_mode = "race".into(),
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
[[ -z "${SF_BUILD_MODE:-}" ]] && { [[ -f "$SF_STATE/build-mode" ]] && SF_BUILD_MODE="$(tr -d '[:space:]' < "$SF_STATE/build-mode")" || SF_BUILD_MODE="race"; }
export SF_BUILD_MODE
sync_runtime_tree() {
    local dst="${XDG_DATA_HOME:-$HOME/.local/share}/superfedora" src="$SF_ROOT" d f ws="$HOME/Projects/superfedora"
    [[ -d "$ws/superfedora/lib" ]] && src="$ws/superfedora"
    if [[ "$(realpath "$src" 2>/dev/null)" != "$(realpath "$dst" 2>/dev/null)" ]]; then
        mkdir -p "$dst"
        for d in bin lib modules packages scripts system docs dotfiles; do
            [[ -d "$src/$d" ]] && { rm -rf "$dst/$d.new"; cp -a "$src/$d" "$dst/$d.new" && rm -rf "$dst/$d" && mv "$dst/$d.new" "$dst/$d"; }
        done
        for f in VERSION install.sh AGENTS.md README.md LICENSE CHANGELOG.md; do [[ -f "$src/$f" ]] && cp -a "$src/$f" "$dst/$f"; done
    fi
    [[ -d "$ws/superforge/lib" ]] && { mkdir -p "$HOME/.local/share/superforge" && cp -rf "$ws/superforge/lib" "$ws/superforge/scripts" "$HOME/.local/share/superforge/" 2>/dev/null || true; }
    rm -f "$dst/forge/stamps/superagent.stamp" "$dst/forge/stamps/superdock.stamp" "$SF_STATE/source-built/superagent.stamp" "$SF_STATE/source-built/superdock.stamp" 2>/dev/null || true
    [[ -f "$SF_STATE/forge.json" ]] && python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); t=d.get("targets",{}); c=any(t.pop(k,None) for k in ("superagent","superdock")); ts=t.get("supershell",{}); (ts.get("binary","").endswith("/superdock") and (ts.update({"binary":ts["binary"][:-9]+"supersettings"}) or True) and (c:=True)); c and json.dump(d,open(p,"w"),indent=2)' "$SF_STATE/forge.json" 2>/dev/null || true
    for f in "$dst/forge/stamps/supershell.stamp" "$SF_STATE/source-built/supershell.stamp"; do [[ -f "$f" ]] && sed -i 's|/superdock$|/supersettings|' "$f" 2>/dev/null || true; done
    rm -f "$src/bin/sf" "$dst/bin/sf" "$HOME/.local/bin/sf" 2>/dev/null || true
    [[ -x "$src/bin/superfedora" && -f /usr/local/bin/superfedora ]] && { sudo -n install -m 755 "$src/bin/superfedora" /usr/local/bin/superfedora 2>/dev/null || true; sudo -n rm -f /usr/local/bin/sf 2>/dev/null || true; }
    SF_ROOT="$src"; SF_VERSION="$(tr -d '[:space:]' < "$src/VERSION" 2>/dev/null || echo "$SF_VERSION")"; export SF_ROOT SF_VERSION
}
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
if [[ "$CMD_NAME" == "update" && "$MODE" != "dry-run" ]]; then
    for r in superfedora superforge supertheme supernotify superbar supershell superfedora.github.io .github; do
        [[ -d "$HOME/Projects/superfedora/$r/.git" ]] && git -C "$HOME/Projects/superfedora/$r" pull --ff-only 2>/dev/null || true
    done
    sync_runtime_tree
    FORGE_CMD="$(command -v superforge 2>/dev/null || echo "$SF_ROOT/lib/forge.sh")"
    [[ -z "$ONLY" && "$SF_BUILD_MODE" == "source" ]] && for c in superforge supertheme superbar supershell supernotify superfedora; do "$FORGE_CMD" build "$c"; done
fi
if [[ "$CMD_NAME" == "install" || "$CMD_NAME" == "update" ]]; then
    [[ $EUID -eq 0 ]] && die "run as your normal user (sudo is used when needed)"
    mkdir -p "$SF_STATE"; mode_lbl="quick install"
    [[ "$SF_BUILD_MODE" == "race" ]] && mode_lbl="two-stage race via SuperForge (easy binaries first -> background -march=native builds)"
    [[ "$SF_BUILD_MODE" == "source" ]] && mode_lbl="build-from-source (-march=native / target-cpu=native)"
    [[ $MODE == install ]] && sync_runtime_tree
    printf '%sSuperFedora v%s%s — %s [%s]\n' "$C_B" "$SF_VERSION" "$C_R" "$([[ $MODE == dry-run ]] && echo 'dry run, nothing will change' || echo 'installing what is missing')" "$mode_lbl"
    _log_file "superfedora $MODE v$SF_VERSION ($SF_BUILD_MODE)"
    run_modules; summary
    if [[ $MODE == install ]]; then
        echo "$SF_VERSION" > "$SF_STATE/version"; echo "$SF_BUILD_MODE" > "$SF_STATE/build-mode"
        [[ "$SF_BUILD_MODE" == "race" && -z "$ONLY" ]] && "$(command -v superforge 2>/dev/null || echo "$SF_ROOT/lib/forge.sh")" background-reforge --async
    fi
    [[ $SF_FAILED -eq 0 ]] || exit 1
else
    printf '%sSuperFedora v%s%s — status (installed: %s, mode: %s)\n' "$C_B" "$SF_VERSION" "$C_R" "$(cat "$SF_STATE/version" 2>/dev/null || echo none)" "$SF_BUILD_MODE"
    run_modules; summary
    tot=$((SF_OK + SF_MISSING + SF_FAILED)); [[ $tot -le 0 ]] && tot=1; pct=$((SF_OK * 100 / tot))
    printf '\n  \033[1;36mReadiness Score\033[0m  [\033[1;32m%d/%d checks passed (%d%%)\033[0m]\n' "$SF_OK" "$tot" "$pct"
    [[ $SF_MISSING -eq 0 && $SF_FAILED -eq 0 ]]
fi
"#;

    let mode = if cmd == "install" || cmd == "update" { if dry { "dry-run" } else { "install" } } else { "status" };
    let mut c = Command::new("bash");
    c.arg("-c").arg(script).env("SF_ROOT", &st.sf_root).env("CMD_NAME", cmd).env("MODE", mode).env("ONLY", only).env("SKIP", skip);
    if !build_mode.is_empty() { c.env("SF_BUILD_MODE", build_mode); }
    if verbose { c.env("SF_VERBOSE", "1"); }
    c.status().map(|s| s.code().unwrap_or(1)).unwrap_or(1)
}
