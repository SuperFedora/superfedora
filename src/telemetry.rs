// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use std::fs;
use std::path::Path;
use std::process::Command;
use std::time::Instant;

#[derive(Clone, Default)]
pub struct CpuTimes {
    pub active: u64,
    pub total: u64,
}

#[derive(Clone)]
pub struct Telemetry {
    pub cpu_model: String,
    pub kernel: String,
    pub uptime_str: String,
    pub cpu_avg: u64,
    pub cpu_mhz: u64,
    pub core_loads: Vec<(String, u64)>,
    pub cpu_history: Vec<u64>,
    pub ram_used_mb: u64,
    pub ram_total_mb: u64,
    pub ram_pct: u16,
    pub swap_used_mb: u64,
    pub swap_total_mb: u64,
    pub swap_pct: u16,
    pub disk_root_pct: u16,
    pub disk_root_lbl: String,
    pub disk_home_pct: u16,
    pub disk_home_lbl: String,
    pub gpu_pct: u16,
    pub temp_c: u64,
    pub bat_pct: u16,
    pub bat_status: String,
    pub net_rx_kbs: u64,
    pub net_tx_kbs: u64,
    pub net_history: Vec<u64>,
    prev_cpus: Vec<CpuTimes>,
    prev_net: (u64, u64),
    last_tick: Instant,
}

impl Default for Telemetry {
    fn default() -> Self {
        Self::new()
    }
}

impl Telemetry {
    pub fn new() -> Self {
        let kernel = fs::read_to_string("/proc/sys/kernel/osrelease")
            .unwrap_or_else(|_| "Linux".into())
            .trim()
            .to_string();
        let mut t = Self {
            cpu_model: Self::read_cpu_model(),
            kernel,
            uptime_str: String::new(),
            cpu_avg: 0,
            cpu_mhz: 0,
            core_loads: Vec::new(),
            cpu_history: vec![0; 48],
            ram_used_mb: 0,
            ram_total_mb: 1,
            ram_pct: 0,
            swap_used_mb: 0,
            swap_total_mb: 1,
            swap_pct: 0,
            disk_root_pct: 0,
            disk_root_lbl: String::new(),
            disk_home_pct: 0,
            disk_home_lbl: String::new(),
            gpu_pct: 0,
            temp_c: 0,
            bat_pct: 100,
            bat_status: "AC".into(),
            net_rx_kbs: 0,
            net_tx_kbs: 0,
            net_history: vec![0; 48],
            prev_cpus: Self::sample_proc_stat(),
            prev_net: Self::sample_net_bytes(),
            last_tick: Instant::now(),
        };
        t.refresh();
        t
    }

    pub fn refresh(&mut self) {
        let cur_cpus = Self::sample_proc_stat();
        if !self.prev_cpus.is_empty() && cur_cpus.len() == self.prev_cpus.len() {
            let mut cores = Vec::new();
            for (idx, (prev, cur)) in self.prev_cpus.iter().zip(cur_cpus.iter()).enumerate() {
                let d_tot = cur.total.saturating_sub(prev.total);
                let d_act = cur.active.saturating_sub(prev.active);
                let pct = (d_act * 100).checked_div(d_tot).unwrap_or(0).min(100);
                if idx == 0 {
                    self.cpu_avg = pct;
                } else {
                    cores.push((format!("C{}", idx - 1), pct));
                }
            }
            if !cores.is_empty() {
                self.core_loads = cores;
            }
        }
        self.prev_cpus = cur_cpus;
        self.cpu_history.push(self.cpu_avg);
        if self.cpu_history.len() > 60 {
            self.cpu_history.remove(0);
        }
        self.cpu_mhz = Self::read_cpu_mhz();
        self.uptime_str = Self::read_uptime();
        self.refresh_mem();
        self.refresh_hw();
        self.refresh_net();
        self.refresh_disks();
    }

    fn read_cpu_model() -> String {
        fs::read_to_string("/proc/cpuinfo")
            .ok()
            .and_then(|t| {
                t.lines()
                    .find_map(|l| Some(l.strip_prefix("model name")?.split_once(':')?.1.trim().to_string()))
            })
            .unwrap_or_else(|| "x86_64 Workstation CPU".into())
    }

    fn read_cpu_mhz() -> u64 {
        let Ok(txt) = fs::read_to_string("/proc/cpuinfo") else { return 0 };
        let vals: Vec<f64> = txt
            .lines()
            .filter_map(|l| l.strip_prefix("cpu MHz")?.split_once(':')?.1.trim().parse().ok())
            .collect();
        if vals.is_empty() { 0 } else { (vals.iter().sum::<f64>() / vals.len() as f64) as u64 }
    }

    fn read_uptime() -> String {
        let secs = fs::read_to_string("/proc/uptime")
            .ok()
            .and_then(|t| t.split_whitespace().next()?.parse::<f64>().ok())
            .unwrap_or(0.0) as u64;
        format!("{}h {:02}m", secs / 3600, (secs % 3600) / 60)
    }

