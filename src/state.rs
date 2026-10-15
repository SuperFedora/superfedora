// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use ratatui::style::Color;
use serde::Deserialize;
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

pub const PALETTES: &[(&str, &str, (u8, u8, u8), (u8, u8, u8))] = &[
    ("01-crimson", "Crimson", (247, 118, 142), (255, 158, 100)), ("02-scarlet", "Scarlet", (255, 95, 110), (247, 118, 142)),
    ("03-ember", "Ember", (255, 122, 89), (224, 175, 104)), ("04-amber", "Amber", (255, 158, 100), (224, 175, 104)),
    ("05-topaz", "Topaz", (224, 175, 104), (158, 206, 106)), ("06-citrine", "Citrine", (240, 208, 104), (115, 218, 202)),
    ("07-peridot", "Peridot", (180, 224, 108), (115, 218, 202)), ("08-emerald", "Emerald", (158, 206, 106), (115, 218, 202)),
    ("09-verdant", "Verdant", (115, 218, 202), (125, 207, 255)), ("10-lagoon", "Lagoon", (42, 195, 222), (122, 162, 247)),
    ("11-glacier", "Glacier", (125, 207, 255), (187, 154, 247)), ("12-cobalt", "Cobalt", (122, 162, 247), (187, 154, 247)),
    ("13-indigo", "Indigo", (130, 140, 255), (125, 207, 255)), ("14-violet", "Violet", (187, 154, 247), (122, 162, 247)),
    ("15-orchid", "Orchid", (211, 134, 247), (247, 118, 142)), ("16-fuchsia", "Fuchsia", (255, 117, 195), (125, 207, 255)),
];

pub const FORGE_CATALOG: &[(&str, &str, &str, &str)] = &[
    ("superfedora", "superfedora", "rust", "16-Bit Rust Workstation Engine & TUI"),
    ("supertheme", "supertheme", "rust", "16-Bit Palette, Wallpaper, Cast & SFX Engine"),
    ("superforge", "superforge", "rust", "Native -march=native Source Compiler & WebApps"),
    ("supershell", "superdock", "rust", "16-Bit Wayland Shell Suite (Dock/Bar/Settings/Lock)"),
    ("supernotify", "supernotify", "rust", "16-Bit Animated Cast Comms & Stage Banners"),
    ("superagent", "superagent", "rust", "Standalone Autonomous Agent & Cast Comms Daemon"),
    ("ripgrep", "rg", "rust", "SIMD-accelerated regex search tool"),
    ("fastfetch", "fastfetch", "cmake", "Native C system info fetcher"),
    ("idlescreen", "idlescreen", "rust", "16-Bit Wayland idle screensaver daemon"),
    ("fd", "fd", "rust", "Fast parallel filesystem finder"),
    ("zoxide", "zoxide", "rust", "Smarter cd directory jumper"),
    ("btop", "btop", "cpp", "C++20 hardware & GPU monitor"),
    ("wlctl", "wlctl", "rust", "16-Bit TUI Wi-Fi / NetworkManager controller"),
    ("bluetui", "bluetui", "rust", "16-Bit TUI Bluetooth manager"),
    ("wiremix", "wiremix", "rust", "16-Bit PipeWire TUI audio mixer"),
    ("fuzzel", "fuzzel", "meson", "Wayland native app launcher"),
    ("openrgb", "openrgb", "qmake", "Open source RGB lighting control"),
    ("hyprland", "Hyprland", "cmake", "Dynamic tiling Wayland compositor"),
    ("quickshell", "quickshell", "cmake", "Qt6 Wayland shell toolkit"),
    ("yazi", "yazi", "rust", "Async terminal file manager with Kitty image previews"),
    ("dua-cli", "dua", "rust", "Interactive disk usage analyzer & cleaner"),
    ("ouch", "ouch", "rust", "Unified archive compressor/decompressor"),
    ("oculante", "oculante", "rust", "Fast minimal Rust GPU image viewer & editor"),
    ("imv", "imv", "meson", "Wayland-native image viewer"),
    ("satty", "satty", "rust", "Modern Wayland screenshot annotation tool"),
    ("hyprpicker", "hyprpicker", "cmake", "wlroots/Hyprland pixel color picker"),
    ("wl-screenrec", "wl-screenrec", "rust", "VA-API hardware-accelerated Wayland screen recorder"),
    ("zathura", "zathura", "meson", "Keyboard-driven PDF/EPUB/DjVu viewer"),
    ("typst", "typst", "rust", "Modern typesetter & PDF compiler"),
    ("csvlens", "csvlens", "rust", "Interactive TUI CSV/TSV spreadsheet viewer"),
    ("helix", "hx", "rust", "Post-modern modal text editor"),
    ("fend", "fend", "rust", "Arbitrary-precision unit-aware calculator"),
    ("termusic", "termusic", "rust", "Terminal music & podcast player"),
    ("cava", "cava", "cmake", " real-time PipeWire audio spectrum visualizer"),
    ("mpv", "mpv", "meson", "GPU-accelerated media player"),
    ("cliphist", "cliphist", "go", "Wayland clipboard history manager"),
    ("bazarr", "bazarr", "python", "Companion subtitle manager for Sonarr & Radarr"),
];

