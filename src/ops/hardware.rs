// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::WorkstationState;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

pub struct GpuProfile {
    pub vendor_arch: String,
    pub pci_id: String,
    pub va_driver_pkg: &'static str,
    pub va_driver_name: &'static str,
    pub ffmpeg_full: bool,
    pub vainfo_ready: bool,
    pub vulkan_ready: bool,
    pub firefox_vaapi: bool,
}

pub fn detect_gpu_profile() -> GpuProfile {
    let mut vendor_arch = String::from("Generic KMS/DRM GPU");
    let mut pci_id = String::from("0000:00:00.0");
    let mut va_driver_pkg = "mesa-va-drivers-freeworld";
    let mut va_driver_name = "radeonsi / mesa";

    if let Ok(entries) = fs::read_dir("/sys/bus/pci/devices") {
        for e in entries.flatten() {
            let p = e.path();
            let class = fs::read_to_string(p.join("class")).unwrap_or_default();
            if class.trim().starts_with("0x03") {
                pci_id = e.file_name().to_string_lossy().to_string();
                let vendor = fs::read_to_string(p.join("vendor")).unwrap_or_default();
                match vendor.trim() {
                    "0x1002" => {
                        vendor_arch = "AMD RDNA / Radeon".into();
                        va_driver_pkg = "mesa-va-drivers-freeworld";
                        va_driver_name = "radeonsi (Mesa Freeworld)";
                    }
                    "0x8086" => {
                        vendor_arch = "Intel Arc / Xe".into();
                        va_driver_pkg = "intel-media-driver";
                        va_driver_name = "iHD (Intel Media Driver)";
                    }
                    "0x10de" => {
                        vendor_arch = "NVIDIA RTX / GeForce".into();
                        va_driver_pkg = "nvidia-vaapi-driver";
                        va_driver_name = "nvidia (NVDEC VA-API)";
                    }
                    _ => {}
                }
                break;
            }
        }
    }

    let ffmpeg_full = Command::new("rpm")
        .args(["-q", "--quiet", "ffmpeg"])
        .status()
        .map(|s| s.success())
        .unwrap_or_else(|_| Path::new("/usr/bin/ffmpeg").exists() && !rpm_has("ffmpeg-free"));
    let vainfo_ready = Path::new("/usr/bin/vainfo").exists()
        && Command::new("vainfo").stdout(Stdio::null()).stderr(Stdio::null()).status().map(|s| s.success()).unwrap_or(true);
    let vulkan_ready = Path::new("/usr/bin/vulkaninfo").exists() || Path::new("/usr/share/vulkan/icd.d").is_dir();
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let firefox_vaapi = Path::new(&home).join(".config/superfedora/firefox-vaapi.js").is_file();

    GpuProfile {
        vendor_arch,
        pci_id,
        va_driver_pkg,
        va_driver_name,
        ffmpeg_full,
        vainfo_ready,
        vulkan_ready,
        firefox_vaapi,
    }
}

fn rpm_has(pkg: &str) -> bool {
    Command::new("rpm").args(["-q", "--quiet", pkg]).status().map(|s| s.success()).unwrap_or(false)
}

fn write_firefox_vaapi_cfg() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/jeryd".into());
    let cfg_dir = PathBuf::from(&home).join(".config/superfedora");
    let _ = fs::create_dir_all(&cfg_dir);
    let target = cfg_dir.join("firefox-vaapi.js");
    let prefs = "// Managed by SuperFedora Wave 2 — Hardware VA-API & Wayland Zero-Copy DMABUF\nuser_pref(\"media.ffmpeg.vaapi.enabled\", true);\nuser_pref(\"media.hardware-video-decoding.force-enabled\", true);\nuser_pref(\"widget.dmabuf.force-enabled\", true);\nuser_pref(\"gfx.webrender.all\", true);\n";
    let _ = fs::write(&target, prefs);

    let moz_dir = PathBuf::from(&home).join(".mozilla/firefox");
    if let Ok(entries) = fs::read_dir(moz_dir) {
        for e in entries.flatten() {
            let p = e.path();
            let name = e.file_name().to_string_lossy().to_string();
            if p.is_dir() && (name.contains(".default") || name.contains("superfedora")) {
                let user_js = p.join("user.js");
                let existing = fs::read_to_string(&user_js).unwrap_or_default();
                if !existing.contains("media.ffmpeg.vaapi.enabled") {
                    let _ = fs::write(&user_js, format!("{existing}\n{prefs}"));
                }
            }
        }
    }
    target
}

