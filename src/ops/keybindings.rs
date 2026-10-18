// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::WorkstationState;
use std::fs;

const KEY_NAMES: &[(&str, &str)] = &[
    ("left", "←"),
    ("right", "→"),
    ("up", "↑"),
    ("down", "↓"),
    ("Return", "Enter"),
    ("Escape", "Esc"),
    ("SUPER_L", "Super (tap)"),
    ("grave", "`"),
    ("equal", "="),
    ("minus", "-"),
    ("period", "."),
    ("comma", ","),
    ("slash", "/"),
    ("BackSpace", "Backspace"),
    ("space", "Space"),
    ("mouse:272", "Left drag"),
    ("mouse:273", "Right drag"),
    ("mouse:274", "Middle click"),
    ("mouse:275", "Mouse back"),
    ("mouse:276", "Mouse forward"),
    ("mouse_down", "Scroll down"),
    ("mouse_up", "Scroll up"),
];

fn fmt_combo(mods: &str, key: &str) -> String {
    if key == "SUPER_L" {
        return "Super (tap)".into();
    }
    let mut parts: Vec<String> = mods
        .split_whitespace()
        .filter(|m| !m.is_empty())
        .map(|m| {
            let mut ch = m.chars();
            match ch.next() {
                Some(f) => f.to_uppercase().collect::<String>() + &ch.as_str().to_lowercase(),
                None => String::new(),
            }
        })
        .collect();
    let k = KEY_NAMES
        .iter()
        .find(|(raw, _)| *raw == key)
        .map(|(_, mapped)| *mapped)
        .unwrap_or_else(|| key.strip_prefix("XF86").unwrap_or(key));
    parts.push(k.to_string());
    parts.join(" + ")
}

pub fn run_keybindings_doc(st: &WorkstationState, args: &[String]) -> i32 {
    let cwd = std::env::current_dir().unwrap_or_else(|_| st.sf_root.clone());
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let share = std::path::PathBuf::from(home).join(".local/share/superfedora");
    let repo = [&cwd, &st.sf_root, &share]
        .into_iter()
        .find(|p| p.join("dotfiles/.config/hypr/conf/bindings.conf").is_file())
        .unwrap_or(&st.sf_root);
    let src = repo.join("dotfiles/.config/hypr/conf/bindings.conf");
    let out_path = repo.join("docs/keybindings.md");
    let version = fs::read_to_string(repo.join("VERSION"))
        .unwrap_or_else(|_| st.version.clone())
        .trim()
        .to_string();
    let Ok(raw_src) = fs::read_to_string(&src) else {
        eprintln!("FAIL: could not read {}", src.display());
        return 1;
    };

    let mut sections: Vec<(String, Vec<(String, String)>)> = Vec::new();
    let mut current: (String, Vec<(String, String)>) = ("General".into(), Vec::new());
    let mut submap: Option<String> = None;

    for line in raw_src.lines() {
        let trimmed = line.trim();
        if let Some(after_hash) = trimmed.strip_prefix('#') {
            let s = after_hash.trim_start();
            if s.starts_with('═') {
                let inner = s.trim_matches('═').trim();
                if !inner.is_empty() {
                    if !current.1.is_empty() {
                        sections.push(current);
                    }
                    current = (inner.to_string(), Vec::new());
                    continue;
                }
            }
        }
        if let Some(rest) = trimmed.strip_prefix("submap") {
            let rest = rest.trim_start();
            if let Some(eq_rhs) = rest.strip_prefix('=') {
                let target = eq_rhs.split_whitespace().next().unwrap_or("");
                if !target.is_empty() {
                    submap = if target == "reset" { None } else { Some(target.to_string()) };
                    continue;
                }
            }
        }
        if let Some(rest) = trimmed.strip_prefix("bind") {
            let Some((flags, rhs)) = rest.split_once('=') else { continue };
            let flags = flags.trim();
            if !flags.chars().all(|c| c.is_ascii_lowercase()) || !flags.contains('d') {
                continue;
            }
            let fields: Vec<&str> = rhs.split(',').map(|f| f.trim()).collect();
            if fields.len() < 3 {
                continue;
            }
            let mut combo = fmt_combo(fields[0], fields[1]);
            if let Some(ref sm) = submap {
                combo = format!("{combo} *(in {sm} mode)*");
            }
            current.1.push((combo, fields[2].to_string()));
        }
    }
    if !current.1.is_empty() {
        sections.push(current);
    }

    let mut out = vec![
        "# SuperFedora Keybindings".to_string(),
        String::new(),
        format!(
            "> Generated from [`bindings.conf`](../dotfiles/.config/hypr/conf/bindings.conf) for **SuperFedora v{version}** by `superfedora keybindings-doc`. Do not edit by hand."
        ),
        ">".to_string(),
        "> Bindings mirror Pop!_OS COSMIC defaults. Press **Super + F1** on the desktop for a searchable list.".to_string(),
        String::new(),
    ];
    let mut total_bindings = 0usize;
    for (title, rows) in &sections {
        total_bindings += rows.len();
        out.push(format!("## {title}"));
        out.push(String::new());
        out.push("| Keys | Action |".to_string());
        out.push("| :--- | :--- |".to_string());
        for (c, d) in rows {
            out.push(format!("| {c} | {d} |"));
        }
        out.push(String::new());
    }
    let rendered = out.join("\n");
    if args.iter().any(|a| a == "--check" || a == "-c") {
        let cur = fs::read_to_string(&out_path).unwrap_or_default();
        if cur != rendered {
            eprintln!("FAIL: docs/keybindings.md is out of sync with dotfiles/.config/hypr/conf/bindings.conf");
            return 1;
        }
        println!("OK: docs/keybindings.md matches dotfiles/.config/hypr/conf/bindings.conf ({total_bindings} bindings)");
        return 0;
    }
    if let Err(e) = fs::write(&out_path, &rendered) {
        eprintln!("FAIL: could not write docs/keybindings.md: {e}");
        return 1;
    }
    println!("wrote docs/keybindings.md ({total_bindings} bindings)");
    0
}
