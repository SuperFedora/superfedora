pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Consolidated system state & event-driven probes (CPU, RAM, GPU, Temp, Net, Wi-Fi, Brightness, SFX, Dock, SuperDeck).
Singleton {
    id: root

    property int cpu: 0; property int mem: 0; property int gpu: 0; property int tempC: 40
    property real netRxKbps: 0; property real netTxKbps: 0
    property string netType: "none"; property string ssid: ""; property int signal: 0; property var wifiList: []
    property real brightness: 1.0; property bool idleEnabled: true; property bool sfxEnabled: true
    property real spkVol: 0.6; property bool spkMuted: false; property real micVol: 1.0; property bool micMuted: false; property bool webcamEnabled: true
    property bool pocketOpen: false; property bool superDeckOpen: false; property string superDeckSection: "quick"
    property bool clock24h: true; property bool clockSeconds: false; property string localTz: "Local"; property bool autoTz: true
    property var worldClocks: []; property bool dnd: false; property bool sessionLocked: false
    property int notifUnread: 0; property int centerToggleSeq: 0; property var notifHistory: []; property var notifAction: null
    property var _lastCpu: null; property var _lastNet: null; property var _lastGpu: null

    FileView { id: procStat; path: "/proc/stat" }
    FileView { id: procMem; path: "/proc/meminfo" }
    FileView { id: procNet; path: "/proc/net/dev" }
    FileView { id: pkgTemp; path: "/sys/class/thermal/thermal_zone6/temp" }
    FileView { id: fallbackTemp; path: "/sys/class/thermal/thermal_zone0/temp" }
    FileView { id: gpuRc6; path: "/sys/class/drm/card1/gt/gt0/rc6_residency_ms" }
    FileView { id: sfxFile; path: Quickshell.env("HOME") + "/.config/superfedora/sfx.conf" }

    // Consolidated 3000ms telemetry timer (replaces multiple rapid timers to minimize idle CPU)
    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const nowMs = Date.now();
            procStat.reload();
            const v = procStat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            if (v.length >= 4) {
                const idle = v[3] + (v[4] || 0), total = v.reduce((a, b) => a + b, 0);
                if (root._lastCpu) {
                    const dt = total - root._lastCpu.total;
                    root.cpu = dt > 0 ? Math.round(100 * (1 - (idle - root._lastCpu.idle) / dt)) : 0;
                }
                root._lastCpu = { total, idle };
            }
            procMem.reload();
            const mtext = procMem.text(), mt = mtext.match(/MemTotal:\s+(\d+)/), ma = mtext.match(/MemAvailable:\s+(\d+)/);
            if (mt && ma && Number(mt[1]) > 0) root.mem = Math.round(100 * (1 - Number(ma[1]) / Number(mt[1])));
            pkgTemp.reload();
            let rawT = Number(pkgTemp.text().trim() || "0");
            if (!rawT || rawT <= 0) { fallbackTemp.reload(); rawT = Number(fallbackTemp.text().trim() || "40000"); }
            root.tempC = Math.round(rawT > 1000 ? rawT / 1000 : rawT);
            gpuRc6.reload();
            const rc6Txt = gpuRc6.text().trim();
            if (rc6Txt !== "") {
                const rc6 = Number(rc6Txt);
                if (root._lastGpu && nowMs > root._lastGpu.t) {
                    const dtMs = nowMs - root._lastGpu.t;
                    root.gpu = Math.max(0, Math.min(100, Math.round(100 * (1 - Math.max(0, rc6 - root._lastGpu.rc6) / dtMs))));
                }
                root._lastGpu = { rc6: rc6, t: nowMs };
            }
            procNet.reload();
            let rxBytes = 0, txBytes = 0;
            for (const nl of procNet.text().split("\n").slice(2)) {
                const parts = nl.trim().split(/[:\s]+/);
                if (parts.length < 10 || parts[0] === "lo" || parts[0] === "") continue;
                rxBytes += Number(parts[1] || 0); txBytes += Number(parts[9] || 0);
            }
            if (root._lastNet && nowMs > root._lastNet.t) {
                const dtSec = (nowMs - root._lastNet.t) / 1000.0;
                root.netRxKbps = Math.max(0, (rxBytes - root._lastNet.rx) / 1024.0 / dtSec);
                root.netTxKbps = Math.max(0, (txBytes - root._lastNet.tx) / 1024.0 / dtSec);
            }
            root._lastNet = { rx: rxBytes, tx: txBytes, t: nowMs };
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE device 2>/dev/null | grep -m1 ':connected$' | cut -d: -f1 || echo none; " +
            "nmcli -t -f ACTIVE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null; " +
            "b=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'); echo \"BRI|${b:-100}\"; " +
            "echo \"SPK|$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)\"; " +
            "echo \"MIC|$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)\"; " +
            "echo \"CAM|$(cat ~/.config/superfedora/webcam-enabled 2>/dev/null || echo on)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n"), type = lines[0] || "none", seen = {}, list = [];
                let activeSsid = "", activeSig = 0;
                for (let i = 1; i < lines.length; i++) {
                    if (lines[i].startsWith("BRI|")) {
                        const bv = Number(lines[i].split("|")[1] || 100);
                        if (!isNaN(bv) && bv > 0) root.brightness = Math.max(0.05, Math.min(1.0, bv / 100.0));
                        continue;
                    }
                    if (lines[i].startsWith("SPK|")) {
                        const sm = lines[i].match(/Volume:\s*([0-9.]+)/);
                        if (sm) root.spkVol = Math.max(0, Math.min(1, Number(sm[1])));
                        root.spkMuted = lines[i].includes("[MUTED]");
                        continue;
                    }
                    if (lines[i].startsWith("MIC|")) {
                        const mm = lines[i].match(/Volume:\s*([0-9.]+)/);
                        if (mm) root.micVol = Math.max(0, Math.min(1, Number(mm[1])));
                        root.micMuted = lines[i].includes("[MUTED]");
                        continue;
                    }
                    if (lines[i].startsWith("CAM|")) {
                        const cv = (lines[i].split("|")[1] || "on").trim().toLowerCase();
                        root.webcamEnabled = (cv !== "off" && cv !== "0" && cv !== "false");
                        continue;
                    }
                    const parts = lines[i].split(":"); if (parts.length < 3) continue;
                    const act = parts[0] === "yes", sig = Number(parts[1] || 0), name = parts.slice(2).join(":").trim();
                    if (!name) continue;
                    if (act) { activeSsid = name; activeSig = sig; }
                    if (!seen[name] && list.length < 6) { seen[name] = true; list.push({ ssid: name, signal: sig, active: act }); }
                }
                root.wifiList = list;
                root.netType = (type === "wifi" || type === "ethernet") ? type : "none";
                root.signal = type === "wifi" ? activeSig : 0;
                root.ssid = type === "wifi" ? activeSsid : "";
            }
        }
    }

    Process {
        id: tzProc
        command: ["sh", "-c",
            "mkdir -p ~/.config/superfedora; f=~/.config/superfedora/clock.conf; [ -f \"$f\" ] && . \"$f\"; " +
            "w=~/.config/superfedora/world-clocks.txt; [ -f \"$w\" ] || printf 'UTC\\nAmerica/New_York\\nAmerica/Los_Angeles\\nEurope/London\\n' > \"$w\"; " +
            "c24=\"${CLOCK_24H:-1}\"; csec=\"${CLOCK_SECONDS:-0}\"; tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo Local); abbr=$(date +%Z); " +
            "auto=$(gsettings get org.gnome.desktop.datetime automatic-timezone 2>/dev/null || echo true); echo \"CFG|$c24|$csec|$tz ($abbr)|$auto\"; " +
            "fmt=$([ \"$c24\" = \"1\" ] && echo '%a %H:%M' || echo '%a %I:%M %p'); " +
            "while IFS= read -r z; do [ -n \"$z\" ] && printf 'WC|%s|%s\\n' \"$z\" \"$(TZ=\"$z\" date +\"$fmt\")\"; done < \"$w\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const wc = [];
                for (const line of text.trim().split("\n")) {
                    const p = line.split("|");
                    if (p[0] === "CFG") {
                        root.clock24h = p[1] !== "0"; root.clockSeconds = p[2] === "1";
                        root.localTz = p[3] || "Local"; root.autoTz = p[4] === "true";
                    } else if (p[0] === "WC" && p.length >= 3) wc.push({ tz: p[1], time: p[2] });
                }
                root.worldClocks = wc;
            }
        }
    }

    function saveClockPrefs(use24h, showSec) {
        root.clock24h = use24h; root.clockSeconds = showSec;
        Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.config/superfedora && printf 'CLOCK_24H=%s\\nCLOCK_SECONDS=%s\\n' " + (use24h ? "1" : "0") + " " + (showSec ? "1" : "0") + " > ~/.config/superfedora/clock.conf"]);
        tzProc.running = true;
    }

    function setBrightness(val) {
        const clamped = Math.max(0.05, Math.min(1.0, val));
        root.brightness = clamped;
        Quickshell.execDetached(["sh", "-c", "brightnessctl -e4 -n2 set " + Math.round(clamped * 100) + "% >/dev/null 2>&1 || true"]);
    }

    function reloadSfx() { sfxFile.reload(); root.sfxEnabled = !sfxFile.text().trim().includes("SFX_ENABLED=0"); }
    function reloadWebcam() { netProc.running = true; }
    function playSfx(name) { if (root.sfxEnabled) Quickshell.execDetached(["sh", "-c", "(~/.local/bin/sf sfx play " + name + " || ~/Projects/superfedora/superfedora/lib/sfx.sh play " + name + ") >/dev/null 2>&1"]); }
    function toggleSfx() { root.sfxEnabled = !root.sfxEnabled; Quickshell.execDetached(["sh", "-c", "(~/.local/bin/sf sfx toggle || ~/Projects/superfedora/superfedora/lib/sfx.sh toggle) >/dev/null 2>&1"]); }
    function toggleSpeakerMute(m) { const next = (typeof m === "boolean") ? m : !root.spkMuted; root.spkMuted = next; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh speaker " + (next ? "mute" : "unmute")]); }
    function setSpeakerVolume(val) { const c = Math.max(0, Math.min(1, val)); root.spkVol = c; Quickshell.execDetached(["sh", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + Math.round(c * 100) + "%"]); }
    function toggleMicMute(m) { const next = (typeof m === "boolean") ? m : !root.micMuted; root.micMuted = next; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh mic " + (next ? "mute" : "unmute")]); }
    function setMicVolume(val) { const c = Math.max(0, Math.min(1, val)); root.micVol = c; Quickshell.execDetached(["sh", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ " + Math.round(c * 100) + "%"]); }
    function toggleWebcam() { root.webcamEnabled = !root.webcamEnabled; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh webcam " + (root.webcamEnabled ? "on" : "off")]); }

    function toggleSuperDeck(sec) {
        const target = sec || "quick";
        if (root.superDeckOpen && root.superDeckSection === target) root.superDeckOpen = false;
        else { root.superDeckSection = target; root.superDeckOpen = true; root.refresh(); }
        root.playSfx("click");
    }

    Process { id: idleProc; command: ["pgrep", "-x", "hypridle"]; onExited: code => root.idleEnabled = code === 0 }

    property bool appGridOpen: false; property var clients: []
    property var dockConfig: ({ position: "bottom", autohide: false, showAlways: true, opacity: 1.0, pinned: ["kitty", "org.mozilla.firefox", "com.google.Chrome", "org.gnome.Nautilus", "nvim", "btop"] })
    property var wsModes: ({}); property string defaultWsMode: "dwindle"

    FileView { id: dockFile; path: Quickshell.env("HOME") + "/.config/superfedora/dock.json" }
    FileView { id: modesFile; path: Quickshell.env("HOME") + "/.config/superfedora/workspace-modes.json" }

    function reloadDock(): void {
        dockFile.reload(); const raw = dockFile.text().trim();
        if (raw) { try { const d = JSON.parse(raw); if (d && typeof d === "object") root.dockConfig = d; } catch (e) {} }
        modesFile.reload(); const mraw = modesFile.text().trim();
        if (mraw) { try { const m = JSON.parse(mraw); if (m && m.workspaces) root.wsModes = m.workspaces; if (m && m.default) root.defaultWsMode = m.default; } catch (e) {} }
    }

    function wsModeFor(wsId): string { const k = String(wsId); return (root.wsModes && root.wsModes[k]) ? root.wsModes[k] : root.defaultWsMode; }
    function runDockCmd(args): void { Quickshell.execDetached(["sh", "-c", "~/.local/bin/superfedora dock " + args + " 2>/dev/null || ~/Projects/superfedora/superfedora/lib/panel-ctl.sh " + args]); }

    Process {
        id: clientsProc
        command: ["sh", "-c", "hyprctl clients -j 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(text.trim() || "[]");
                    root.clients = arr.filter(c => c.mapped && c.workspace && (c.workspace.id > 0 || String(c.workspace.name || "").includes("minimized")));
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = String(event.name || "");
            if (n.includes("window") || n.includes("workspace") || n === "focusedmon") clientsProc.running = true;
        }
    }

    Timer { interval: 3500; running: true; repeat: true; triggeredOnStart: true; onTriggered: clientsProc.running = true }
    Component.onCompleted: { root.reloadDock(); root.reloadSfx(); root.reloadWebcam(); }

    IpcHandler {
        target: "dock"
        function reload(): void { root.reloadDock(); clientsProc.running = true; }
        function toggleApps(): void { root.appGridOpen = !root.appGridOpen; root.playSfx("click"); }
        function toggle(): void { root.runDockCmd("always toggle"); }
    }
    IpcHandler {
        target: "superdeck"
        function toggle(): void { root.toggleSuperDeck("quick"); }
        function open(sec: string): void { root.superDeckSection = sec || "quick"; root.superDeckOpen = true; root.refresh(); }
    }
    IpcHandler { target: "panels"; function settings(): void { root.toggleSuperDeck("dock"); } }
    IpcHandler { target: "status"; function refresh(): void { root.refresh(); } }

    Timer {
        interval: 6000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { netProc.running = true; idleProc.running = true; tzProc.running = true; root.reloadSfx(); root.reloadWebcam(); }
    }
    function refresh() { netProc.running = true; idleProc.running = true; tzProc.running = true; clientsProc.running = true; root.reloadDock(); root.reloadSfx(); root.reloadWebcam(); }
}
