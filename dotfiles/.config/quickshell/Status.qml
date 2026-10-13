pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lightweight system probes (CPU, network, idle) on slow timers.
Singleton {
    id: root

    property int cpu: 0
    property string netType: "none"     // wifi | ethernet | none
    property string ssid: ""
    property int signal: 0
    property bool idleEnabled: true

    // --- CPU from /proc/stat -------------------------------------------
    property var _lastCpu: null

    FileView {
        id: procStat
        path: "/proc/stat"
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
            if (v.length < 4) return;
            const idle = v[3] + (v[4] || 0);
            const total = v.reduce((a, b) => a + b, 0);
            if (root._lastCpu) {
                const dt = total - root._lastCpu.total;
                const di = idle - root._lastCpu.idle;
                root.cpu = dt > 0 ? Math.round(100 * (1 - di / dt)) : 0;
            }
            root._lastCpu = { total, idle };
        }
    }

    // --- Network via nmcli ---------------------------------------------
    Process {
        id: netProc
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE device 2>/dev/null | grep -m1 ':connected$' | cut -d: -f1; " +
            "nmcli -t -f ACTIVE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null | grep -m1 '^yes'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const type = lines[0] || "";
                if (type === "wifi") {
                    const parts = (lines[1] || "").split(":");
                    root.netType = "wifi";
                    root.signal = Number(parts[1] || 0);
                    root.ssid = parts.slice(2).join(":");
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
