import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import ".."

// GNOME Settings-Style Preference Pages for SuperFedora Settings (12 Categories, Boxed Preference Groups).
Item {
    id: pg
    property string activePage: "wifi"
    property string forgeMsg: "Compiler Profile: -O3 -march=native -flto=auto  ·  Installs into ~/.local/bin"
    signal executeCommand(string cmd, bool closeAfter)

    readonly property var btAdapter: Bluetooth.defaultAdapter; readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var btList: btAdapter ? Bluetooth.devices.values.slice(0, 8) : []
    readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
    readonly property var aiAgents: [
        { id: "agy", label: "Antigravity (agy)" }, { id: "claude", label: "Claude Code" }, { id: "chatgpt", label: "ChatGPT / Codex" },
        { id: "grok", label: "xAI Grok" }, { id: "vibe", label: "Mistral Vibe" }, { id: "mcode", label: "MiniMax Code" }, { id: "ollama", label: "Ollama (Pi)" }
    ]
    readonly property var forgeTargets: ["https://claude.ai", "https://chatgpt.com", "https://github.com", "https://youtube.com", "btop", "fastfetch", "ripgrep", "fd"]
    function esc(s) { return String(s || "").replace(/'/g, "'\\''"); }
    function submitStartup() { const c = startupIn.text.trim(); if (!c) return; Status.addStartupApp(c); startupIn.text = ""; }
    function submitForge(t) { const q = String(t || forgeIn.text || "").trim().replace(/['"]/g, ""); if (!q) return; Status.runForge(q); }

    ColumnLayout {
        anchors { fill: parent; leftMargin: 20; rightMargin: 20; topMargin: 14; bottomMargin: 14 }
        spacing: 12

        // ---------------- 1. WI-FI ----------------
        ColumnLayout {
            visible: pg.activePage === "wifi"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 62; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; margins: 14 } spacing: 10
                    ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Wi-Fi Adapter"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: Status.wifiEnabled ? (Status.ssid ? ("Connected to " + Status.ssid + " (" + Status.signal + "%)") : "Enabled — Select a network below") : "Wireless radio is turned off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } }
                    Rectangle { implicitWidth: 108; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ RESCAN ]"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("nmcli device wifi rescan; sleep 1 && qs ipc call status refresh", false) } }
                    Rectangle { implicitWidth: 120; implicitHeight: 32; radius: Theme.radiusSm; color: Status.wifiEnabled ? Theme.green : Theme.red; Text { anchors.centerIn: parent; text: Status.wifiEnabled ? "[ ON ]" : "[ OFF ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleWifiRadio() } }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; clip: true
                ColumnLayout {
                    anchors { fill: parent; margins: 12 } spacing: 6
                    Text { text: "VISIBLE & SAVED WIRELESS NETWORKS"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                    Repeater {
                        model: Status.wifiList
                        Rectangle {
                            id: wfItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: modelData.active ? Theme.bg : "transparent"; border.width: 1; border.color: modelData.active ? Theme.cyan : Theme.border
                            RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10; Text { text: wfItem.modelData.ssid; color: wfItem.modelData.active ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: wfItem.modelData.active; Layout.fillWidth: true } Text { text: wfItem.modelData.security + " · " + wfItem.modelData.signal + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } Rectangle { implicitWidth: 120; implicitHeight: 26; radius: Theme.radiusSm; color: wfItem.modelData.active ? Theme.green : Theme.blue; Text { anchors.centerIn: parent; text: wfItem.modelData.active ? "[ DISCONNECT ]" : "[ CONNECT ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(wfItem.modelData.active ? ("nmcli connection down '" + pg.esc(wfItem.modelData.ssid) + "'") : ("nmcli device wifi connect '" + pg.esc(wfItem.modelData.ssid) + "'"), false) } } Rectangle { visible: wfItem.modelData.saved || wfItem.modelData.active; implicitWidth: 86; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ FORGET ]"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("nmcli connection delete '" + pg.esc(wfItem.modelData.ssid) + "'", false) } } }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ---------------- 2. NETWORK ----------------
        ColumnLayout {
            visible: pg.activePage === "network"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Repeater {
                model: [
                    { t: "Active Network Transport", s: "Current link: " + Status.netType.toUpperCase() + "  ·  RX: " + Math.round(Status.netRxKbps) + " KB/s  ·  TX: " + Math.round(Status.netTxKbps) + " KB/s", b: "[ OPEN NMTUI ]", c: "kitty --class floating-term -e nmtui" },
                    { t: "Advanced Connection Profiles (VPN / VLAN / 802.1X)", s: "Configure static IPv4/IPv6 routes, WireGuard/OpenVPN, and enterprise certificates", b: "[ CONNECTION EDITOR ]", c: "nm-connection-editor || kitty --class floating-term -e nmtui" },
                    { t: "DNS Resolver Cache", s: "Flush systemd-resolved DNS caches across all interfaces", b: "[ FLUSH DNS ]", c: "resolvectl flush-caches && notify-send -a SuperFedora 'Network' 'Flushed DNS cache'" }
                ]
                Rectangle {
                    id: netItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 72; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    RowLayout { anchors { fill: parent; margins: 14 } spacing: 12; ColumnLayout { Layout.fillWidth: true; spacing: 4; Text { text: netItem.modelData.t; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: netItem.modelData.s; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } } Rectangle { implicitWidth: 184; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: netItem.modelData.b; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(netItem.modelData.c, false) } } }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // ---------------- 3. BLUETOOTH ----------------
        ColumnLayout {
            visible: pg.activePage === "bluetooth"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 62; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; margins: 14 } spacing: 10
                    ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Bluetooth Radio"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: pg.btEnabled ? "Adapter powered on and ready for pairing" : "Bluetooth adapter is powered off"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } }
                    Rectangle { implicitWidth: 116; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ SCAN 15S ]"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("bluetoothctl --timeout 15 scan on >/dev/null 2>&1 &", false) } }
                    Rectangle { implicitWidth: 120; implicitHeight: 32; radius: Theme.radiusSm; color: pg.btEnabled ? Theme.green : Theme.red; Text { anchors.centerIn: parent; text: pg.btEnabled ? "[ ON ]" : "[ OFF ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(pg.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", false) } }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; clip: true
                ColumnLayout {
                    anchors { fill: parent; margins: 12 } spacing: 6
                    Text { text: "PAIRED & DISCOVERED DEVICES"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                    Repeater { model: pg.btList; Rectangle { id: btItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: modelData.connected ? Theme.bg : "transparent"; border.width: 1; border.color: modelData.connected ? Theme.cyan : Theme.border; RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10; Text { text: (btItem.modelData.name || "Unknown") + "  [" + btItem.modelData.address + "]"; color: btItem.modelData.connected ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: btItem.modelData.connected; Layout.fillWidth: true } Rectangle { implicitWidth: 124; implicitHeight: 26; radius: Theme.radiusSm; color: btItem.modelData.connected ? Theme.green : Theme.blue; Text { anchors.centerIn: parent; text: btItem.modelData.connected ? "[ DISCONNECT ]" : "[ CONNECT ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const d = btItem.modelData; pg.executeCommand(d.connected ? ("bluetoothctl disconnect " + d.address) : ("bluetoothctl connect " + d.address), false); } } } Rectangle { implicitWidth: 86; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ REMOVE ]"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("bluetoothctl remove " + btItem.modelData.address, false) } } } } }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ---------------- 4. DISPLAYS ----------------
        ColumnLayout {
            visible: pg.activePage === "displays"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 68; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout { anchors { fill: parent; margins: 14 } spacing: 10; ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Display Backlight Brightness (" + Math.round(Status.brightness * 100) + "%)"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: "Adjust internal panel luminance"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } } Repeater { model: [{ l: "[ 25% ]", v: 0.25 }, { l: "[ 50% ]", v: 0.5 }, { l: "[ 75% ]", v: 0.75 }, { l: "[ 100% ]", v: 1.0 }]; Rectangle { id: brItem; required property var modelData; implicitWidth: 78; implicitHeight: 32; radius: Theme.radiusSm; color: Math.abs(Status.brightness - modelData.v) < 0.08 ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: brItem.modelData.l; color: Math.abs(Status.brightness - brItem.modelData.v) < 0.08 ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.setBrightness(brItem.modelData.v) } } } }
            }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 68; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout { anchors { fill: parent; margins: 14 } spacing: 10; ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Monitor UI Scale Factor"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: "Apply crisp Wayland fractional or integer scaling"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } } Repeater { model: [{ l: "[ 100% ]", s: "1" }, { l: "[ 125% ]", s: "1.25" }, { l: "[ 150% ]", s: "1.5" }, { l: "[ 200% ]", s: "2" }]; Rectangle { id: scItem; required property var modelData; implicitWidth: 82; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: scItem.modelData.l; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("hyprctl keyword monitor ,preferred,auto," + scItem.modelData.s, false) } } } }
            }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 68; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout { anchors { fill: parent; margins: 14 } spacing: 10; ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Night Light & Keyboard Backlight DPMS Sync"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: "Warm eye-care filter and automatic keyboard LED shutoff when screen blanks"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } } Rectangle { implicitWidth: 156; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.yellow; Text { anchors.centerIn: parent; text: "[ NIGHT LIGHT ]"; color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("~/.local/bin/sf theme nightlight toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh nightlight toggle", false) } } Rectangle { implicitWidth: 168; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "[ KBD LIGHT: " + (Status.kbdBacklight === 0 ? "OFF" : (Status.kbdBacklight === 1 ? "LOW" : "HIGH")) + " ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.setKbdBacklight() } } }
            }
            Item { Layout.fillHeight: true }
        }

        // ---------------- 5. SOUND / 7. MULTITASKING / 8. APPEARANCE ----------------
        AiTab { visible: pg.activePage === "sound"; Layout.fillWidth: true; Layout.fillHeight: true; activeTab: "audio"; onExecuteCommand: (c, cl) => pg.executeCommand(c, cl) }
        LauncherMenu { visible: pg.activePage === "multitasking" || pg.activePage === "appearance"; Layout.fillWidth: true; Layout.fillHeight: true; activeSection: pg.activePage === "appearance" ? "theme" : "shell"; onExecuteCommand: (c, cl) => pg.executeCommand(c, cl) }

        // ---------------- 6. POWER ----------------
        ColumnLayout {
            visible: pg.activePage === "power"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 68; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; margins: 14 } spacing: 10
                    ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Battery & Idle Power Management (" + (pg.batPresent ? (pg.batPct + "%") : "AC") + ")"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: "Threshold: " + Status.bat0Threshold + "  ·  Coffee / Idle: " + (Status.idleMode === "lock" ? "Lock Only (No Screen Off)" : (Status.idleMode === "screensaver" ? "Screensaver Only" : "Screen Power Off")); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } }
                    Rectangle { implicitWidth: 214; implicitHeight: 32; radius: Theme.radiusSm; color: Status.idleMode === "lock" ? Theme.cyan : (Status.idleMode === "screensaver" ? Theme.yellow : Theme.blue); Text { anchors.centerIn: parent; text: Status.idleMode === "lock" ? "[ 󰅶 󰌾 COFFEE: LOCK ONLY ]" : (Status.idleMode === "screensaver" ? "[ 󰅶 COFFEE: SCREENSAVER ]" : "[ 󰒲 AUTO-IDLE: POWER OFF ]"); color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleIdle() } }
                    Rectangle { implicitWidth: 164; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "[ SCREEN OFF NOW ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("sleep 0.2; ~/.config/hypr/scripts/toggle-touchpad.sh dpms off", true) } }
                }
            }
            GridLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 10; columnSpacing: 10
                Repeater { model: [{ l: "[ 󰌾 LOCK SESSION ]", c: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session", col: Theme.cyan }, { l: "[ 󰤄 SUSPEND SYSTEM ]", c: "systemctl suspend", col: Theme.yellow }, { l: "[ 󰜉 REBOOT WORKSTATION ]", c: "systemctl reboot", col: Theme.orange }, { l: "[ 󰐥 POWER OFF ]", c: "systemctl poweroff", col: Theme.red }]; Rectangle { id: pwItem; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: modelData.col; Text { anchors.centerIn: parent; text: pwItem.modelData.l; color: pwItem.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(pwItem.modelData.c, true) } } }
            }
        }

        // ---------------- 9. STARTUP APPS (View, Run, Add & Remove Login Autostart Apps) ----------------
        ColumnLayout {
            visible: pg.activePage === "startup"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 64; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; margins: 12 } spacing: 10
                    Text { text: "ADD STARTUP APP:"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 36; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: startupIn.activeFocus ? Theme.cyan : Theme.border; TextInput { id: startupIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; clip: true; Keys.onReturnPressed: pg.submitStartup(); Text { visible: startupIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Command to launch at login (e.g. synology-drive, discord, flatpak run ...)"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } } }
                    Rectangle { implicitWidth: 164; implicitHeight: 36; radius: Theme.radiusSm; color: Theme.green; Text { anchors.centerIn: parent; text: "[ + ADD TO LOGIN ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.submitStartup() } }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; clip: true
                ColumnLayout {
                    anchors { fill: parent; margins: 12 } spacing: 6
                    Text { text: "CONFIGURED AUTOSTART APPLICATIONS (~/.config/hypr/conf/autostart.conf)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                    Repeater {
                        model: Status.startupApps
                        Rectangle {
                            id: stItem; required property string modelData; Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.border
                            RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10; Text { text: "▸ " + stItem.modelData; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight } Rectangle { implicitWidth: 96; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "[ RUN NOW ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(stItem.modelData, false) } } Rectangle { implicitWidth: 88; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ REMOVE ]"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.removeStartupApp(stItem.modelData) } } }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ---------------- 10. KEYBOARD & MOUSE ----------------
        ColumnLayout {
            visible: pg.activePage === "input"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Repeater {
                model: [
                    { t: "Keyboard Layout & Repeat Rate", s: "US layout with CapsLock as Compose  ·  40 chars/sec repeat", b: "[ SWITCH XKB LAYOUT ]", c: "hyprctl switchxkblayout all next" },
                    { t: "ELAN Touchpad & TrackPoint", s: "Natural scrolling, tap-to-click, and disable-while-typing enabled", b: "[ TOGGLE TOUCHPAD ]", c: "~/.config/hypr/scripts/toggle-touchpad.sh touchpad" },
                    { t: "COSMIC + SuperFedora Keyboard Shortcuts", s: "View the full searchable keybinding reference sheet (Super + F1)", b: "[ VIEW SHORTCUTS ]", c: "~/.config/hypr/scripts/keybindings.sh" }
                ]
                Rectangle { id: inItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 72; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; RowLayout { anchors { fill: parent; margins: 14 } spacing: 12; ColumnLayout { Layout.fillWidth: true; spacing: 4; Text { text: inItem.modelData.t; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: inItem.modelData.s; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } } Rectangle { implicitWidth: 184; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: inItem.modelData.b; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(inItem.modelData.c, false) } } } }
            }
            Item { Layout.fillHeight: true }
        }

        // ---------------- 11. SOURCE & WEBAPP FORGE (In-Depth Builder, Chromeless Firefox WebApps & Curated Targets) ----------------
        ColumnLayout {
            visible: pg.activePage === "forge"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 92; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Status.forgeBusy ? Theme.yellow : Theme.border
                ColumnLayout {
                    anchors { fill: parent; margins: 12 } spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: (Status.forgeBusy || Status.forgeRecent) ? ("󰙪 " + Status.forgeTarget + " (" + Status.forgePct + "%) — " + Status.forgeStep) : pg.forgeMsg; color: Status.forgeBusy ? Theme.yellow : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Rectangle { implicitWidth: 256; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Status.forgeIsolated ? Theme.orange : Theme.green; Text { anchors.centerIn: parent; text: Status.forgeIsolated ? "[ PROFILE: ISOLATED SANDBOX ]" : "[ PROFILE: SHARED (MAIN FIREFOX) ]"; color: Status.forgeIsolated ? Theme.orange : Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Status.forgeIsolated = !Status.forgeIsolated; Status.playSfx("toggle"); } } }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle { Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: forgeIn.activeFocus ? Theme.cyan : Theme.border; TextInput { id: forgeIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; clip: true; Keys.onReturnPressed: pg.submitForge(forgeIn.text); Text { visible: forgeIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "https://claude.ai  or  https://github.com/owner/repo"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 } } }
                        Rectangle { implicitWidth: 156; implicitHeight: 34; radius: Theme.radiusSm; color: Status.forgeBusy ? Theme.yellow : Theme.blue; Text { anchors.centerIn: parent; text: Status.forgeBusy ? ("[ FORGING " + Status.forgePct + "% ]") : "[ FORGE & INSTALL ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.submitForge(forgeIn.text) } }
                        Rectangle { implicitWidth: 136; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.green; Text { anchors.centerIn: parent; text: "[ 󰚰 UPDATE ALL ]"; color: Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.submitForge("update") } }
                    }
                }
            }
            GridLayout { Layout.fillWidth: true; implicitHeight: 84; columns: 4; rowSpacing: 8; columnSpacing: 8; Repeater { model: pg.forgeTargets; Rectangle { id: ftItem; required property string modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ + " + ftItem.modelData.replace(/^https:\/\//, "").toUpperCase() + " ]"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.submitForge(ftItem.modelData) } } } }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border; clip: true
                ColumnLayout {
                    anchors { fill: parent; margins: 10 } spacing: 4
                    Text { text: "INSTALLED CHROMELESS FIREFOX WEBAPPS (~/.local/share/applications/sf-webapp-*.desktop)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    Repeater { model: Status.forgedWebApps; Rectangle { id: waItem; required property var modelData; Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.border; RowLayout { anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8; Text { text: "▸ " + waItem.modelData.name + "  [" + (waItem.modelData.mode || "shared").toUpperCase() + "]  —  " + waItem.modelData.url; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; Layout.fillWidth: true; elide: Text.ElideRight } Rectangle { implicitWidth: 78; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "[ OPEN ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(waItem.modelData.bin, false) } } Rectangle { implicitWidth: 78; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ + DOCK ]"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.runDockCmd("pin '" + waItem.modelData.app_id + "'") } } Rectangle { implicitWidth: 78; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ REMOVE ]"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.removeForge(waItem.modelData.slug) } } } } }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ---------------- 12. SYSTEM & STATE (AI Harness Selection, Comms Cast Testbench & Btrfs Snapshots) ----------------
        ColumnLayout {
            visible: pg.activePage === "system"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 82; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                ColumnLayout {
                    anchors { fill: parent; margins: 10 } spacing: 6
                    RowLayout { Layout.fillWidth: true; Text { text: "DEFAULT AI HARNESS / CLI AGENT (Used by SuperDock [`] AI & Quake Terminal)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.fillWidth: true } Rectangle { implicitWidth: 158; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ OLLAMA SERVER & MODEL ]"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("~/.config/hypr/scripts/quake-ai.sh prompt-ollama", false) } } }
                    RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6; Repeater { model: pg.aiAgents; Rectangle { id: agItem; required property var modelData; readonly property bool isCur: Status.aiAgent === modelData.id; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: isCur ? Theme.blue : Theme.bg; border.width: 1; border.color: isCur ? Theme.cyan : Theme.border; Text { anchors.centerIn: parent; text: agItem.modelData.label; color: agItem.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.selectAiAgent(agItem.modelData.id) } } } }
                }
            }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 42; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 6
                    Text { text: "16-BIT COMMS & BANNERS:"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    Repeater {
                        model: [
                            { l: "[READY]", a: "banner", v: "ready", c: Theme.primary }, { l: "[WARN]", a: "banner", v: "warning", c: Theme.danger },
                            { l: "[UPDATE]", a: "banner", v: "update", c: Theme.ok }, { l: "[CHKPT]", a: "banner", v: "checkpoint", c: Theme.cyan },
                            { l: "[CAST: AI]", a: "cast", v: "ai", c: Theme.primary }, { l: "[CAST: SEC]", a: "cast", v: "security", c: Theme.danger },
                            { l: "[CAST: FORGE]", a: "cast", v: "builder", c: Theme.ok }, { l: "[CAST: ENG]", a: "cast", v: "engineer", c: Theme.accent }, { l: "[CAST: APP]", a: "cast", v: "app", c: Theme.magenta }
                        ]
                        Rectangle {
                            required property var modelData; Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm; color: cbM.containsMouse ? modelData.c : Theme.bg; border.width: 1; border.color: modelData.c
                            Text { anchors.centerIn: parent; text: parent.modelData.l; color: cbM.containsMouse ? Theme.bg : parent.modelData.c; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                            MouseArea { id: cbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.notifAction) Status.notifAction(parent.modelData.a, parent.modelData.v); } }
                        }
                    }
                }
            }
            LauncherMenu { Layout.fillWidth: true; Layout.fillHeight: true; activeSection: "state"; onExecuteCommand: (c, cl) => pg.executeCommand(c, cl) }
        }
    }
}
