// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::{PALETTES, WorkstationState};
use crate::telemetry::Telemetry;
use crate::ui_forge::render_forge;
use crate::ui_header::{TAB_TITLES, render_footer, render_header};
use crate::ui_panels::{render_dock_tuis, render_doctor, render_snapshots, render_themes};
use crate::ui_vitals::render_vitals;
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{
    Terminal,
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
};
use std::io;
use std::process::{Command, Stdio};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};
use std::thread;
use std::time::{Duration, Instant};

pub fn run_tui(initial_tab: usize) -> i32 {
    let mut st = WorkstationState::load();
    st.load_snapshots();
    let mut tel = Telemetry::new();
    let _ = Command::new(bin_or_script(&st, "supertheme", "lib/sfx.sh")).args(["sfx", "play", "startup"]).stdout(Stdio::null()).stderr(Stdio::null()).spawn();

    if enable_raw_mode().is_err() { return 1; }
    let mut stdout = io::stdout();
    let _ = execute!(stdout, EnterAlternateScreen);
    let Ok(mut terminal) = Terminal::new(CrosstermBackend::new(stdout)) else {
        let _ = disable_raw_mode();
        return 1;
    };

    let mut active_tab = initial_tab.min(TAB_TITLES.len() - 1);
    let mut forge_sel = 0usize;
    let mut theme_sel = PALETTES.iter().position(|(id, _, _, _)| *id == st.theme_color).unwrap_or(0);
    let mut webapp_input: Option<String> = None;
    let mut status_msg = String::from("16-Bit Rust Engine Ready");
    let busy = Arc::new(AtomicBool::new(false));
    let mut last_tick = Instant::now();
    let mut tick_count = 0u64;

    loop {
        let _ = terminal.draw(|f| {
            let chunks = Layout::default()
                .direction(Direction::Vertical)
                .constraints([Constraint::Length(6), Constraint::Min(12), Constraint::Length(3)])
                .split(f.area());
            render_header(f, chunks[0], &st, &tel, active_tab);
            match active_tab {
                0 => render_vitals(f, chunks[1], &st, &tel),
                1 => render_forge(f, chunks[1], &st, forge_sel, webapp_input.as_deref()),
                2 => render_themes(f, chunks[1], &st, theme_sel),
                3 => render_snapshots(f, chunks[1], &st, &tel),
                4 => render_dock_tuis(f, chunks[1], &st),
                _ => render_doctor(f, chunks[1], &st),
            }
            render_footer(f, chunks[2], &st, active_tab, &status_msg, busy.load(Ordering::Relaxed));
        });

        let timeout = Duration::from_millis(250).saturating_sub(last_tick.elapsed());
        if event::poll(timeout).unwrap_or(false)
            && let Ok(Event::Key(key)) = event::read()
            && key.kind == KeyEventKind::Press
        {
            if let Some(ref mut buf) = webapp_input {
                match key.code {
                    KeyCode::Esc => webapp_input = None,
                    KeyCode::Backspace => { buf.pop(); }
                    KeyCode::Enter => {
                        let url = buf.trim().to_string();
                        webapp_input = None;
                        if !url.is_empty() {
                            status_msg = format!("Installing WebApp: {url}");
                            spawn_bg(&st, &busy, "superforge", "lib/forge.sh", vec!["webapp".into(), url]);
                        }
                    }
                    KeyCode::Char(c) => buf.push(c),
                    _ => {}
                }
                continue;
            }

            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Tab => active_tab = (active_tab + 1) % TAB_TITLES.len(),
                KeyCode::BackTab => active_tab = (active_tab + TAB_TITLES.len() - 1) % TAB_TITLES.len(),
                KeyCode::Char('1') => active_tab = 0,
                KeyCode::Char('2') => active_tab = 1,
                KeyCode::Char('3') => active_tab = 2,
                KeyCode::Char('4') => { st.load_snapshots(); active_tab = 3; }
                KeyCode::Char('5') => active_tab = 4,
                KeyCode::Char('6') => active_tab = 5,
                _ => handle_tab_key(
                    key.code, active_tab, &mut st, &mut tel, &mut forge_sel,
                    &mut theme_sel, &mut webapp_input, &mut status_msg, &busy, &mut terminal,
                ),
            }
        }

        if last_tick.elapsed() >= Duration::from_millis(250) {
            tick_count += 1;
            st.refresh_fast();
            if tick_count.is_multiple_of(2) { tel.refresh(); }
            if tick_count.is_multiple_of(6) { st.refresh(); }
            last_tick = Instant::now();
        }
    }

    let _ = disable_raw_mode();
    let _ = execute!(terminal.backend_mut(), LeaveAlternateScreen);
    let _ = terminal.show_cursor();
    0
}

