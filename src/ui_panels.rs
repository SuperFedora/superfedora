// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::{PALETTES, WorkstationState};
use crate::telemetry::Telemetry;
use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{BarChart, Block, Borders, Gauge, List, ListItem, Paragraph},
};

pub fn render_themes(f: &mut Frame, area: Rect, st: &WorkstationState, selected: usize) {
    let pri = st.primary_color();
    let sec = st.secondary_color();
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(60), Constraint::Percentage(40)])
        .split(area);

    let items: Vec<ListItem> = PALETTES
        .iter()
        .enumerate()
        .map(|(idx, &(id, name, p_rgb, s_rgb))| {
            let is_sel = idx == selected;
            let is_act = id == st.theme_color;
            let p_col = Color::Rgb(p_rgb.0, p_rgb.1, p_rgb.2);
            let s_col = Color::Rgb(s_rgb.0, s_rgb.1, s_rgb.2);
            Line::from(vec![
                Span::styled(
                    if is_sel { " ▸ " } else { "   " },
                    Style::default().fg(pri).add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    if is_act { "[ACTIVE] " } else { "         " },
                    Style::default().fg(Color::Green).add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    format!("{id:<14} {name:<10} "),
                    Style::default()
                        .fg(if is_sel { Color::Black } else { Color::White })
                        .bg(if is_sel { p_col } else { Color::Reset })
                        .add_modifier(Modifier::BOLD),
                ),
                Span::styled("████████████", Style::default().fg(p_col)),
                Span::raw(" "),
                Span::styled("████████", Style::default().fg(s_col)),
            ])
            .into()
        })
        .collect();

    let list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(pri))
            .title(Span::styled(
                " 16-BIT RAINBOW PALETTE MATRIX (Enter=Apply, [/]=Prev/Next) ",
                Style::default().fg(pri).add_modifier(Modifier::BOLD),
            )),
    );
    f.render_widget(list, cols[0]);

    let info_lines = vec![
        Line::from(""),
        Line::from(vec![
            Span::styled("  Active Palette : ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
            Span::styled(&st.theme_color, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(vec![
            Span::styled("  Day/Night Mode : ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
            Span::styled(format!("{}  (press [m] to toggle)", st.theme_mode), Style::default().fg(Color::White)),
        ]),
        Line::from(vec![
            Span::styled("  Corner Style   : ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
            Span::styled(format!("{}  (press [c] to toggle)", st.theme_corners), Style::default().fg(Color::White)),
        ]),
        Line::from(vec![
            Span::styled("  Nightlight     : ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
            Span::styled("press [n] to toggle warm eye-care filter", Style::default().fg(Color::Yellow)),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::raw("  Primary RGB    : "),
            Span::styled("████████████████████", Style::default().fg(pri)),
        ]),
        Line::from(vec![
            Span::raw("  Secondary RGB  : "),
            Span::styled("████████████████████", Style::default().fg(sec)),
        ]),
    ];
    let right_block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(sec))
        .title(Span::styled(" STUDIO CONTROLS & SWATCH ", Style::default().fg(sec).add_modifier(Modifier::BOLD)));
    f.render_widget(Paragraph::new(info_lines).block(right_block), cols[1]);
}

pub fn render_snapshots(f: &mut Frame, area: Rect, st: &WorkstationState, tel: &Telemetry) {
    let pri = st.primary_color();
    let sec = st.secondary_color();
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(4), Constraint::Min(8)])
        .split(area);

    let g = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(pri))
                .title(Span::styled(
                    format!(
                        " BTRFS ROOT FILESYSTEM & BOOT-GUARD (Baseline Snapshot: #{}) ",
                        st.baseline_snap
                    ),
                    Style::default().fg(pri).add_modifier(Modifier::BOLD),
                )),
        )
        .gauge_style(Style::default().fg(pri).bg(Color::DarkGray))
        .percent(tel.disk_root_pct)
        .label(Span::styled(
            format!("Root /: {}% ({})  |  /home: {}% ({})", tel.disk_root_pct, tel.disk_root_lbl, tel.disk_home_pct, tel.disk_home_lbl),
            Style::default().fg(Color::White).add_modifier(Modifier::BOLD),
        ));
    f.render_widget(g, rows[0]);

    let lines: Vec<Line> = st
        .snapshots
        .iter()
        .map(|s| Line::from(Span::styled(format!("  {s}"), Style::default().fg(Color::White))))
        .collect();
    let snap_block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(sec))
        .title(Span::styled(
            " SNAPPER BTRFS CHECKPOINTS ([c] Create Checkpoint   [b] Rollback to Baseline   [r] Reload) ",
            Style::default().fg(sec).add_modifier(Modifier::BOLD),
        ));
    f.render_widget(Paragraph::new(lines).block(snap_block), rows[1]);
}