    fn sample_proc_stat() -> Vec<CpuTimes> {
        let mut out = Vec::new();
        let Ok(txt) = fs::read_to_string("/proc/stat") else { return out };
        for line in txt.lines().take_while(|l| l.starts_with("cpu")) {
            let nums: Vec<u64> = line.split_whitespace().skip(1).filter_map(|s| s.parse().ok()).collect();
            if nums.len() >= 4 {
                let idle = nums[3] + nums.get(4).copied().unwrap_or(0);
                let total: u64 = nums.iter().sum();
                out.push(CpuTimes { active: total.saturating_sub(idle), total });
            }
        }
        out
    }

    fn refresh_mem(&mut self) {
        let Ok(txt) = fs::read_to_string("/proc/meminfo") else { return };
        let (mut tot, mut avail, mut stot, mut sfree) = (0u64, 0u64, 0u64, 0u64);
        for line in txt.lines() {
            let mut p = line.split_whitespace();
            let (k, v) = (p.next().unwrap_or(""), p.next().and_then(|s| s.parse().ok()).unwrap_or(0));
            match k {
                "MemTotal:" => tot = v,
                "MemAvailable:" => avail = v,
                "SwapTotal:" => stot = v,
                "SwapFree:" => sfree = v,
                _ => {}
            }
        }
        self.ram_total_mb = (tot / 1024).max(1);
        self.ram_used_mb = tot.saturating_sub(avail) / 1024;
        self.ram_pct = ((self.ram_used_mb * 100) / self.ram_total_mb).min(100) as u16;
        self.swap_total_mb = stot / 1024;
        self.swap_used_mb = stot.saturating_sub(sfree) / 1024;
        self.swap_pct = (self.swap_used_mb * 100).checked_div(self.swap_total_mb).unwrap_or(0).min(100) as u16;
    }

    fn refresh_hw(&mut self) {
        for card in ["card0", "card1", "card2"] {
            if let Ok(s) = fs::read_to_string(format!("/sys/class/drm/{card}/device/gpu_busy_percent"))
                && let Ok(v) = s.trim().parse::<u16>()
            {
                self.gpu_pct = v.min(100);
                break;
            }
        }
        if let Ok(entries) = fs::read_dir("/sys/class/thermal") {
            self.temp_c = entries
                .flatten()
                .filter_map(|e| fs::read_to_string(e.path().join("temp")).ok()?.trim().parse::<u64>().ok())
                .map(|v| v / 1000)
                .filter(|&c| (15..125).contains(&c))
                .max()
                .unwrap_or(0);
        }
        for bat in ["BAT0", "BAT1"] {
            let base = Path::new("/sys/class/power_supply").join(bat);
            if base.exists() {
                self.bat_pct = fs::read_to_string(base.join("capacity")).ok().and_then(|s| s.trim().parse().ok()).unwrap_or(100).min(100);
                self.bat_status = fs::read_to_string(base.join("status")).unwrap_or_else(|_| "AC".into()).trim().to_string();
                break;
            }
        }
    }

    fn sample_net_bytes() -> (u64, u64) {
        let (mut rx, mut tx) = (0u64, 0u64);
        if let Ok(txt) = fs::read_to_string("/proc/net/dev") {
            for line in txt.lines().skip(2) {
                if let Some((iface, rest)) = line.split_once(':') && iface.trim() != "lo" {
                    let c: Vec<u64> = rest.split_whitespace().filter_map(|s| s.parse().ok()).collect();
                    if c.len() >= 9 { rx += c[0]; tx += c[8]; }
                }
            }
        }
        (rx, tx)
    }

    fn refresh_net(&mut self) {
        let now = Instant::now();
        let dt = now.duration_since(self.last_tick).as_secs_f64().max(0.1);
        let cur = Self::sample_net_bytes();
        self.net_rx_kbs = ((cur.0.saturating_sub(self.prev_net.0) as f64 / 1024.0) / dt) as u64;
        self.net_tx_kbs = ((cur.1.saturating_sub(self.prev_net.1) as f64 / 1024.0) / dt) as u64;
        self.prev_net = cur;
        self.last_tick = now;
        self.net_history.push(self.net_rx_kbs + self.net_tx_kbs);
        if self.net_history.len() > 60 { self.net_history.remove(0); }
    }

    fn refresh_disks(&mut self) {
        let Ok(out) = Command::new("df").args(["-BG", "/", "/home"]).output() else { return };
        for (i, line) in String::from_utf8_lossy(&out.stdout).lines().skip(1).enumerate() {
            let c: Vec<&str> = line.split_whitespace().collect();
            if c.len() >= 5 {
                let pct = c[4].trim_end_matches('%').parse::<u16>().unwrap_or(0).min(100);
                let lbl = format!("{} / {}", c[2], c[1]);
                if i == 0 { self.disk_root_pct = pct; self.disk_root_lbl = lbl; } else { self.disk_home_pct = pct; self.disk_home_lbl = lbl; }
            }
        }
    }
}