#[allow(clippy::too_many_arguments)]
fn handle_tab_key(
    code: KeyCode, tab: usize, st: &mut WorkstationState, tel: &mut Telemetry,
    forge_sel: &mut usize, theme_sel: &mut usize, webapp_input: &mut Option<String>,
    status_msg: &mut String, busy: &Arc<AtomicBool>,
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
) {
    match tab {
        0 => match code {
            KeyCode::Char('r') => { tel.refresh(); st.refresh(); *status_msg = "Telemetry refreshed".into(); }
            KeyCode::Char('b') => run_fullscreen_cmd(terminal, "btop", &[]),
            _ => {}
        },
        1 => {
            let total = (st.forge_items.len() + st.webapps.len()).max(1);
            match code {
                KeyCode::Down | KeyCode::Char('j') => *forge_sel = (*forge_sel + 1) % total,
                KeyCode::Up | KeyCode::Char('k') => *forge_sel = (*forge_sel + total - 1) % total,
                KeyCode::Char('u') => {
                    *status_msg = "Running 4-stage Forge update...".into();
                    spawn_bg(st, busy, "superforge", "lib/forge.sh", vec!["update".into()]);
                }
                KeyCode::Char('w') => *webapp_input = Some(String::new()),
                KeyCode::Enter | KeyCode::Char('i') => {
                    if *forge_sel < st.forge_items.len() {
                        let name = st.forge_items[*forge_sel].name.clone();
                        *status_msg = format!("Forging {name} (-march=native)...");
                        spawn_bg(st, busy, "superforge", "lib/forge.sh", vec![name]);
                    } else if let Some((slug, _, _)) = st.webapps.get(*forge_sel - st.forge_items.len()) {
                        let _ = Command::new(format!("sf-webapp-{slug}")).stdout(Stdio::null()).stderr(Stdio::null()).spawn();
                    }
                }
                KeyCode::Char('x') | KeyCode::Delete => {
                    let target = if *forge_sel < st.forge_items.len() {
                        st.forge_items[*forge_sel].name.clone()
                    } else if let Some((slug, _, _)) = st.webapps.get(*forge_sel - st.forge_items.len()) {
                        slug.clone()
                    } else { return; };
                    *status_msg = format!("Removing {target}...");
                    spawn_bg(st, busy, "superforge", "lib/forge.sh", vec!["remove".into(), target]);
                }
                _ => {}
            }
        }
        2 => match code {
            KeyCode::Down | KeyCode::Char('j') => *theme_sel = (*theme_sel + 1) % PALETTES.len(),
            KeyCode::Up | KeyCode::Char('k') => *theme_sel = (*theme_sel + PALETTES.len() - 1) % PALETTES.len(),
            KeyCode::Enter => {
                let id = PALETTES[*theme_sel].0;
                run_sync_bin(st, "supertheme", "lib/apply-theme.sh", &[id]);
                *status_msg = format!("Applied 16-bit palette: {id}");
            }
            KeyCode::Char(']') => run_sync_bin(st, "supertheme", "lib/apply-theme.sh", &["next"]),
            KeyCode::Char('[') => run_sync_bin(st, "supertheme", "lib/apply-theme.sh", &["prev"]),
            KeyCode::Char('m') => run_sync_bin(st, "supertheme", "lib/apply-theme.sh", &["toggle"]),
            KeyCode::Char('c') => run_sync_bin(st, "supertheme", "lib/apply-theme.sh", &["corners", "toggle"]),
            KeyCode::Char('n') => run_sync_bin(st, "supertheme", "lib/apply-theme.sh", &["nightlight", "toggle"]),
            _ => {}
        },
        3 => match code {
            KeyCode::Char('r') => { st.load_snapshots(); *status_msg = "Refreshed Btrfs Time-Machine vault".into(); }
            KeyCode::Char('c') => {
                let num = crate::ops::snapshot::create_checkpoint(st, "SuperFedora TUI Checkpoint");
                st.load_snapshots();
                *status_msg = format!("Sealed Btrfs Time-Machine checkpoint #{num}");
            }
            KeyCode::Char('d') => {
                let exe = std::env::current_exe().unwrap_or_else(|_| st.sf_root.join("bin/superfedora"));
                run_fullscreen_cmd(terminal, exe.to_str().unwrap_or("superfedora"), &["snapshot", "diff"]);
            }
            KeyCode::Char('b') => run_fullscreen_cmd(terminal, st.sf_root.join("lib/tui.sh").to_str().unwrap_or("superfedora"), &["rollback", "--baseline"]),
            _ => {}
        },
        4 => match code {
            KeyCode::Char('b') => run_sync_bin(st, "superbar", "lib/panel-ctl.sh", &["edge", "bottom"]),
            KeyCode::Char('t') => run_sync_bin(st, "superbar", "lib/panel-ctl.sh", &["edge", "top"]),
            KeyCode::Char('l') => run_sync_bin(st, "superbar", "lib/panel-ctl.sh", &["edge", "left"]),
            KeyCode::Char('r') => run_sync_bin(st, "superbar", "lib/panel-ctl.sh", &["edge", "right"]),
            KeyCode::Char('a') => run_sync_bin(st, "superbar", "lib/panel-ctl.sh", &["hide", "toggle"]),
            KeyCode::Char('w') => run_sync_bin(st, "superbar", "lib/panel-ctl.sh", &["tiling", "cycle"]),
            KeyCode::Char('s') => run_sync_bin(st, "supertheme", "lib/sfx.sh", &["sfx", "toggle"]),
            KeyCode::Char('p') => run_fullscreen_cmd(terminal, "wiremix", &[]),
            KeyCode::Char('i') => run_fullscreen_cmd(terminal, "wlctl", &[]),
            KeyCode::Char('u') => run_fullscreen_cmd(terminal, "bluetui", &[]),
            KeyCode::Char('o') => run_fullscreen_cmd(terminal, "btop", &[]),
            _ => {}
        },
        _ => match code {
            KeyCode::Enter | KeyCode::Char('a') => {
                let exe = std::env::current_exe().unwrap_or_else(|_| st.sf_root.join("bin/superfedora"));
                run_fullscreen_cmd(terminal, exe.to_str().unwrap_or("superfedora"), &["status"]);
            }
            KeyCode::Char('d') => run_fullscreen_cmd(terminal, st.sf_root.join("lib/install-dotfiles.sh").to_str().unwrap_or("superfedora"), &[]),
            _ => {}
        },
    }
}

