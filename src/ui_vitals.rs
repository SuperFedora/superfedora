// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::WorkstationState;
use crate::telemetry::Telemetry;
use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::Span,
    widgets::{BarChart, Block, Borders, Gauge, Sparkline},
};

pub fn render_vitals(f: &mut Frame, area: Rect, st: &WorkstationState, tel: &Telemetry) {
    let pri = st.primary_color();
    let sec = st.secondary_color();

    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(68), Constraint::Percentage(32)])
        .split(area);

    let top_cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(52), Constraint::Percentage(48)])
        .split(rows[0]);

    let bar_data: Vec<(&str, u64)> = tel
        .core_loads
        .iter()
        .map(|(lbl, v)| (lbl.as_str(), *v))
        .collect();
    let barchart = BarChart::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(pri))
                .title(Span::styled(
                    format!(
                        " PER-CORE CPU LOAD BAR CHART (Avg: {}% @ {} MHz) ",
                        tel.cpu_avg, tel.cpu_mhz
                    ),
                    Style::default().fg(pri).add_modifier(Modifier::BOLD),
                )),
        )
        .data(&bar_data)
        .bar_width(3)
        .bar_gap(1)
        .max(100)
        .bar_style(Style::default().fg(pri))
        .value_style(
            Style::default()
                .fg(Color::Black)
                .bg(sec)
                .add_modifier(Modifier::BOLD),
        )
        .label_style(Style::default().fg(Color::White));
    f.render_widget(barchart, top_cols[0]);

    let gauge_rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Ratio(1, 6),
            Constraint::Ratio(1, 6),
            Constraint::Ratio(1, 6),
            Constraint::Ratio(1, 6),
            Constraint::Ratio(1, 6),
            Constraint::Ratio(1, 6),
        ])
        .split(top_cols[1]);

    draw_gauge(
        f,
        gauge_rows[0],
        " CPU PACKAGE ",
        tel.cpu_avg.min(100) as u16,
        format!("{}%  ({} MHz, up {})", tel.cpu_avg, tel.cpu_mhz, tel.uptime_str),
        pri,
    );
    draw_gauge(
        f,
        gauge_rows[1],
        " MEMORY RAM ",
        tel.ram_pct,
        format!("{}%  ({} / {} MiB)", tel.ram_pct, tel.ram_used_mb, tel.ram_total_mb),
        sec,
    );
    draw_gauge(
        f,
        gauge_rows[2],
        " ZRAM / SWAP ",
        tel.swap_pct,
        format!("{}%  ({} / {} MiB)", tel.swap_pct, tel.swap_used_mb, tel.swap_total_mb),
        Color::Cyan,
    );
    draw_gauge(
        f,
        gauge_rows[3],
        " GPU & THERMAL ",
        tel.gpu_pct,
        format!("GPU {}%  |  Core Temp: {} C", tel.gpu_pct, tel.temp_c),
        Color::Yellow,
    );
    draw_gauge(
        f,
        gauge_rows[4],
        " BATTERY TANK ",
        tel.bat_pct,
        format!("{}%  ({})", tel.bat_pct, tel.bat_status),
        Color::Green,
    );
    draw_gauge(
        f,
        gauge_rows[5],
        " BTRFS ROOT / ",
        tel.disk_root_pct,
        format!("{}%  ({})", tel.disk_root_pct, tel.disk_root_lbl),
        pri,
    );

    let bot_cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(52), Constraint::Percentage(48)])
        .split(rows[1]);

    let cpu_spark = Sparkline::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(pri))
                .title(Span::styled(
                    format!(" CPU LOAD HISTORY SPARKLINE (60s — Kernel {}) ", tel.kernel),
                    Style::default().fg(pri).add_modifier(Modifier::BOLD),
                )),
        )
        .data(&tel.cpu_history)
        .max(100)
        .style(Style::default().fg(pri));
    f.render_widget(cpu_spark, bot_cols[0]);

    let net_spark = Sparkline::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(sec))
                .title(Span::styled(
                    format!(
                        " NETWORK THROUGHPUT SPARKLINE (RX: {} KB/s | TX: {} KB/s) ",
                        tel.net_rx_kbs, tel.net_tx_kbs
                    ),
                    Style::default().fg(sec).add_modifier(Modifier::BOLD),
                )),
        )
        .data(&tel.net_history)
        .style(Style::default().fg(sec));
    f.render_widget(net_spark, bot_cols[1]);
}

fn draw_gauge(f: &mut Frame, area: Rect, title: &str, pct: u16, label: String, color: Color) {
    let g = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(color))
                .title(Span::styled(title, Style::default().fg(color).add_modifier(Modifier::BOLD))),
        )
        .gauge_style(Style::default().fg(color).bg(Color::DarkGray))
        .percent(pct.min(100))
        .label(Span::styled(
            label,
            Style::default().fg(Color::White).add_modifier(Modifier::BOLD),
        ));
    f.render_widget(g, area);
}
