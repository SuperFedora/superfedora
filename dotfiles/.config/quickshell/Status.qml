pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lightweight system probes (CPU, RAM, GPU, Temp, Net Throughput, Wi-Fi, Clocks, Panels).
Singleton {
    id: root

    property int cpu: 0
    property int mem: 0
    property int gpu: 0
    property int tempC: 40
    property real netRxKbps: 0
    property real netTxKbps: 0
    property string netType: "none"     // wifi | ethernet | none
    property string ssid: ""
    property int signal: 0
    property var wifiList: []
    property bool idleEnabled: true
    property bool clock24h: true
    property bool clockSeconds: false
    property string localTz: "Local"
    property bool autoTz: true
    property var worldClocks: []

    // --- Fast Localhost Telemetry (/proc/stat, /proc/meminfo, /proc/net/dev, thermal, drm) ---
    property var _lastCpu: null
    property var _lastNet: null
    property var _lastGpu: null

    FileView { id: procStat; path: "/proc/stat" }
    FileView { id: procMem; path: "/proc/meminfo" }
    FileView { id: procNet; path: "/proc/net/dev" }
    FileView { id: pkgTemp; path: "/sys/class/thermal/thermal_zone6/temp" }
    FileView { id: fallbackTemp; path: "/sys/class/thermal/thermal_zone0/temp" }
    FileView { id: gpuRc6; path: "/sys/class/drm/card1/gt/gt0/rc6_residency_ms" }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const nowMs = Date.now();
            procStat.reload();
            const v = procStat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            if (v.length >= 4) {
                const idle = v[3] + (v[4] || 0);
                const total = v.reduce((a, b) => a + b, 0);
                if (root._lastCpu) {
                    const dt = total - root._lastCpu.total;
                    root.cpu = dt > 0 ? Math.round(100 * (1 - (idle - root._lastCpu.idle) / dt)) : 0;
                }
                root._lastCpu = { total, idle };
            }
            procMem.reload();
            const mtext = procMem.text();
            const mt = mtext.match(/MemTotal:\s+(\d+)/);
            const ma = mtext.match(/MemAvailable:\s+(\d+)/);
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
            let rxBytes = 0; let txBytes = 0;
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

    // --- Network via nmcli ---------------------------------------------
    Process {
        id: netProc
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE device 2>/dev/null | grep -m1 ':connected$' | cut -d: -f1 || echo none; " +
            "nmcli -t -f ACTIVE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const type = lines[0] || "none";
                const seen = {};
                const list = [];
                let activeSsid = "";
                let activeSig = 0;
                for (let i = 1; i < lines.length; i++) {
                    const parts = lines[i].split(":");
                    if (parts.length < 3) continue;
                    const act = parts[0] === "yes";
                    const sig = Number(parts[1] || 0);
                    const name = parts.slice(2).join(":").trim();
                    if (!name) continue;
                    if (act) { activeSsid = name; activeSig = sig; }
                    if (!seen[name] && list.length < 6) {
                        seen[name] = true;
                        list.push({ ssid: name, signal: sig, active: act });
                    }
                }
                root.wifiList = list;
                root.netType = (type === "wifi" || type === "ethernet") ? type : "none";
                root.signal = type === "wifi" ? activeSig : 0;
                root.ssid = type === "wifi" ? activeSsid : "";
            }
        }
    }

    // --- Clock settings, Timezone & World Clocks -----------------------
    Process {
        id: tzProc
        command: ["sh", "-c",
            "mkdir -p ~/.config/superfedora; " +
            "f=~/.config/superfedora/clock.conf; [ -f \"$f\" ] && . \"$f\"; " +
            "w=~/.config/superfedora/world-clocks.txt; " +
            "[ -f \"$w\" ] || printf 'UTC\\nAmerica/New_York\\nAmerica/Los_Angeles\\nEurope/London\\n' > \"$w\"; " +
            "c24=\"${CLOCK_24H:-1}\"; csec=\"${CLOCK_SECONDS:-0}\"; " +
            "tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo Local); " +
            "abbr=$(date +%Z); " +
            "auto=$(gsettings get org.gnome.desktop.datetime automatic-timezone 2>/dev/null || echo true); " +
            "echo \"CFG|$c24|$csec|$tz ($abbr)|$auto\"; " +
            "fmt=$([ \"$c24\" = \"1\" ] && echo '%a %H:%M' || echo '%a %I:%M %p'); " +
            "while IFS= read -r z; do [ -n \"$z\" ] && printf 'WC|%s|%s\\n' \"$z\" \"$(TZ=\"$z\" date +\"$fmt\")\"; done < \"$w\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const wc = [];
                for (const line of text.trim().split("\n")) {
                    const p = line.split("|");
                    if (p[0] === "CFG") {
                        root.clock24h = p[1] !== "0";
                        root.clockSeconds = p[2] === "1";
                        root.localTz = p[3] || "Local";
                        root.autoTz = p[4] === "true";
                    } else if (p[0] === "WC" && p.length >= 3) {
                        wc.push({ tz: p[1], time: p[2] });
                    }
                }
                root.worldClocks = wc;
            }
        }
    }

    function saveClockPrefs(use24h, showSec) {
        root.clock24h = use24h;
        root.clockSeconds = showSec;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p ~/.config/superfedora && printf 'CLOCK_24H=%s\\nCLOCK_SECONDS=%s\\n' " +
            (use24h ? "1" : "0") + " " + (showSec ? "1" : "0") + " > ~/.config/superfedora/clock.conf"]);
        tzProc.running = true;
    }

    Process {
        id: idleProc
        command: ["pgrep", "-x", "hypridle"]
        onExited: code => root.idleEnabled = code === 0
    }

    // --- Hyprland clients & Multi-Edge Panels Config -------------------
    property bool settingsOpen: false
    property var clients: []
    property var dockOrder: ["launcher", "terminal", "browser", "files", "editor", "monitor", "panels", "theme"]
    property var panels: ({
        top:    { enabled: true,  span: "full", percent: 100, thickness: 36, hideMode: "never",      start: ["launcher", "workspaces"], center: ["clock"], end: ["tray", "status"] },
        bottom: { enabled: true,  span: "hug",  percent: 65,  thickness: 52, hideMode: "intellihide", start: [], center: ["apps"], end: [] },
        left:   { enabled: false, span: "hug",  percent: 70,  thickness: 58, hideMode: "never",       start: [], center: ["hardware"], end: [] },
        right:  { enabled: false, span: "hug",  percent: 70,  thickness: 58, hideMode: "never",       start: [], center: ["hardware"], end: [] }
    })

    FileView { id: panelsFile; path: Quickshell.env("HOME") + "/.config/superfedora/panels.json" }

    function reloadPanels(): void {
        panelsFile.reload();
        const raw = panelsFile.text().trim();
        if (!raw) return;
        try {
            const d = JSON.parse(raw);
            if (d && d.top && d.bottom) root.panels = d;
            if (d && Array.isArray(d.dockOrder) && d.dockOrder.length > 0) root.dockOrder = d.dockOrder;
        } catch (e) {}
    }

    function saveDockOrder(newOrder): void {
        root.dockOrder = newOrder;
        Quickshell.execDetached(["python3", "-c",
            "import json,os; p=os.path.expanduser('~/.config/superfedora/panels.json'); " +
            "d=json.load(open(p)) if os.path.exists(p) else {}; d['dockOrder']=" + JSON.stringify(newOrder) + "; " +
            "json.dump(d,open(p,'w'),indent=2)"]);
    }

    function updatePanel(edge, key, val): void {
        Quickshell.execDetached(["sh", "-c",
            "~/.local/bin/superfedora panel set " + edge + " " + key + " '" + val + "' 2>/dev/null || " +
            "~/Projects/superfedora/superfedora/lib/panel-ctl.sh set " + edge + " " + key + " '" + val + "'"]);
    }

    Process {
        id: clientsProc
        command: ["sh", "-c", "hyprctl clients -j 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(text.trim() || "[]");
                    root.clients = arr.filter(c => c.mapped && !c.hidden && c.workspace && c.workspace.id > 0);
                } catch (e) {}
            }
        }
    }

    Timer { interval: 800; running: true; repeat: true; triggeredOnStart: true; onTriggered: clientsProc.running = true }
    Component.onCompleted: root.reloadPanels()

    IpcHandler {
        target: "panels"
        function reload(): void { root.reloadPanels(); }
        function settings(): void { root.settingsOpen = !root.settingsOpen; }
    }

    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { netProc.running = true; idleProc.running = true; tzProc.running = true; }
    }

    function refresh() {
        netProc.running = true; idleProc.running = true; tzProc.running = true; clientsProc.running = true; root.reloadPanels();
    }
}
