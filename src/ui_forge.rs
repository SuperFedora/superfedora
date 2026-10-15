// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::WorkstationState;
use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{BarChart, Block, Borders, Clear, Gauge, List, ListItem, Paragraph},
};

pub fn render_forge(
    f: &mut Frame,
    area: Rect,
    st: &WorkstationState,
    selected: usize,
    webapp_prompt: Option<&str>,
) {
    let pri = st.primary_color();
    let sec = st.secondary_color();

    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(4), Constraint::Min(10)])
        .split(area);

    let (pct, step_lbl, g_col) = if st.forge_live.active {
        (
            st.forge_live.pct.min(100),
            format!("ACTIVE [{}]: {} ({}%)", st.forge_live.target, st.forge_live.step, st.forge_live.pct),
            Color::Yellow,
        )
    } else {
        let forged_cnt = st.forge_items.iter().filter(|i| i.installed).count();
        let total_cnt = st.forge_items.len().max(1);
        let p = ((forged_cnt * 100) / total_cnt).min(100) as u16;
        (
            p,
            format!(
                "IDLE — {}/{} Native Packages Forged (-march=native / LTO) | {} Firefox WebApps  [Press 'u' for 4-Stage Update]",
                forged_cnt,
                total_cnt,
                st.webapps.len()
            ),
            pri,
        )
    };

    let stage_gauge = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(g_col))
                .title(Span::styled(
                    " FORGE 4-STAGE PIPELINE ([1/4] DNF ▸ [2/4] GIT ▸ [3/4] LTO COMPILE ▸ [4/4] WEBAPPS) ",
                    Style::default().fg(g_col).add_modifier(Modifier::BOLD),
                )),
        )
        .gauge_style(Style::default().fg(g_col).bg(Color::DarkGray))
        .percent(pct)
        .label(Span::styled(step_lbl, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)));
    f.render_widget(stage_gauge, rows[0]);

    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(56), Constraint::Percentage(44)])
        .split(rows[1]);

    let mut items: Vec<ListItem> = Vec::new();
    for (idx, it) in st.forge_items.iter().enumerate() {
        let is_sel = idx == selected;
        let badge = if it.installed { "[FORGED]" } else { "[AVAIL ]" };
        let b_col = if it.installed { Color::Green } else { Color::DarkGray };
        let sz = if it.size_kb > 0 { format!("{:>5} KB", it.size_kb) } else { "    --  ".into() };
        let line = Line::from(vec![
            Span::styled(
                if is_sel { " ▸ " } else { "   " },
                Style::default().fg(pri).add_modifier(Modifier::BOLD),
            ),
            Span::styled(format!("{badge:<9}"), Style::default().fg(b_col).add_modifier(Modifier::BOLD)),
            Span::styled(
                format!("{:<13}", it.name),
                Style::default()
                    .fg(if is_sel { Color::Black } else { Color::White })
                    .bg(if is_sel { pri } else { Color::Reset })
                    .add_modifier(Modifier::BOLD),
            ),
            Span::styled(format!(" {:<6} ", it.kind), Style::default().fg(sec)),
            Span::styled(format!("{sz}  "), Style::default().fg(Color::Cyan)),
            Span::styled(&it.desc, Style::default().fg(Color::Gray)),
        ]);
        items.push(ListItem::new(line));
    }

    let base_idx = st.forge_items.len();
    for (w_idx, (slug, name, url)) in st.webapps.iter().enumerate() {
        let is_sel = base_idx + w_idx == selected;
        let line = Line::from(vec![
            Span::styled(
                if is_sel { " ▸ " } else { "   " },
                Style::default().fg(pri).add_modifier(Modifier::BOLD),
            ),
            Span::styled("[WEBAPP] ", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
            Span::styled(
                format!("{:<13}", name.chars().take(13).collect::<String>()),
                Style::default()
                    .fg(if is_sel { Color::Black } else { Color::White })
                    .bg(if is_sel { pri } else { Color::Reset })
                    .add_modifier(Modifier::BOLD),
            ),
            Span::styled(format!(" {:<14} ", slug), Style::default().fg(sec)),
            Span::styled(url, Style::default().fg(Color::Gray)),
        ]);
        items.push(ListItem::new(line));
    }

    let pkg_list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(pri))
            .title(Span::styled(
                " NATIVE PACKAGES & CHROMELESS FIREFOX WEBAPPS (Enter=Build/Launch, w=Add WebApp, x=Remove) ",
                Style::default().fg(pri).add_modifier(Modifier::BOLD),
            )),
    );
    f.render_widget(pkg_list, cols[0]);

    let right_rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(62), Constraint::Percentage(38)])
        .split(cols[1]);

    let size_bars: Vec<(&str, u64)> = st
        .forge_items
        .iter()
        .map(|i| (i.name.as_str(), (i.size_kb as f64).sqrt() as u64))
        .collect();
    let size_chart = BarChart::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(sec))
                .title(Span::styled(
                    " FORGED BINARY FOOTPRINT CHART (sqrt KB scale) ",
                    Style::default().fg(sec).add_modifier(Modifier::BOLD),
                )),
        )
        .data(&size_bars)
        .bar_width(6)
        .bar_gap(2)
        .bar_style(Style::default().fg(sec))
        .value_style(Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD))
        .label_style(Style::default().fg(Color::White));
    f.render_widget(size_chart, right_rows[0]);

    let forged_n = st.forge_items.iter().filter(|i| i.installed).count() as u64;
    let avail_n = st.forge_items.len() as u64;
    let web_n = st.webapps.len() as u64;
    let summary_bars = vec![("FORGED", forged_n), ("CATALOG", avail_n), ("WEBAPPS", web_n)];
    let sum_chart = BarChart::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(pri))
                .title(Span::styled(
                    " FORGE INVENTORY BREAKDOWN ",
                    Style::default().fg(pri).add_modifier(Modifier::BOLD),
                )),
        )
        .data(&summary_bars)
        .bar_width(9)
        .bar_gap(3)
        .bar_style(Style::default().fg(pri))
        .value_style(Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD));
    f.render_widget(sum_chart, right_rows[1]);

    if let Some(input) = webapp_prompt {
        let popup = Rect {
            x: area.width.saturating_sub(68) / 2,
            y: area.height / 2,
            width: 68.min(area.width),
            height: 5,
        };
        f.render_widget(Clear, popup);
        let p_block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::Yellow))
            .title(Span::styled(
                " INSTALL CHROMELESS FIREFOX WEBAPP (Enter URL or url|Name, Esc=Cancel) ",
                Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD),
            ));
        let txt = Paragraph::new(format!(" > {input}█")).block(p_block);
        f.render_widget(txt, popup);
    }
}
