// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::ops::mode::active_mode;
use crate::state::WorkstationState;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

fn default_manifest_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let dir = PathBuf::from(home).join(".config/superfedora");
    let _ = fs::create_dir_all(&dir);
    dir.join("workstation.toml")
}

pub fn generate_manifest(st: &WorkstationState) -> String {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let cfg = PathBuf::from(&home).join(".config/superfedora");
    let ws_mode = active_mode();
    let ui_scale = fs::read_to_string(cfg.join("ui-scale")).ok().and_then(|s| s.trim().parse::<u32>().ok()).unwrap_or(15);
    let anim = fs::read_to_string(cfg.join("animations")).map(|s| s.trim() != "0" && s.trim() != "off").unwrap_or(true);
    let nl = fs::read_to_string(cfg.join("theme.env")).ok().and_then(|t| {
        t.lines().find_map(|l| l.strip_prefix("THEME_NIGHTLIGHT=")?.trim().trim_matches('"').to_string().into())
    }).unwrap_or_else(|| "off".into());
    let wall = fs::read_to_string(PathBuf::from(&home).join(".config/hypr/.current-wallpaper"))
        .unwrap_or_default()
        .trim()
        .to_string();
    let build_mode = fs::read_to_string(cfg.join("build-mode")).unwrap_or_else(|_| "quick".into()).trim().to_string();

    let forged: Vec<String> = st.forge_items.iter().filter(|i| i.installed).map(|i| format!("\"{}\"", i.name)).collect();
    let webapps: Vec<String> = st.webapps.iter().map(|(slug, _, url)| format!("\"{slug}|{url}\"")).collect();

    let dnd = fs::read_to_string(cfg.join("notifications.json"))
        .ok()
        .and_then(|s| serde_json::from_str::<serde_json::Value>(&s).ok())
        .and_then(|v| v.get("dnd").and_then(|b| b.as_bool()))
        .unwrap_or(false);
    let agent_id = fs::read_to_string(cfg.join("active-agent")).unwrap_or_else(|_| "agy".into()).trim().to_string();
    let ollama_host = fs::read_to_string(cfg.join("ollama-host")).unwrap_or_else(|_| "127.0.0.1:11434".into()).trim().to_string();
    let ollama_model = fs::read_to_string(cfg.join("ollama-model")).unwrap_or_else(|_| "qwen2.5-coder:7b".into()).trim().to_string();

    format!(
        "# SuperFedora Declarative Workstation Clone Manifest (workstation.toml)\n\
         [workstation]\n\
         version = \"{}\"\n\
         mode = \"{}\"\n\
         ui_scale = {}\n\
         animations = {}\n\n\
         [supertheme]\n\
         palette = \"{}\"\n\
         mode = \"{}\"\n\
         corners = \"{}\"\n\
         nightlight = \"{}\"\n\
         wallpaper = \"{}\"\n\
         sfx = {}\n\n\
         [superforge]\n\
         build_mode = \"{}\"\n\
         recipes = [{}]\n\
         webapps = [{}]\n\n\
         [supershell]\n\
         dock_position = \"{}\"\n\
         dock_autohide = \"{}\"\n\
         tiling_layout = \"{}\"\n\n\
         [supernotify]\n\
         dnd = {}\n\
         animations = {}\n\n\
         [superagent]\n\
         active_agent = \"{}\"\n\
         ollama_host = \"{}\"\n\
         ollama_model = \"{}\"\n",
        st.version, ws_mode, ui_scale, anim,
        st.theme_color, st.theme_mode, st.theme_corners, nl, wall, st.sfx_on,
        build_mode, forged.join(", "), webapps.join(", "),
        st.dock_pos, st.dock_autohide, st.tiling_layout,
        dnd, anim, agent_id, ollama_host, ollama_model
    )
}

pub fn run_export_cmd(st: &WorkstationState, args: &[String]) -> i32 {
    if args.iter().any(|a| a == "-h" || a == "--help" || a == "help") {
        println!("Usage: superfedora export [path|--stdout]");
        return 0;
    }
    let toml_txt = generate_manifest(st);
    if args.iter().any(|a| a == "-" || a == "--stdout") {
        print!("{toml_txt}");
        return 0;
    }
    let out_path = args.first().map(PathBuf::from).unwrap_or_else(default_manifest_path);
    if let Some(parent) = out_path.parent() && !parent.as_os_str().is_empty() {
        let _ = fs::create_dir_all(parent);
    }
    if let Err(e) = fs::write(&out_path, &toml_txt) {
        eprintln!("error: failed to write {}: {e}", out_path.display());
        return 1;
    }
    println!("  [OK] Exported declarative workstation manifest to {}", out_path.display());
    0
}

fn clean_toml_val(raw_val: &str) -> String {
    let v = raw_val.trim();
    if let Some(rest) = v.strip_prefix('"')
        && let Some(end) = rest.find('"')
    {
        return rest[..end].to_string();
    }
    if let Some(rest) = v.strip_prefix('\'')
        && let Some(end) = rest.find('\'')
    {
        return rest[..end].to_string();
    }
    v.split('#').next().unwrap_or(v).trim().trim_matches('"').to_string()
}