fn bin_or_script(st: &WorkstationState, bin: &str, rel: &str) -> std::path::PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let p = std::path::Path::new(&home).join(".local/bin").join(bin);
    if p.is_file() { p } else { st.sf_root.join(rel) }
}

fn run_sync_bin(st: &mut WorkstationState, bin: &str, rel: &str, args: &[&str]) {
    let _ = Command::new(bin_or_script(st, bin, rel)).env("SF_ROOT", &st.sf_root).args(args).stdout(Stdio::null()).stderr(Stdio::null()).status();
    st.refresh();
}

fn spawn_bg(st: &WorkstationState, busy: &Arc<AtomicBool>, bin: &str, rel: &str, args: Vec<String>) {
    if busy.swap(true, Ordering::SeqCst) { return; }
    let target = bin_or_script(st, bin, rel);
    let root = st.sf_root.clone();
    let flag = Arc::clone(busy);
    thread::spawn(move || {
        let _ = Command::new(target).env("SF_ROOT", root).args(args).stdout(Stdio::null()).stderr(Stdio::null()).status();
        flag.store(false, Ordering::SeqCst);
    });
}

fn run_fullscreen_cmd(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>, cmd: &str, args: &[&str]) {
    let _ = disable_raw_mode();
    let _ = execute!(terminal.backend_mut(), LeaveAlternateScreen);
    let _ = Command::new(cmd).args(args).status();
    let _ = execute!(terminal.backend_mut(), EnterAlternateScreen);
    let _ = enable_raw_mode();
    let _ = terminal.clear();
}