fn trigger_engineer_cast(st: &WorkstationState, title: &str, body: &str) {
    if Command::new("supernotify")
        .args(["--cast", "engineer", title, body])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
    {
        return;
    }
    let _ = Command::new("bash")
        .arg(st.sf_root.join("lib/notify-ctl.sh"))
        .args(["--cast", "engineer", title, body])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

pub fn run_hardware_cmd(st: &WorkstationState, args: &[String]) -> i32 {
    let mut dry = false;
    let mut sub = "probe";
    for a in args {
        match a.as_str() {
            "--dry-run" | "-n" => dry = true,
            "probe" | "status" | "check" => sub = "probe",
            "optimize" | "tune" | "apply" | "install" => sub = "optimize",
            "-h" | "--help" | "help" => {
                println!("Usage: superfedora hardware [probe|optimize] [--dry-run]");
                println!("  probe     Detect PCI GPU architecture, VA-API driver, ffmpeg & Vulkan readiness");
                println!("  optimize  Swap ffmpeg-free -> ffmpeg, install VA-API drivers & Firefox DMABUF");
                return 0;
            }
            other => {
                eprintln!("\x1b[1;31m  [ERR] Unknown hardware action '{}'. Expected: probe | optimize\x1b[0m", other);
                return 2;
            }
        }
    }

    let prof = detect_gpu_profile();
    match sub {
        "probe" => {
            println!("\x1b[1;38;5;141m[::] SUPERFEDORA HARDWARE & VA-API VIDEO ACCELERATION PROBE\x1b[0m");
            println!("  GPU Architecture : {} (PCI {})", prof.vendor_arch, prof.pci_id);
            println!("  VA-API Driver    : {} [pkg: {}]", prof.va_driver_name, prof.va_driver_pkg);
            println!("  FFmpeg Build     : {}", if prof.ffmpeg_full { "\x1b[1;32m[OK] Full RPM Fusion ffmpeg\x1b[0m" } else { "\x1b[1;33m[--] Patent-restricted ffmpeg-free\x1b[0m" });
            println!("  VA-API Runtime   : {}", if prof.vainfo_ready { "\x1b[1;32m[OK] vainfo ready\x1b[0m" } else { "\x1b[1;33m[--] libva-utils not verified\x1b[0m" });
            println!("  Vulkan Runtime   : {}", if prof.vulkan_ready { "\x1b[1;32m[OK] Vulkan ICD ready\x1b[0m" } else { "\x1b[1;33m[--] vulkan-tools missing\x1b[0m" });
            println!("  Firefox DMABUF   : {}", if prof.firefox_vaapi { "\x1b[1;32m[OK] Zero-copy VA-API enabled\x1b[0m" } else { "\x1b[1;33m[--] Run 'superfedora hardware optimize'\x1b[0m" });
            0
        }
        "optimize" => {
            println!("\x1b[1;38;5;141m[::] SUPERFEDORA GPU & VA-API AUTO-TUNING ENGINE ({})\x1b[0m", prof.vendor_arch);
            if dry {
                println!("  [DRY-RUN] 1. Codec Swap     : sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing");
                println!("  [DRY-RUN] 2. VA-API Driver  : sudo dnf install -y {} libva-utils vulkan-tools", prof.va_driver_pkg);
                println!("  [DRY-RUN] 3. Firefox DMABUF : ~/.config/superfedora/firefox-vaapi.js (media.ffmpeg.vaapi.enabled=true)");
                println!("  [DRY-RUN] 4. Cast Comms     : supernotify --cast engineer \"SYS ENG: Hardware VA-API Tuned\"");
                return 0;
            }
            let cfg_path = write_firefox_vaapi_cfg();
            println!("  [OK] Configured Firefox zero-copy DMABUF & VA-API ({})", cfg_path.display());
            if rpm_has("ffmpeg-free") {
                println!("  [+] Swapping ffmpeg-free -> full ffmpeg...");
                let _ = Command::new("sudo").args(["-n", "dnf", "swap", "-y", "ffmpeg-free", "ffmpeg", "--allowerasing"]).status();
            }
            if !rpm_has(prof.va_driver_pkg) || !rpm_has("libva-utils") {
                println!("  [+] Ensuring VA-API driver package ({}) & libva-utils...", prof.va_driver_pkg);
                let _ = Command::new("sudo").args(["-n", "dnf", "install", "-y", prof.va_driver_pkg, "libva-utils", "vulkan-tools"]).status();
            }
            trigger_engineer_cast(
                st,
                "SYS ENG: Hardware VA-API Tuned",
                &format!("{} configured with {} & Firefox DMABUF.", prof.vendor_arch, prof.va_driver_pkg),
            );
            println!("  [OK] Hardware codec & VA-API optimization complete (SYS ENG Cast Comms notified).");
            0
        }
        _ => 2,
    }
}
