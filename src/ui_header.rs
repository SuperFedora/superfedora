// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::WorkstationState;
use crate::telemetry::Telemetry;
use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Tabs},
};

pub const TAB_TITLES: &[&str] = &[
    "[1] VITALS & CHARTS",
    "[2] FORGE & WEBAPPS",
    "[3] 16-BIT THEMES",
    "[4] SNAPSHOTS",
    "[5] DOCK & TUIS",
    "[6] DOCTOR",
];

pub fn render_header(
    f: &mut Frame,
    area: Rect,
    st: &WorkstationState,
    tel: &Telemetry,
    active_tab: usize,
) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Length(3)])
        .split(area);

    let pri = st.primary_color();
    let sec = st.secondary_color();
    let forged_cnt = st.forge_items.iter().filter(|i| i.installed).count();
    let sfx_lbl = if st.sfx_on { "ON" } else { "OFF" };

    let title_line = Line::from(vec![
        Span::styled(
            format!(" [::] SUPER FEDORA v{} ", st.version),
            Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD),
        ),
        Span::raw("  "),
        Span::styled("CPU: ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
        Span::styled(
            format!("{} ({} MHz)", tel.cpu_model, tel.cpu_mhz),
            Style::default().fg(Color::White),
        ),
        Span::raw("   "),
        Span::styled("THEME: ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
        Span::styled(
            format!("{} [{}]", st.theme_color, st.theme_mode),
            Style::default().fg(pri).add_modifier(Modifier::BOLD),
        ),
        Span::raw("   "),
        Span::styled("FORGE: ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
        Span::styled(
            format!("{} bin / {} web", forged_cnt, st.webapps.len()),
            Style::default().fg(Color::Green),
        ),
        Span::raw("   "),
        Span::styled("SFX: ", Style::default().fg(sec).add_modifier(Modifier::BOLD)),
        Span::styled(sfx_lbl, Style::default().fg(Color::Yellow)),
    ]);

    let header_block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(pri))
        .title(Span::styled(
            " 16-BIT RUST WORKSTATION CONTROL DECK ",
            Style::default().fg(pri).add_modifier(Modifier::BOLD),
        ));
    f.render_widget(Paragraph::new(title_line).block(header_block), chunks[0]);

    let titles: Vec<Line> = TAB_TITLES
        .iter()
        .map(|t| Line::from(Span::styled(*t, Style::default().fg(Color::Gray))))
        .collect();
    let tabs = Tabs::new(titles)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(sec))
                .title(Span::styled(" NAVIGATION (1-6 / TAB / ARROWS) ", Style::default().fg(sec))),
        )
        .select(active_tab)
        .style(Style::default().fg(Color::White))
        .highlight_style(
            Style::default()
                .fg(Color::Black)
                .bg(pri)
                .add_modifier(Modifier::BOLD),
        )
        .divider(" │ ");
    f.render_widget(tabs, chunks[1]);
}

pub fn render_footer(
    f: &mut Frame,
    area: Rect,
    st: &WorkstationState,
    active_tab: usize,
    status_msg: &str,
    busy: bool,
) {
    let pri = st.primary_color();
    let sec = st.secondary_color();

    let hints = match active_tab {
        0 => "[1-6/Tab] Switch Tab   [r] Refresh Telemetry   [b] Launch btop   [q/Esc] Quit",
        1 => "[↑/↓] Select   [Enter/i] Forge Target   [u] 4-Stage Update   [w] Install WebApp   [x] Remove   [q] Quit",
        2 => "[↑/↓] Select Palette   [Enter] Apply Theme   [m] Dark/Light   [c] Corners   [n] Nightlight   [q] Quit",
        3 => "[c] Create Btrfs Checkpoint   [b] Rollback to Baseline   [r] Reload Snapshots   [q] Quit",
        4 => "[b/t/l/r] Dock Edge   [a] Autohide   [w] Layout Cycle   [s] Toggle SFX   [1-4] Launch HW TUI   [q] Quit",
        _ => "[Enter/a] Run Full Workstation Audit   [d] Deploy Dotfiles   [q] Quit",
    };

    let badge = if busy || st.forge_live.active {
        Span::styled(
            format!(" [ACTIVE: {} {}%] ", st.forge_live.step, st.forge_live.pct),
            Style::default().fg(Color::Black).bg(Color::Yellow).add_modifier(Modifier::BOLD),
        )
    } else if !status_msg.is_empty() {
        Span::styled(
            format!(" [{}] ", status_msg),
            Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD),
        )
    } else {
        Span::styled(
            " [READY] ",
            Style::default().fg(Color::Black).bg(Color::Green).add_modifier(Modifier::BOLD),
        )
    };

    let line = Line::from(vec![
        badge,
        Span::raw(" "),
        Span::styled(hints, Style::default().fg(Color::White)),
    ]);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(pri));
    f.render_widget(Paragraph::new(line).block(block), area);
}