fn parse_kv(txt: &str, section: &str, key: &str) -> Option<String> {
    let mut cur_sec = "";
    for raw in txt.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if line.starts_with('[') && let Some(end) = line.find(']') {
            cur_sec = line[1..end].trim();
            continue;
        }
        if cur_sec == section && let Some((k, v)) = line.split_once('=') && k.trim() == key {
            return Some(clean_toml_val(v));
        }
    }
    None
}

pub fn run_import_cmd(st: &mut WorkstationState, args: &[String]) -> i32 {
    let mut dry = false;
    let mut path_arg: Option<PathBuf> = None;
    for a in args {
        match a.as_str() {
            "--dry-run" | "-n" => dry = true,
            "-h" | "--help" | "help" => {
                println!("Usage: superfedora import [path] [--dry-run]");
                return 0;
            }
            p => path_arg = Some(PathBuf::from(p)),
        }
    }
    let in_path = path_arg.unwrap_or_else(default_manifest_path);
    if !Path::new(&in_path).is_file() {
        eprintln!("error: workstation manifest not found: {}", in_path.display());
        return 1;
    }
    let Ok(txt) = fs::read_to_string(&in_path) else {
        eprintln!("error: unable to read {}", in_path.display());
        return 1;
    };
    let has_sec = ["[workstation]", "[supertheme]", "[superforge]", "[supershell]", "[supernotify]", "[superagent]"]
        .iter()
        .any(|s| txt.contains(s));
    if !has_sec {
        eprintln!("error: invalid or empty workstation manifest: {}", in_path.display());
        return 1;
    }

    let ws_mode = parse_kv(&txt, "workstation", "mode").unwrap_or_else(|| "balanced".into());
    let ui_scale = parse_kv(&txt, "workstation", "ui_scale").unwrap_or_else(|| "15".into());
    let palette = parse_kv(&txt, "supertheme", "palette").unwrap_or_else(|| st.theme_color.clone());
    let th_mode = parse_kv(&txt, "supertheme", "mode").unwrap_or_else(|| st.theme_mode.clone());
    let corners = parse_kv(&txt, "supertheme", "corners").unwrap_or_else(|| st.theme_corners.clone());
    let nightlight = parse_kv(&txt, "supertheme", "nightlight").unwrap_or_else(|| "off".into());
    let build_mode = parse_kv(&txt, "superforge", "build_mode").unwrap_or_else(|| "quick".into());
    let dock_pos = parse_kv(&txt, "supershell", "dock_position").unwrap_or_else(|| st.dock_pos.clone());
    let dock_hide = parse_kv(&txt, "supershell", "dock_autohide").unwrap_or_else(|| st.dock_autohide.clone());
    let tiling = parse_kv(&txt, "supershell", "tiling_layout").unwrap_or_else(|| st.tiling_layout.clone());
    let dnd = parse_kv(&txt, "supernotify", "dnd").unwrap_or_else(|| "false".into());
    let agent = parse_kv(&txt, "superagent", "active_agent").unwrap_or_else(|| "agy".into());
    let ol_host = parse_kv(&txt, "superagent", "ollama_host").unwrap_or_else(|| "127.0.0.1:11434".into());
    let ol_model = parse_kv(&txt, "superagent", "ollama_model").unwrap_or_else(|| "qwen2.5-coder:7b".into());

    println!("\x1b[1;38;5;141m[::] SUPERFEDORA DECLARATIVE WORKSTATION IMPORT ({})\x1b[0m", in_path.display());
    println!("  Workstation Mode : {ws_mode} (UI scale: {ui_scale}px)");
    println!("  SuperTheme       : {palette} ({th_mode}, {corners} corners, nightlight: {nightlight})");
    println!("  SuperShell Dock  : {dock_pos} (autohide: {dock_hide}, layout: {tiling})");
    println!("  SuperAgent       : {agent} (Ollama: {ol_host} // {ol_model})");

    if dry {
        println!("  [DRY-RUN] Declarative workstation manifest verified (0 mutations performed).");
        return 0;
    }

    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let cfg = PathBuf::from(&home).join(".config/superfedora");
    let _ = fs::create_dir_all(&cfg);
    for (f, val) in [
        ("workstation-mode", &ws_mode),
        ("ui-scale", &ui_scale),
        ("build-mode", &build_mode),
        ("dock-position", &dock_pos),
        ("dock-autohide", &dock_hide),
        ("tiling-layout", &tiling),
        ("active-agent", &agent),
        ("ollama-host", &ol_host),
        ("ollama-model", &ol_model),
    ] {
        let _ = fs::write(cfg.join(f), format!("{val}\n"));
    }
    let _ = fs::write(
        cfg.join("theme.env"),
        format!("THEME_COLOR=\"{palette}\"\nTHEME_MODE=\"{th_mode}\"\nTHEME_CORNERS=\"{corners}\"\nTHEME_NIGHTLIGHT=\"{nightlight}\"\n"),
    );
    let _ = Command::new("supertheme").args(["set", &palette, &th_mode, &corners]).stdout(Stdio::null()).stderr(Stdio::null()).status();
    let _ = Command::new("supernotify").args(["dnd", if dnd == "true" { "on" } else { "off" }]).stdout(Stdio::null()).stderr(Stdio::null()).status();
    let _ = crate::ops::mode::run_mode_cmd(st, &[ws_mode]);
    st.refresh();
    println!("  [OK] Imported declarative workstation configuration from {}", in_path.display());
    0
}