#[derive(Clone, Default, Deserialize)]
pub struct ForgeLive {
    #[serde(default)] pub active: bool,
    #[serde(default)] pub target: String,
    #[serde(default)] pub pct: u16,
    #[serde(default)] pub step: String,
}

#[derive(Clone)]
pub struct ForgeItem {
    pub name: String,
    pub kind: String,
    pub desc: String,
    pub installed: bool,
    pub size_kb: u64,
}

#[derive(Clone)]
pub struct WorkstationState {
    pub sf_root: PathBuf,
    pub state_dir: PathBuf,
    pub version: String,
    pub theme_color: String,
    pub theme_mode: String,
    pub theme_corners: String,
    pub primary_rgb: (u8, u8, u8),
    pub secondary_rgb: (u8, u8, u8),
    pub sfx_on: bool,
    pub dock_pos: String,
    pub dock_autohide: String,
    pub tiling_layout: String,
    pub baseline_snap: String,
    pub guard_status: String,
    pub forge_items: Vec<ForgeItem>,
    pub webapps: Vec<(String, String, String)>,
    pub forge_live: ForgeLive,
    pub snapshots: Vec<String>,
    pub modules: Vec<(String, String, String, bool)>,
}

impl WorkstationState {
    pub fn load() -> Self {
        let sf_root = Self::resolve_root();
        let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
        let state_dir = env::var("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from(&home).join(".config")).join("superfedora");
        if !state_dir.exists() && Path::new("/etc/skel/.config/superfedora").is_dir() {
            let _ = fs::create_dir_all(state_dir.join("cast"));
            if let Ok(entries) = fs::read_dir("/etc/skel/.config/superfedora") {
                for e in entries.flatten() {
                    let p = e.path();
                    if p.is_file() {
                        let _ = fs::copy(&p, state_dir.join(e.file_name()));
                    } else if p.is_dir() && let Ok(sub) = fs::read_dir(&p) {
                        let dst_sub = state_dir.join(e.file_name());
                        let _ = fs::create_dir_all(&dst_sub);
                        for se in sub.flatten() { let _ = fs::copy(se.path(), dst_sub.join(se.file_name())); }
                    }
                }
            }
        }
        let version = fs::read_to_string(sf_root.join("VERSION")).unwrap_or_else(|_| "0.8.0".into()).trim().to_string();
        let mut st = Self {
            version, sf_root, state_dir, theme_color: "12-cobalt".into(), theme_mode: "dark".into(), theme_corners: "square".into(),
            primary_rgb: (122, 162, 247), secondary_rgb: (187, 154, 247), sfx_on: true, dock_pos: "bottom".into(),
            dock_autohide: "always".into(), tiling_layout: "dwindle".into(), baseline_snap: "none".into(), guard_status: "ready".into(),
            forge_items: Vec::new(), webapps: Vec::new(), forge_live: ForgeLive::default(), snapshots: Vec::new(), modules: Vec::new(),
        };
        st.refresh();
        st
    }

    pub fn resolve_root() -> PathBuf {
        if let Ok(r) = env::var("SF_ROOT") {
            let p = PathBuf::from(r);
            if p.join("lib/core.sh").is_file() { return p; }
        }
        if let Ok(exe) = env::current_exe()
            && let Ok(real) = fs::canonicalize(&exe)
            && let Some(parent) = real.parent().and_then(|p| p.parent())
            && parent.join("lib/core.sh").is_file()
        {
            return parent.to_path_buf();
        }
        let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
        for cand in [PathBuf::from(&home).join("Projects/superfedora/superfedora"), PathBuf::from(&home).join(".local/share/superfedora"), PathBuf::from("/usr/share/superfedora")] {
            if cand.join("lib/core.sh").is_file() { return cand; }
        }
        PathBuf::from(home).join(".local/share/superfedora")
    }

    pub fn primary_color(&self) -> Color { Color::Rgb(self.primary_rgb.0, self.primary_rgb.1, self.primary_rgb.2) }
    pub fn secondary_color(&self) -> Color { Color::Rgb(self.secondary_rgb.0, self.secondary_rgb.1, self.secondary_rgb.2) }

    pub fn refresh_fast(&mut self) {
        self.forge_live = fs::read_to_string(self.state_dir.join("forge-live.json")).ok().and_then(|s| serde_json::from_str(&s).ok()).unwrap_or_default();
    }

    pub fn refresh(&mut self) {
        if let Ok(txt) = fs::read_to_string(self.state_dir.join("theme.env")) {
            for line in txt.lines() {
                if let Some((k, v)) = line.split_once('=') {
                    let val = v.trim().trim_matches('"').trim_matches('\'');
                    match k.trim() {
                        "THEME_COLOR" => self.theme_color = val.to_string(),
                        "THEME_MODE" => self.theme_mode = val.to_string(),
                        "THEME_CORNERS" => self.theme_corners = val.to_string(),
                        _ => {}
                    }
                }
            }
        }
        if let Some((_, _, p, s)) = PALETTES.iter().find(|(id, _, _, _)| *id == self.theme_color) {
            self.primary_rgb = *p;
            self.secondary_rgb = *s;
        }
        self.sfx_on = fs::read_to_string(self.state_dir.join("sfx")).map(|s| s.trim() != "off").unwrap_or(true);
        self.dock_pos = fs::read_to_string(self.state_dir.join("dock-position")).unwrap_or_else(|_| "bottom".into()).trim().to_string();
        self.dock_autohide = fs::read_to_string(self.state_dir.join("dock-autohide")).unwrap_or_else(|_| "always".into()).trim().to_string();
        self.tiling_layout = fs::read_to_string(self.state_dir.join("tiling-layout")).unwrap_or_else(|_| "dwindle".into()).trim().to_string();
        self.baseline_snap = fs::read_to_string(self.state_dir.join("last_pre_install_snapshot")).unwrap_or_else(|_| "none".into()).trim().to_string();
        self.refresh_fast();
        self.refresh_forge();
        self.refresh_modules();
    }

    fn refresh_forge(&mut self) {
        let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
        let bin_dir = Path::new(&home).join(".local/bin");
        let sys_bin = Path::new("/usr/local/bin");
        let stamp_dir = env::var("XDG_DATA_HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from(&home).join(".local/share")).join("superfedora/forge/stamps");
        let legacy_stamp_dir = self.state_dir.join("source-built");
        self.forge_items = FORGE_CATALOG
            .iter()
            .map(|&(name, bin_name, sys, desc)| {
                let bin_path = if bin_dir.join(bin_name).exists() { bin_dir.join(bin_name) } else { sys_bin.join(bin_name) };
                let installed = stamp_dir.join(format!("{name}.stamp")).exists() || legacy_stamp_dir.join(format!("{name}.stamp")).exists() || bin_path.exists();
                let size_kb = fs::metadata(&bin_path).map(|m| m.len() / 1024).unwrap_or(0);
                ForgeItem { name: name.into(), kind: sys.into(), desc: desc.into(), installed, size_kb }
            })
            .collect();
        self.webapps.clear();
        if let Ok(txt) = fs::read_to_string(self.state_dir.join("forge.json"))
            && let Ok(val) = serde_json::from_str::<serde_json::Value>(&txt)
            && let Some(targets) = val.get("targets").and_then(|w| w.as_object())
        {
            for (slug, info) in targets {
                if info.get("type").and_then(|v| v.as_str()) == Some("webapp") {
                    let name = info.get("name").and_then(|v| v.as_str()).unwrap_or(slug).to_string();
                    let url = info.get("url").and_then(|v| v.as_str()).unwrap_or("").to_string();
                    self.webapps.push((slug.clone(), name, url));
                }
            }
        }
    }

    fn refresh_modules(&mut self) {
        let mut mods = Vec::new();
        if let Ok(entries) = fs::read_dir(self.sf_root.join("modules")) {
            let mut map = BTreeMap::new();
            for e in entries.flatten() {
                let fname = e.file_name().to_string_lossy().to_string();
                if fname.ends_with(".sh") && fname.len() > 4 { map.insert(fname, e.path()); }
            }
            for (fname, path) in map {
                let num = fname.chars().take(2).collect::<String>();
                let name = fname.trim_end_matches(".sh").get(3..).unwrap_or(&fname).to_string();
                let desc = fs::read_to_string(&path)
                    .ok()
                    .and_then(|t| t.lines().find_map(|l| l.strip_prefix("# desc: ").map(|s| s.trim().to_string())))
                    .unwrap_or_else(|| "Workstation module".into());
                mods.push((num, name, desc, true));
            }
        }
        self.modules = mods;
    }

    pub fn load_snapshots(&mut self) {
        self.snapshots = crate::ops::snapshot::query_snapper_rows()
            .into_iter()
            .map(|(id, kind, ts, desc)| format!("#{id:<4}  {kind:<8}  {ts:<20}  {desc}"))
            .collect();
    }
}
