// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// superfedora — Native Rust 16-Bit Workstation Engine & Graphical TUI
// ==============================================================================

mod charts_cli;
mod cli;
mod ops;
mod settings_engine;
mod state;
mod telemetry;
mod tui;
mod ui_forge;
mod ui_header;
mod ui_panels;
mod ui_vitals;

use crate::state::WorkstationState;
use std::env;
use std::process;

fn main() {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let path_env = env::var("PATH").unwrap_or_default();
    let full_path = format!(
        "{home}/.local/bin:{home}/.cargo/bin:{home}/.minimax-code/bin:{home}/.grok/bin:{path_env}"
    );
    unsafe {
        env::set_var("PATH", full_path);
    }

    let mut st = WorkstationState::load();
    unsafe {
        env::set_var("SF_ROOT", &st.sf_root);
    }

    let raw_args: Vec<String> = env::args().skip(1).collect();
    let (cmd, rest): (&str, &[String]) = match raw_args.first() {
        Some(first) => (first.as_str(), &raw_args[1..]),
        None => ("", &[]),
    };

    let code = cli::dispatch(cmd, rest, &mut st);
    process::exit(code);
}
