pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lightweight system probes (CPU, network, idle) on slow timers.
Singleton {
    id: root

    property int cpu: 0
    property int mem: 0
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

    // --- CPU & RAM from /proc/stat and /proc/meminfo -------------------
    property var _lastCpu: null

    FileView { id: procStat; path: "/proc/stat" }
    FileView { id: procMem; path: "/proc/meminfo" }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            procStat.reload();
            const line = procStat.text().split("\n")[0];
            const v = line.trim().split(/\s+/).slice(1).map(Number);
            if (v.length >= 4) {
                const idle = v[3] + (v[4] || 0);
                const total = v.reduce((a, b) => a + b, 0);
                if (root._lastCpu) {
                    const dt = total - root._lastCpu.total;
                    const di = idle - root._lastCpu.idle;
                    root.cpu = dt > 0 ? Math.round(100 * (1 - di / dt)) : 0;
                }
                root._lastCpu = { total, idle };
            }
            procMem.reload();
            const mtext = procMem.text();
            const mt = mtext.match(/MemTotal:\s+(\d+)/);
            const ma = mtext.match(/MemAvailable:\s+(\d+)/);
            if (mt && ma && Number(mt[1]) > 0) {
                root.mem = Math.round(100 * (1 - Number(ma[1]) / Number(mt[1])));
            }
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
                if (type === "wifi") {
                    root.netType = "wifi";
                    root.signal = activeSig;
                    root.ssid = activeSsid;
                } else if (type === "ethernet") {
                    root.netType = "ethernet";
                    root.ssid = "";
                } else {
                    root.netType = "none";
                    root.ssid = "";
                }
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
                const lines = text.trim().split("\n");
                const wc = [];
                for (const line of lines) {
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

    // --- hypridle running? ---------------------------------------------
    Process {
        id: idleProc
        command: ["pgrep", "-x", "hypridle"]
        onExited: code => root.idleEnabled = code === 0
    }

    // --- Hyprland clients & Multi-Edge Panels Config -------------------
    property bool settingsOpen: false
    property var clients: []
    property var panels: ({
        top:    { enabled: true,  span: "full", percent: 100, thickness: 36, hideMode: "never",      start: ["launcher", "workspaces"], center: ["clock"], end: ["tray", "status"] },
        bottom: { enabled: true,  span: "hug",  percent: 65,  thickness: 52, hideMode: "intellihide", start: [], center: ["apps"], end: [] },
        left:   { enabled: false, span: "hug",  percent: 70,  thickness: 46, hideMode: "intellihide", start: ["launcher"], center: ["workspaces", "apps"], end: ["theme", "status"] },
        right:  { enabled: false, span: "hug",  percent: 70,  thickness: 46, hideMode: "intellihide", start: ["workspaces"], center: ["apps"], end: ["theme", "status"] }
    })

    FileView {
        id: panelsFile
        path: Quickshell.env("HOME") + "/.config/superfedora/panels.json"
    }

    function reloadPanels(): void {
        panelsFile.reload();
        const raw = panelsFile.text().trim();
        if (!raw) return;
        try {
            const d = JSON.parse(raw);
            if (d && d.top && d.bottom) root.panels = d;
        } catch (e) {}
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

    Timer {
        interval: 800
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clientsProc.running = true
    }

    Component.onCompleted: root.reloadPanels()

    IpcHandler {
        target: "panels"
        function reload(): void { root.reloadPanels(); }
        function settings(): void { root.settingsOpen = !root.settingsOpen; }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netProc.running = true;
            idleProc.running = true;
            tzProc.running = true;
        }
    }

    function refresh() {
        netProc.running = true;
        idleProc.running = true;
        tzProc.running = true;
        clientsProc.running = true;
        root.reloadPanels();
    }
}
