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

    // --- CPU & RAM from /proc/stat and /proc/meminfo -------------------
    property var _lastCpu: null

    FileView {
        id: procStat
        path: "/proc/stat"
    }

    FileView {
        id: procMem
        path: "/proc/meminfo"
    }

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

    // --- hypridle running? ---------------------------------------------
    Process {
        id: idleProc
        command: ["pgrep", "-x", "hypridle"]
        onExited: code => root.idleEnabled = code === 0
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netProc.running = true;
            idleProc.running = true;
        }
    }

    function refresh() {
        netProc.running = true;
        idleProc.running = true;
    }
}