pub fn render_dock_tuis(f: &mut Frame, area: Rect, st: &WorkstationState) {
    let pri = st.primary_color();
    let sec = st.secondary_color();
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(52), Constraint::Percentage(48)])
        .split(area);

    let dock_lines = vec![
        Line::from(""),
        Line::from(vec![
            Span::styled("  SuperDock Edge     : ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
            Span::styled(&st.dock_pos, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
            Span::raw("   ([b]ottom [t]op [l]eft [r]ight)"),
        ]),
        Line::from(vec![
            Span::styled("  Autohide Mode      : ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
            Span::styled(&st.dock_autohide, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
            Span::raw("   ([a] Toggle Autohide)"),
        ]),
        Line::from(vec![
            Span::styled("  Workspace Layout   : ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
            Span::styled(&st.tiling_layout, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
            Span::raw("   ([w] Cycle Dwindle/Master/Scrolling/Monocle)"),
        ]),
        Line::from(vec![
            Span::styled("  16-Bit SFX Engine  : ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
            Span::styled(
                if st.sfx_on { "ENABLED" } else { "MUTED" },
                Style::default().fg(if st.sfx_on { Color::Green } else { Color::Red }).add_modifier(Modifier::BOLD),
            ),
            Span::raw("   ([s] Toggle SFX)"),
        ]),
    ];
    let left_b = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(pri))
        .title(Span::styled(" SUPERDOCK & HYPRLAND WORKSPACE ENGINE ", Style::default().fg(pri).add_modifier(Modifier::BOLD)));
    f.render_widget(Paragraph::new(dock_lines).block(left_b), cols[0]);

    let tui_lines = vec![
        Line::from(""),
        Line::from(Span::styled("  Press key to launch dedicated Rust/C++ hardware TUI:", Style::default().fg(Color::Gray))),
        Line::from(""),
        Line::from(vec![Span::styled("   [p] wiremix  ", Style::default().fg(pri).add_modifier(Modifier::BOLD)), Span::raw("— 16-Bit PipeWire Audio Router & Mixer")]),
        Line::from(vec![Span::styled("   [i] wlctl    ", Style::default().fg(pri).add_modifier(Modifier::BOLD)), Span::raw("— 16-Bit Wi-Fi & NetworkManager TUI")]),
        Line::from(vec![Span::styled("   [u] bluetui  ", Style::default().fg(pri).add_modifier(Modifier::BOLD)), Span::raw("— 16-Bit Bluetooth Device Manager")]),
        Line::from(vec![Span::styled("   [o] btop     ", Style::default().fg(pri).add_modifier(Modifier::BOLD)), Span::raw("— C++20 Process & GPU Telemetry Monitor")]),
    ];
    let right_b = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(sec))
        .title(Span::styled(" DEDICATED HARDWARE TUIS ", Style::default().fg(sec).add_modifier(Modifier::BOLD)));
    f.render_widget(Paragraph::new(tui_lines).block(right_b), cols[1]);
}

pub fn render_doctor(f: &mut Frame, area: Rect, st: &WorkstationState) {
    let pri = st.primary_color();
    let sec = st.secondary_color();
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(48), Constraint::Percentage(52)])
        .split(area);

    let bar_data: Vec<(&str, u64)> = st
        .modules
        .iter()
        .map(|(_num, name, _desc, ok)| (name.as_str(), if *ok { 100 } else { 20 }))
        .collect();
    let chart = BarChart::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(pri))
                .title(Span::styled(
                    " SUPERFEDORA MODULE READINESS BAR CHART (%) ",
                    Style::default().fg(pri).add_modifier(Modifier::BOLD),
                )),
        )
        .data(&bar_data)
        .bar_width(9)
        .bar_gap(2)
        .max(100)
        .bar_style(Style::default().fg(pri))
        .value_style(Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD));
    f.render_widget(chart, rows[0]);

    let mod_lines: Vec<Line> = st
        .modules
        .iter()
        .map(|(num, name, desc, ok)| {
            Line::from(vec![
                Span::styled(
                    if *ok { "  [OK] " } else { "  [--] " },
                    Style::default().fg(if *ok { Color::Green } else { Color::Yellow }).add_modifier(Modifier::BOLD),
                ),
                Span::styled(format!("{num} {name:<14}"), Style::default().fg(sec).add_modifier(Modifier::BOLD)),
                Span::styled(desc, Style::default().fg(Color::White)),
            ])
        })
        .collect();
    let list_b = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(sec))
        .title(Span::styled(
            " WORKSTATION MODULES ([Enter/a] Run Full Audit   [d] Deploy Dotfiles) ",
            Style::default().fg(sec).add_modifier(Modifier::BOLD),
        ));
    f.render_widget(Paragraph::new(mod_lines).block(list_b), rows[1]);
}
