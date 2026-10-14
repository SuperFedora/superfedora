pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Consolidated system state & event-driven probes (CPU, RAM, GPU, Temp, Net, Wi-Fi, Brightness, SFX, Dock, SuperDesk, Settings).
Singleton {
    id: root

    property int cpu: 0; property int mem: 0; property int gpu: 0; property int tempC: 40
    property real netRxKbps: 0; property real netTxKbps: 0
    property string netType: "none"; property bool wifiEnabled: true; property string ssid: ""; property int signal: 0; property var wifiList: []; property var savedWifiList: []
    property real brightness: 1.0; property bool idleEnabled: true; property bool sfxEnabled: true
    property real spkVol: 0.6; property bool spkMuted: false; property real micVol: 1.0; property bool micMuted: false; property bool webcamEnabled: true
    property var audioSinks: []; property var audioSources: []; property var startupApps: []
    property int kbdBacklight: 0; property bool bat0Present: false; property string bat0Threshold: "Standard (0% - 100%)"; property string aiAgent: "agy"
    property bool rgbSupported: false; property int rgbCount: 0; property string rgbHex: "7aa2f7"
    property string aiReply: "Ready. Type a prompt above and press Enter for an instant answer, or click [ OPEN TERMINAL ] for an interactive session."
    property bool aiBusy: false; property string _pendingAiPrompt: ""
    property bool pocketOpen: false; property bool centerToolsOpen: false; property bool superDeckOpen: false; property string superDeckSection: "ai"; property bool superDeckPowerHighlight: false
    property bool screenRecording: false; property bool voxActive: false; property int updatesCount: 0; property string weatherTemp: ""
    property bool settingsOpen: false; property string settingsPage: "wifi"
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

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const nowMs = Date.now(); procStat.reload(); const v = procStat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            if (v.length >= 4) { const idle = v[3] + (v[4] || 0), total = v.reduce((a, b) => a + b, 0); if (root._lastCpu) { const dt = total - root._lastCpu.total; root.cpu = dt > 0 ? Math.round(100 * (1 - (idle - root._lastCpu.idle) / dt)) : 0; } root._lastCpu = { total, idle }; }
            procMem.reload(); const mtext = procMem.text(), mt = mtext.match(/MemTotal:\s+(\d+)/), ma = mtext.match(/MemAvailable:\s+(\d+)/);
            if (mt && ma && Number(mt[1]) > 0) root.mem = Math.round(100 * (1 - Number(ma[1]) / Number(mt[1])));
            pkgTemp.reload(); let rawT = Number(pkgTemp.text().trim() || "0");
            if (!rawT || rawT <= 0) { fallbackTemp.reload(); rawT = Number(fallbackTemp.text().trim() || "40000"); }
            root.tempC = Math.round(rawT > 1000 ? rawT / 1000 : rawT);
            gpuRc6.reload(); const rc6Txt = gpuRc6.text().trim();
            if (rc6Txt !== "") { const rc6 = Number(rc6Txt); if (root._lastGpu && nowMs > root._lastGpu.t) root.gpu = Math.max(0, Math.min(100, Math.round(100 * (1 - Math.max(0, rc6 - root._lastGpu.rc6) / (nowMs - root._lastGpu.t))))); root._lastGpu = { rc6: rc6, t: nowMs }; }
            procNet.reload(); let rxBytes = 0, txBytes = 0;
            for (const nl of procNet.text().split("\n").slice(2)) { const parts = nl.trim().split(/[:\s]+/); if (parts.length >= 10 && parts[0] !== "lo" && parts[0] !== "") { rxBytes += Number(parts[1] || 0); txBytes += Number(parts[9] || 0); } }
            if (root._lastNet && nowMs > root._lastNet.t) { const dtSec = (nowMs - root._lastNet.t) / 1000.0; root.netRxKbps = Math.max(0, (rxBytes - root._lastNet.rx) / 1024.0 / dtSec); root.netTxKbps = Math.max(0, (txBytes - root._lastNet.tx) / 1024.0 / dtSec); }
            root._lastNet = { rx: rxBytes, tx: txBytes, t: nowMs };
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE device 2>/dev/null | grep -m1 ':connected$' | cut -d: -f1 || echo none; " +
            "echo \"WFR|$(nmcli radio wifi 2>/dev/null || echo enabled)\"; " +
            "nmcli -t -f TYPE,NAME connection show 2>/dev/null | awk '/^802-11-wireless:/{sub(/^802-11-wireless:/,\"\");gsub(/\\\\:/,\":\");print \"SAV|\"$0}'; " +
            "nmcli -t -f ACTIVE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null; " +
            "wpctl status 2>/dev/null | awk '/^Video/{exit} /Sinks:/{s=\"SNK\";next} /Sources:/{s=\"SRC\";next} /Filters:|Streams:/{s=\"\";next} s&&match($0,/(\\*?)[[:space:]]*([0-9]+)\\.[[:space:]]+([^\\[]+)/,m){n=m[3];sub(/[[:space:]]+$/,\"\",n);sub(/^.*Audio[[:space:]]+/,\"\",n);sub(/[[:space:]]*Output.*$/,\"\",n);sub(/HDMI \\/ DisplayPort/,\"HDMI/DP\",n);sub(/Microphone/,\"Mic\",n);print s\"|\"m[2]\"|\"((m[1]==\"*\")?1:0)\"|\"n}'; " +
            "b=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'); echo \"BRI|${b:-100}\"; " +
            "echo \"SPK|$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)\"; echo \"MIC|$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)\"; " +
            "echo \"CAM|$(cat ~/.config/superfedora/webcam-enabled 2>/dev/null || echo on)\"; " +
            "~/.config/hypr/scripts/toggle-touchpad.sh dpms sync >/dev/null 2>&1 || true; k=$(cat /sys/class/leds/tpacpi::kbd_backlight/brightness ~/.config/superfedora/kbd-backlight 2>/dev/null | head -n1); echo \"KBD|${k:-0}\"; " +
            "ag=$(grep '^AI_AGENT=' ~/.config/superfedora/quake-ai.env 2>/dev/null | cut -d= -f2 | tr -d \"'\\\"\"); echo \"AGY|${ag:-agy}\"; " +
            "awk -F'=' '/^[[:space:]]*exec-once[[:space:]]*=/{c=$2; sub(/^[[:space:]]+/,\"\",c); if(c!~/(systemctl|superfedora\\.locked|hyprpolkitagent|sfx play startup)/) print \"STA|\"c}' ~/.config/hypr/conf/autostart.conf 2>/dev/null || true; " +
            "echo \"RGB|$(cat ~/.config/superfedora/rgb-devices 2>/dev/null || echo 0)|$(cat ~/.config/superfedora/rgb-color 2>/dev/null || echo 7aa2f7)\"; " +
            "(pgrep -x wf-recorder >/dev/null || pgrep -f '^gpu-screen-recorder' >/dev/null) && echo 'REC|1' || echo 'REC|0'; " +
            "(pgrep -x voxtype >/dev/null || pgrep -f 'pw-record.*superfedora-vox' >/dev/null) && echo 'VOX|1' || echo 'VOX|0'; " +
            "wf=~/.cache/superfedora-weather; if [ ! -f \"$wf\" ] || [ -n \"$(find \"$wf\" -mmin +15 2>/dev/null)\" ]; then (curl -fsSL --max-time 3 'https://wttr.in/?format=%t' 2>/dev/null | tr -d '+' > \"$wf\" &) 2>/dev/null; fi; echo \"WTH|$(cat \"$wf\" 2>/dev/null | tr -d '\\n')\"; " +
            "uf=~/.cache/superfedora-updates; if [ ! -f \"$uf\" ] || [ -n \"$(find \"$uf\" -mmin +30 2>/dev/null)\" ]; then (dnf check-update -q 2>/dev/null | grep -cE '^[a-zA-Z0-9]' > \"$uf\" &) 2>/dev/null; fi; echo \"UPD|$(cat \"$uf\" 2>/dev/null | head -n1)\"; " +
            "if [ -d /sys/class/power_supply/BAT0 ]; then bs=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold /sys/class/power_supply/BAT0/charge_start_threshold 2>/dev/null | head -n1); be=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold /sys/class/power_supply/BAT0/charge_stop_threshold 2>/dev/null | head -n1); echo \"BAT0|1|${bs:-0}|${be:-100}\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n"), type = lines[0] || "none", byName = {}, list = [], saved = [], sinks = [], sources = [], stApps = [];
                let activeSsid = "", activeSig = 0;
                for (let i = 1; i < lines.length; i++) {
                    if (lines[i].startsWith("WFR|")) { root.wifiEnabled = (lines[i].split("|")[1] || "enabled").trim() !== "disabled"; continue; }
                    if (lines[i].startsWith("SAV|")) { const sv = lines[i].slice(4).trim(); if (sv && saved.indexOf(sv) === -1) saved.push(sv); continue; }
                    if (lines[i].startsWith("SNK|") || lines[i].startsWith("SRC|")) { const p = lines[i].split("|"), arr = (p[0] === "SNK" ? sinks : sources); if (arr.length < 6 || p[2] === "1") arr.push({ id: p[1], active: p[2] === "1", name: p.slice(3).join("|") }); continue; }
                    if (lines[i].startsWith("BRI|")) { const bv = Number(lines[i].split("|")[1] || 100); if (!isNaN(bv) && bv > 0) root.brightness = Math.max(0.05, Math.min(1.0, bv / 100.0)); continue; }
                    if (lines[i].startsWith("SPK|")) { const sm = lines[i].match(/Volume:\s*([0-9.]+)/); if (sm) root.spkVol = Math.max(0, Math.min(1, Number(sm[1]))); root.spkMuted = lines[i].includes("[MUTED]"); continue; }
                    if (lines[i].startsWith("MIC|")) { const mm = lines[i].match(/Volume:\s*([0-9.]+)/); if (mm) root.micVol = Math.max(0, Math.min(1, Number(mm[1]))); root.micMuted = lines[i].includes("[MUTED]"); continue; }
                    if (lines[i].startsWith("CAM|")) { const cv = (lines[i].split("|")[1] || "on").trim().toLowerCase(); root.webcamEnabled = (cv !== "off" && cv !== "0" && cv !== "false"); continue; }
                    if (lines[i].startsWith("KBD|")) { root.kbdBacklight = Math.max(0, Math.min(2, Number(lines[i].split("|")[1] || 0))); continue; }
                    if (lines[i].startsWith("AGY|")) { root.aiAgent = (lines[i].split("|")[1] || "agy").trim(); continue; }
                    if (lines[i].startsWith("STA|")) { const sc = lines[i].slice(4).trim(); if (sc) stApps.push(sc); continue; }
                    if (lines[i].startsWith("RGB|")) { const rp = lines[i].split("|"); root.rgbCount = Number(rp[1] || 0); root.rgbSupported = root.rgbCount > 0; root.rgbHex = (rp[2] || "7aa2f7").replace(/^#/, ""); continue; }
                    if (lines[i].startsWith("REC|")) { root.screenRecording = (lines[i].split("|")[1] || "0").trim() === "1"; continue; }
                    if (lines[i].startsWith("VOX|")) { root.voxActive = (lines[i].split("|")[1] || "0").trim() === "1"; continue; }
                    if (lines[i].startsWith("WTH|")) { root.weatherTemp = (lines[i].split("|")[1] || "").trim(); continue; }
                    if (lines[i].startsWith("UPD|")) { root.updatesCount = Number((lines[i].split("|")[1] || "0").trim()) || 0; continue; }
                    if (lines[i].startsWith("BAT0|")) { const bp = lines[i].split("|"); root.bat0Present = true; root.bat0Threshold = "Start " + (bp[2] || "0") + "% / Stop " + (bp[3] || "100") + "%"; continue; }
                    const parts = lines[i].split(":"); if (parts.length < 4) continue;
                    const act = parts[0] === "yes", sig = Number(parts[1] || 0), sec = (parts[2] || "").trim(), name = parts.slice(3).join(":").replace(/\\:/g, ":").replace(/\\\\/g, "\\").trim(), open = (!sec || sec === "--");
                    if (!name) continue;
                    if (act) { activeSsid = name; activeSig = sig; }
                    if (byName[name]) { if (act) byName[name].active = true; if (sig > byName[name].signal) byName[name].signal = sig; }
                    else if (list.length < 8 || act) { const item = { ssid: name, signal: sig, active: act, open: open, security: open ? "OPEN" : "WPA", saved: saved.indexOf(name) !== -1 }; byName[name] = item; list.push(item); }
                }
                list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.savedWifiList = saved; root.audioSinks = sinks; root.audioSources = sources; root.startupApps = stApps;
                root.wifiList = list.slice(0, 8); root.netType = (type === "wifi" || type === "ethernet") ? type : "none";
                root.signal = type === "wifi" ? activeSig : 0; root.ssid = type === "wifi" ? activeSsid : "";
            }
        }
    }

    Process { id: rgbProbeProc; command: ["sh", "-c", "mkdir -p ~/.config/superfedora; c=0; if command -v openrgb >/dev/null 2>&1; then c=$(timeout 3 openrgb --noautoconnect -l 2>/dev/null | grep -cE '^[0-9]+: ' || true); fi; [ \"$c\" -gt 0 ] && echo \"$c\" > ~/.config/superfedora/rgb-devices || rm -f ~/.config/superfedora/rgb-devices; qs ipc call status refresh >/dev/null 2>&1 || true"] }
    Process { id: aiAskProc; command: ["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh ask " + JSON.stringify(root._pendingAiPrompt)]; stdout: StdioCollector { onStreamFinished: { root.aiReply = text.trim() || "Done."; root.aiBusy = false; } } }
    Process {
        id: tzProc
        command: ["sh", "-c", "mkdir -p ~/.config/superfedora; f=~/.config/superfedora/clock.conf; [ -f \"$f\" ] && . \"$f\"; w=~/.config/superfedora/world-clocks.txt; [ -f \"$w\" ] || printf 'UTC\\nAmerica/New_York\\nAmerica/Los_Angeles\\nEurope/London\\n' > \"$w\"; c24=\"${CLOCK_24H:-1}\"; csec=\"${CLOCK_SECONDS:-0}\"; tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo Local); abbr=$(date +%Z); auto=$(gsettings get org.gnome.desktop.datetime automatic-timezone 2>/dev/null || echo true); echo \"CFG|$c24|$csec|$tz ($abbr)|$auto\"; fmt=$([ \"$c24\" = \"1\" ] && echo '%a %H:%M' || echo '%a %I:%M %p'); while IFS= read -r z; do [ -n \"$z\" ] && printf 'WC|%s|%s\\n' \"$z\" \"$(TZ=\"$z\" date +\"$fmt\")\"; done < \"$w\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const wc = [];
                for (const line of text.trim().split("\n")) {
                    const p = line.split("|");
                    if (p[0] === "CFG") { root.clock24h = p[1] !== "0"; root.clockSeconds = p[2] === "1"; root.localTz = p[3] || "Local"; root.autoTz = p[4] === "true"; }
                    else if (p[0] === "WC" && p.length >= 3) wc.push({ tz: p[1], time: p[2] });
                }
                root.worldClocks = wc;
            }
        }
    }

    function setRgbColor(hex) { if (!root.rgbSupported) return; const h = String(hex || "7aa2f7").replace(/^#/, ""); root.rgbHex = h === "off" ? "000000" : h; root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "~/.local/bin/sf theme rgb '" + h + "' || ~/Projects/superfedora/superfedora/lib/apply-theme.sh rgb '" + h + "'"]); }
    function askQuickAi(prompt) { const q = String(prompt || "").trim(); if (!q || root.aiBusy) return; root._pendingAiPrompt = q; root.aiBusy = true; root.aiReply = "Querying " + root.aiAgent.toUpperCase() + "..."; root.playSfx("confirm"); aiAskProc.running = true; }
    function addStartupApp(cmd) { const c = String(cmd || "").trim().replace(/'/g, ""); if (!c) return; root.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", "grep -Fqx 'exec-once = " + c + "' ~/.config/hypr/conf/autostart.conf 2>/dev/null || printf '\\nexec-once = %s\\n' '" + c + "' >> ~/.config/hypr/conf/autostart.conf; [ -f ~/Projects/superfedora/superfedora/dotfiles/.config/hypr/conf/autostart.conf ] && cp -f ~/.config/hypr/conf/autostart.conf ~/Projects/superfedora/superfedora/dotfiles/.config/hypr/conf/autostart.conf; qs ipc call status refresh"]); }
    function removeStartupApp(cmd) { const c = String(cmd || "").trim().replace(/'/g, ""); if (!c) return; root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "awk -v t='exec-once = " + c + "' '$0 != t' ~/.config/hypr/conf/autostart.conf > ~/.config/hypr/conf/autostart.conf.tmp && mv ~/.config/hypr/conf/autostart.conf.tmp ~/.config/hypr/conf/autostart.conf; [ -f ~/Projects/superfedora/superfedora/dotfiles/.config/hypr/conf/autostart.conf ] && cp -f ~/.config/hypr/conf/autostart.conf ~/Projects/superfedora/superfedora/dotfiles/.config/hypr/conf/autostart.conf; qs ipc call status refresh"]); }
    function saveClockPrefs(use24h, showSec) { root.clock24h = use24h; root.clockSeconds = showSec; Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.config/superfedora && printf 'CLOCK_24H=%s\\nCLOCK_SECONDS=%s\\n' " + (use24h ? "1" : "0") + " " + (showSec ? "1" : "0") + " > ~/.config/superfedora/clock.conf"]); tzProc.running = true; }
    function setBrightness(val) { const c = Math.max(0.05, Math.min(1.0, val)); root.brightness = c; Quickshell.execDetached(["sh", "-c", "brightnessctl -e4 -n2 set " + Math.round(c * 100) + "% >/dev/null 2>&1 || true"]); }
    function reloadSfx() { sfxFile.reload(); root.sfxEnabled = !sfxFile.text().trim().includes("SFX_ENABLED=0"); }
    function reloadWebcam() { netProc.running = true; }
    function playSfx(name) { if (root.sfxEnabled) Quickshell.execDetached(["sh", "-c", "(~/.local/bin/sf sfx play " + name + " || ~/Projects/superfedora/superfedora/lib/sfx.sh play " + name + ") >/dev/null 2>&1"]); }
    function toggleSfx() { root.sfxEnabled = !root.sfxEnabled; Quickshell.execDetached(["sh", "-c", "(~/.local/bin/sf sfx toggle || ~/Projects/superfedora/superfedora/lib/sfx.sh toggle) >/dev/null 2>&1"]); }
    function toggleWifiRadio(en) { const next = (typeof en === "boolean") ? en : !root.wifiEnabled; root.wifiEnabled = next; if (!next && root.netType === "wifi") { root.netType = "none"; root.ssid = ""; root.signal = 0; root.wifiList = []; } root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "nmcli radio wifi " + (next ? "on" : "off") + "; sleep 0.5 && qs ipc call status refresh >/dev/null 2>&1 || true"]); }
    function toggleSpeakerMute(m) { const next = (typeof m === "boolean") ? m : !root.spkMuted; root.spkMuted = next; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh speaker " + (next ? "mute" : "unmute")]); }
    function setSpeakerVolume(val) { const c = Math.max(0, Math.min(1, val)); root.spkVol = c; Quickshell.execDetached(["sh", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + Math.round(c * 100) + "%"]); }
    function toggleMicMute(m) { const next = (typeof m === "boolean") ? m : !root.micMuted; root.micMuted = next; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh mic " + (next ? "mute" : "unmute")]); }
    function setMicVolume(val) { const c = Math.max(0, Math.min(1, val)); root.micVol = c; Quickshell.execDetached(["sh", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ " + Math.round(c * 100) + "%"]); }
    function setAudioDefault(id) { const sid = String(id); if (root.audioSinks.some(s => s.id === sid)) root.audioSinks = root.audioSinks.map(s => ({ id: s.id, active: s.id === sid, name: s.name })); if (root.audioSources.some(s => s.id === sid)) root.audioSources = root.audioSources.map(s => ({ id: s.id, active: s.id === sid, name: s.name })); root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "wpctl set-default " + sid + "; sleep 0.2 && qs ipc call status refresh >/dev/null 2>&1 || true"]); }
    function toggleWebcam() { root.webcamEnabled = !root.webcamEnabled; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh webcam " + (root.webcamEnabled ? "on" : "off")]); }
    function setKbdBacklight(lvl) { const next = (typeof lvl === "number") ? Math.max(0, Math.min(2, lvl)) : ((root.kbdBacklight + 1) % 3); root.kbdBacklight = next; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-touchpad.sh kbd-backlight " + next]); }
    function selectAiAgent(id) { root.aiAgent = id; root.playSfx("click"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh select-agent '" + id + "'"]); }
    function nextAiAgent() { const ids = ["agy", "mcode", "grok", "vibe", "claude", "chatgpt", "ollama"]; root.selectAiAgent(ids[(ids.indexOf(root.aiAgent) + 1) % ids.length]); }

    function normalizeDeckTab(sec) {
        const s = String(sec || "").toLowerCase();
        if (s === "ai" || s === "harness" || s === "agent" || s === "1") return "ai";
        if (s === "wifi" || s === "net" || s === "wlan" || s === "2") return "wifi";
        if (s === "bluetooth" || s === "bt" || s === "3") return "bluetooth";
        if (s === "audio" || s === "sensors" || s === "cam" || s === "mic" || s === "speaker" || s === "io" || s === "zerotrust" || s === "4") return "audio";
        if (s === "display" || s === "screen" || s === "kbd" || s === "input" || s === "5") return "display";
        if (s === "theme" || s === "appearance" || s === "surface" || s === "6") return "theme";
        if (s === "shell" || s === "bar" || s === "dock" || s === "7") return "shell";
        if (s === "forge" || s === "software" || s === "build" || s === "8") return "forge";
        if (s === "state" || s === "snapshots" || s === "btrfs" || s === "system" || s === "9") return "state";
        return (s === "power" || s === "battery" || s === "session" || s === "0" || s === "10") ? "power" : (root.superDeckSection || "ai");
    }
    function normalizeSettingsPage(p) {
        const s = String(p || "").toLowerCase();
        if (s === "wifi" || s === "2") return "wifi"; if (s === "network" || s === "net") return "network"; if (s === "bluetooth" || s === "bt" || s === "3") return "bluetooth";
        if (s === "display" || s === "displays" || s === "5") return "displays"; if (s === "audio" || s === "sound" || s === "4") return "sound"; if (s === "power" || s === "0") return "power";
        if (s === "shell" || s === "multitasking" || s === "dock" || s === "bar" || s === "7") return "multitasking"; if (s === "theme" || s === "appearance" || s === "6") return "appearance";
        if (s === "startup" || s === "apps" || s === "autostart") return "startup"; if (s === "input" || s === "keyboard" || s === "mouse") return "input"; if (s === "forge" || s === "8") return "forge";
        return (s === "state" || s === "system" || s === "ai" || s === "1" || s === "9") ? "system" : (root.settingsPage || "wifi");
    }
    property bool _quakeShown: false
    function syncQuakeAi(hdrH) { const want = root.superDeckOpen && root.normalizeDeckTab(root.superDeckSection) === "ai"; if (!want && !root._quakeShown) return; root._quakeShown = want; Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh " + (want ? ("show " + (hdrH || 40)) : "hide keep-deck") + " >/dev/null 2>&1"]); }
    onSuperDeckOpenChanged: root.syncQuakeAi()
    onSuperDeckSectionChanged: if (root.superDeckOpen) root.syncQuakeAi()
    function openSettings(page) { root.superDeckOpen = false; if (page) root.settingsPage = root.normalizeSettingsPage(page); root.settingsOpen = true; root.refresh(); root.playSfx("click"); }
    function toggleSettings(page) {
        if (!page) { root.superDeckOpen = false; root.settingsOpen = !root.settingsOpen; }
        else { const p = root.normalizeSettingsPage(page); if (root.settingsOpen && root.settingsPage === p) root.settingsOpen = false; else { root.superDeckOpen = false; root.settingsPage = p; root.settingsOpen = true; } }
        if (root.settingsOpen) root.refresh(); root.playSfx("click");
    }
    function toggleSuperDeck(sec) {
        root.settingsOpen = false;
        if (!sec || sec === "last") { root.superDeckPowerHighlight = false; root.superDeckOpen = !root.superDeckOpen; }
        else { const t = root.normalizeDeckTab(sec); if (root.superDeckOpen && root.superDeckSection === t) root.superDeckOpen = false; else { root.superDeckSection = t; root.superDeckPowerHighlight = (t === "power"); root.superDeckOpen = true; } }
        if (root.superDeckOpen) root.refresh(); root.playSfx("click");
    }
    function toggleIdle() { root.idleEnabled = !root.idleEnabled; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle-idle.sh"]); }
    function toggleScreenRecord(region) { root.screenRecording = !root.screenRecording; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/screenshot.sh " + (region ? "record-region" : "record")]); }
    function toggleVox() { root.voxActive = !root.voxActive; root.playSfx("toggle"); Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/screenshot.sh vox"]); }
    Process { id: idleProc; command: ["sh", "-c", "[ ! -f ~/.config/superfedora/stay-awake ] && pgrep -x hypridle >/dev/null"]; onExited: code => root.idleEnabled = code === 0 }
    property bool appGridOpen: false; property var clients: []
    property var dockConfig: ({ position: "bottom", autohide: false, showAlways: true, opacity: 1.0, pinned: ["kitty", "org.mozilla.firefox", "com.google.Chrome", "org.gnome.Nautilus", "nvim", "btop"] })
    property var wsModes: ({}); property string defaultWsMode: "dwindle"
    readonly property var defaultBarIcons: ["wifi", "bluetooth", "|", "speaker", "mic", "camera", "|", "battery", "power"]
    readonly property var coreBarIcons: ["wifi", "bluetooth", "speaker", "mic", "camera", "battery", "power"]
    property var barIcons: ["wifi", "bluetooth", "|", "speaker", "mic", "camera", "|", "battery", "power"]
    property var barHiddenIcons: []
    FileView { id: dockFile; path: Quickshell.env("HOME") + "/.config/superfedora/dock.json" }
    FileView { id: modesFile; path: Quickshell.env("HOME") + "/.config/superfedora/workspace-modes.json" }
    FileView { id: barIconsFile; path: Quickshell.env("HOME") + "/.config/superfedora/bar-icons.json" }
    function reloadBarIcons(): void {
        barIconsFile.reload(); const raw = barIconsFile.text().trim(); if (!raw) return;
        try {
            const d = JSON.parse(raw), seen = {}, out = [];
            if (d && Array.isArray(d.order)) {
                for (const id of d.order) { if (id === "|") out.push("|"); else if (root.coreBarIcons.indexOf(id) !== -1 && !seen[id]) { seen[id] = true; out.push(id); } }
                for (const id of root.coreBarIcons) if (!seen[id]) out.push(id);
                root.barIcons = out;
            }
            if (d && Array.isArray(d.hidden)) root.barHiddenIcons = d.hidden.filter(id => root.coreBarIcons.indexOf(id) !== -1);
        } catch (e) {}
    }
    function saveBarIcons(): void { Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.config/superfedora && printf '%s\\n' '" + JSON.stringify({ order: root.barIcons, hidden: root.barHiddenIcons }) + "' > ~/.config/superfedora/bar-icons.json"]); }
    function swapBarIcons(fromIdx, toIdx): void {
        const arr = root.barIcons.slice(); if (fromIdx < 0 || toIdx < 0 || fromIdx >= arr.length || toIdx >= arr.length || fromIdx === toIdx) return;
        const tmp = arr[fromIdx]; arr[fromIdx] = arr[toIdx]; arr[toIdx] = tmp; root.barIcons = arr; root.playSfx("click"); root.saveBarIcons();
    }
    function moveBarIcon(id, dir): void {
        const arr = root.barIcons.slice(), idx = arr.indexOf(id), step = dir < 0 ? -1 : 1; if (idx < 0) return;
        let t = idx + step; while (t >= 0 && t < arr.length && arr[t] === "|") t += step;
        if (t >= 0 && t < arr.length) root.swapBarIcons(idx, t);
    }
    function toggleBarIconHidden(id): void {
        if (!id || id === "|" || root.coreBarIcons.indexOf(id) === -1) return;
        const h = root.barHiddenIcons.slice(), i = h.indexOf(id); if (i >= 0) h.splice(i, 1); else h.push(id);
        root.barHiddenIcons = h; root.playSfx("toggle"); root.saveBarIcons();
    }
    function toggleBarDividers(): void {
        if (root.barIcons.indexOf("|") !== -1) root.barIcons = root.barIcons.filter(x => x !== "|");
        else { const c = root.barIcons.filter(x => x !== "|"); root.barIcons = [c[0], c[1], "|", c[2], c[3], c[4], "|", c[5], c[6]].filter(Boolean); }
        root.playSfx("toggle"); root.saveBarIcons();
    }
    function resetBarIcons(): void { root.barIcons = root.defaultBarIcons.slice(); root.barHiddenIcons = []; root.playSfx("toggle"); root.saveBarIcons(); }
    function reloadDock(): void {
        dockFile.reload(); const raw = dockFile.text().trim(); if (raw) { try { const d = JSON.parse(raw); if (d && typeof d === "object") root.dockConfig = d; } catch (e) {} }
        modesFile.reload(); const mraw = modesFile.text().trim(); if (mraw) { try { const m = JSON.parse(mraw); if (m && m.workspaces) root.wsModes = m.workspaces; if (m && m.default) root.defaultWsMode = m.default; } catch (e) {} }
    }
    function wsModeFor(wsId): string { const k = String(wsId); return (root.wsModes && root.wsModes[k]) ? root.wsModes[k] : root.defaultWsMode; }
    function runDockCmd(args): void { Quickshell.execDetached(["sh", "-c", "~/.local/bin/superfedora dock " + args + " 2>/dev/null || ~/Projects/superfedora/superfedora/lib/panel-ctl.sh " + args]); }
    Process { id: clientsProc; command: ["sh", "-c", "hyprctl clients -j 2>/dev/null || echo '[]'"]; stdout: StdioCollector { onStreamFinished: { try { const arr = JSON.parse(text.trim() || "[]"); root.clients = arr.filter(c => c.mapped && c.workspace && (c.workspace.id > 0 || String(c.workspace.name || "").includes("minimized"))); } catch (e) {} } } }
    Connections { target: Hyprland; function onRawEvent(event) { const n = String(event.name || ""), d = String(event.data || ""); if (n.includes("window") || n.includes("workspace") || n.includes("focusedmon")) clientsProc.running = true; if (n === "activewindow" && root._quakeShown && d !== "," && !d.startsWith("quake-ai,")) root.superDeckOpen = false; } }
    Component.onCompleted: { root.reloadBarIcons(); root.reloadDock(); root.reloadSfx(); root.reloadWebcam(); clientsProc.running = true; rgbProbeProc.running = true; }
    IpcHandler { target: "dock"; function reload(): void { root.reloadDock(); clientsProc.running = true; } function toggleApps(): void { root.appGridOpen = !root.appGridOpen; root.playSfx("click"); } function toggle(): void { root.runDockCmd("always toggle"); } }
    IpcHandler { target: "superdeck"; function toggle(): void { root.toggleSuperDeck(""); } function toggleAi(): void { root.toggleSuperDeck("ai"); } function open(sec: string): void { const t = root.normalizeDeckTab(sec), wasOpen = root.superDeckOpen, prev = root.superDeckSection; root.settingsOpen = false; root.superDeckPowerHighlight = (t === "power"); root.superDeckSection = t; root.superDeckOpen = true; if (wasOpen && prev === t) root.syncQuakeAi(); root.refresh(); } function numkey(n: string): void { if (root.superDeckOpen) { const t = root.normalizeDeckTab(n), prev = root.superDeckSection; root.superDeckPowerHighlight = (t === "power"); root.superDeckSection = t; if (prev === t) root.syncQuakeAi(); root.refresh(); root.playSfx("click"); } else Hyprland.dispatch("workspace " + (n === "0" ? "empty" : n)); } function close(): void { root.superDeckOpen = false; } }
    IpcHandler { target: "settings"; function toggle(): void { root.toggleSettings(""); } function open(page: string): void { root.openSettings(page); } function close(): void { root.settingsOpen = false; } }
    IpcHandler { target: "panels"; function settings(): void { root.toggleSettings(""); } }
    IpcHandler { target: "status"; function refresh(): void { root.refresh(); } function reloadBar(): void { root.reloadBarIcons(); } }
    Timer { interval: 4500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    function refresh() { netProc.running = true; idleProc.running = true; tzProc.running = true; clientsProc.running = true; root.reloadDock(); root.reloadSfx(); root.reloadWebcam(); }
}
