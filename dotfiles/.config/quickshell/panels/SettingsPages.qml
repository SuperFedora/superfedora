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
    readonly property var forgeTargets: ["hyprland", "quickshell", "openrgb", "idlescreen", "ripgrep", "fastfetch", "btop", "fd"]

    function esc(s) { return String(s || "").replace(/'/g, "'\\''"); }
    function submitStartup() { const c = startupIn.text.trim(); if (!c) return; Status.addStartupApp(c); startupIn.text = ""; }
    function submitForge(t) {
        const q = String(t || forgeIn.text || "").trim().replace(/['"]/g, ""); if (!q) return;
        pg.forgeMsg = "Forging " + q + " with -O3 -march=native...";
        pg.executeCommand("(~/.local/bin/sf forge '" + q + "' || ~/Projects/superfedora/superfedora/lib/forge.sh '" + q + "') && notify-send -a SuperFedora 'Source Forge' 'Built " + q + "'", false);
    }

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
                            required property var modelData; Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: modelData.active ? Theme.bg : "transparent"; border.width: 1; border.color: modelData.active ? Theme.cyan : Theme.border
                            RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10; Text { text: parent.parent.modelData.ssid; color: parent.parent.modelData.active ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: parent.parent.modelData.active; Layout.fillWidth: true } Text { text: parent.parent.modelData.security + " · " + parent.parent.modelData.signal + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } Rectangle { implicitWidth: 120; implicitHeight: 26; radius: Theme.radiusSm; color: parent.parent.parent.modelData.active ? Theme.green : Theme.blue; Text { anchors.centerIn: parent; text: parent.parent.parent.parent.modelData.active ? "[ DISCONNECT ]" : "[ CONNECT ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(parent.parent.parent.parent.modelData.active ? ("nmcli connection down '" + pg.esc(parent.parent.parent.parent.modelData.ssid) + "'") : ("nmcli device wifi connect '" + pg.esc(parent.parent.parent.parent.modelData.ssid) + "'"), false) } } Rectangle { visible: parent.parent.modelData.saved || parent.parent.modelData.active; implicitWidth: 86; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ FORGET ]"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("nmcli connection delete '" + pg.esc(parent.parent.parent.parent.modelData.ssid) + "'", false) } } }
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
                    required property var modelData; Layout.fillWidth: true; implicitHeight: 72; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    RowLayout { anchors { fill: parent; margins: 14 } spacing: 12; ColumnLayout { Layout.fillWidth: true; spacing: 4; Text { text: parent.parent.modelData.t; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: parent.parent.modelData.s; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } } Rectangle { implicitWidth: 184; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: parent.parent.parent.modelData.b; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(parent.parent.parent.modelData.c, false) } } }
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
                    Repeater {
                        model: pg.btList
                        Rectangle {
                            required property var modelData; Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: modelData.connected ? Theme.bg : "transparent"; border.width: 1; border.color: modelData.connected ? Theme.cyan : Theme.border
                            RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10; Text { text: (parent.parent.modelData.name || "Unknown") + "  [" + parent.parent.modelData.address + "]"; color: parent.parent.modelData.connected ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: parent.parent.modelData.connected; Layout.fillWidth: true } Rectangle { implicitWidth: 124; implicitHeight: 26; radius: Theme.radiusSm; color: parent.parent.parent.modelData.connected ? Theme.green : Theme.blue; Text { anchors.centerIn: parent; text: parent.parent.parent.parent.modelData.connected ? "[ DISCONNECT ]" : "[ CONNECT ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const d = parent.parent.parent.parent.modelData; pg.executeCommand(d.connected ? ("bluetoothctl disconnect " + d.address) : ("bluetoothctl connect " + d.address), false); } } } Rectangle { implicitWidth: 86; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ REMOVE ]"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("bluetoothctl remove " + parent.parent.parent.parent.modelData.address, false) } } }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ---------------- 4. DISPLAYS ----------------
        ColumnLayout {
            visible: pg.activePage === "displays"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 68; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; margins: 14 } spacing: 10
                    ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Display Backlight Brightness (" + Math.round(Status.brightness * 100) + "%)"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: "Adjust internal panel luminance"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } }
                    Repeater { model: [{ l: "[ 25% ]", v: 0.25 }, { l: "[ 50% ]", v: 0.5 }, { l: "[ 75% ]", v: 0.75 }, { l: "[ 100% ]", v: 1.0 }]; Rectangle { required property var modelData; implicitWidth: 78; implicitHeight: 32; radius: Theme.radiusSm; color: Math.abs(Status.brightness - modelData.v) < 0.08 ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: parent.modelData.l; color: Math.abs(Status.brightness - parent.modelData.v) < 0.08 ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.setBrightness(parent.modelData.v) } } }
                }
            }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 68; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; margins: 14 } spacing: 10
                    ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Monitor UI Scale Factor"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: "Apply crisp Wayland fractional or integer scaling"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } }
                    Repeater { model: [{ l: "[ 100% ]", s: "1" }, { l: "[ 125% ]", s: "1.25" }, { l: "[ 150% ]", s: "1.5" }, { l: "[ 200% ]", s: "2" }]; Rectangle { required property var modelData; implicitWidth: 82; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: parent.modelData.l; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("hyprctl keyword monitor ,preferred,auto," + parent.modelData.s, false) } } }
                }
            }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 68; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                RowLayout {
                    anchors { fill: parent; margins: 14 } spacing: 10
                    ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Night Light & Keyboard Backlight DPMS Sync"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: "Warm eye-care filter and automatic keyboard LED shutoff when screen blanks"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } }
                    Rectangle { implicitWidth: 156; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.yellow; Text { anchors.centerIn: parent; text: "[ NIGHT LIGHT ]"; color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("~/.local/bin/sf theme nightlight toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh nightlight toggle", false) } }
                    Rectangle { implicitWidth: 168; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "[ KBD LIGHT: " + (Status.kbdBacklight === 0 ? "OFF" : (Status.kbdBacklight === 1 ? "LOW" : "HIGH")) + " ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.setKbdBacklight() } }
                }
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
                    ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: "Battery & Idle Power Management (" + (pg.batPresent ? (pg.batPct + "%") : "AC") + ")"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: "Threshold: " + Status.bat0Threshold + "  ·  Auto-Idle: " + (Status.idleEnabled ? "Enabled" : "Stay Awake"); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } }
                    Rectangle { implicitWidth: 164; implicitHeight: 32; radius: Theme.radiusSm; color: Status.idleEnabled ? Theme.cyan : Theme.yellow; Text { anchors.centerIn: parent; text: Status.idleEnabled ? "[ AUTO-IDLE: ON ]" : "[ STAY AWAKE ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("~/.config/hypr/scripts/toggle-idle.sh", false) } }
                    Rectangle { implicitWidth: 164; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "[ SCREEN OFF NOW ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand("sleep 0.2; ~/.config/hypr/scripts/toggle-touchpad.sh dpms off", true) } }
                }
            }
            GridLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 10; columnSpacing: 10
                Repeater { model: [{ l: "[ 󰌾 LOCK SESSION ]", c: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session", col: Theme.cyan }, { l: "[ 󰤄 SUSPEND SYSTEM ]", c: "systemctl suspend", col: Theme.yellow }, { l: "[ 󰜉 REBOOT WORKSTATION ]", c: "systemctl reboot", col: Theme.orange }, { l: "[ 󰐥 POWER OFF ]", c: "systemctl poweroff", col: Theme.red }]; Rectangle { required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: modelData.col; Text { anchors.centerIn: parent; text: parent.modelData.l; color: parent.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(parent.modelData.c, true) } } }
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
                            required property string modelData; Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.border
                            RowLayout { anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10; Text { text: "▸ " + parent.parent.modelData; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight } Rectangle { implicitWidth: 96; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "[ RUN NOW ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(parent.parent.parent.parent.modelData, false) } } Rectangle { implicitWidth: 88; implicitHeight: 26; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ REMOVE ]"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.removeStartupApp(parent.parent.parent.parent.modelData) } } }
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
                Rectangle {
                    required property var modelData; Layout.fillWidth: true; implicitHeight: 72; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    RowLayout { anchors { fill: parent; margins: 14 } spacing: 12; ColumnLayout { Layout.fillWidth: true; spacing: 4; Text { text: parent.parent.modelData.t; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { text: parent.parent.modelData.s; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 } } Rectangle { implicitWidth: 184; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: parent.parent.parent.modelData.b; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.executeCommand(parent.parent.parent.modelData.c, false) } } }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // ---------------- 11. SOURCE FORGE (In-Depth GitHub Builder & Curated Targets) ----------------
        ColumnLayout {
            visible: pg.activePage === "forge"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 82; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                ColumnLayout {
                    anchors { fill: parent; margins: 12 } spacing: 6
                    Text { text: pg.forgeMsg; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle { Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: forgeIn.activeFocus ? Theme.cyan : Theme.border; TextInput { id: forgeIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; clip: true; Keys.onReturnPressed: pg.submitForge(forgeIn.text); Text { visible: forgeIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "https://github.com/owner/repo"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 } } }
                        Rectangle { implicitWidth: 164; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.blue; Text { anchors.centerIn: parent; text: "[ FORGE & INSTALL ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.submitForge(forgeIn.text) } }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; columns: 4; rowSpacing: 8; columnSpacing: 8
                Repeater { model: pg.forgeTargets; Rectangle { required property string modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ FORGE " + parent.modelData.toUpperCase() + " ]"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.submitForge(parent.modelData) } } }
            }
        }

        // ---------------- 12. SYSTEM & STATE (AI Harness Selection & Btrfs Snapshots) ----------------
        ColumnLayout {
            visible: pg.activePage === "system"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 88; radius: Theme.radius; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                ColumnLayout {
                    anchors { fill: parent; margins: 12 } spacing: 8
                    Text { text: "DEFAULT AI HARNESS / CLI AGENT (Used by Quick AI & Quake Terminal)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                        Repeater { model: pg.aiAgents; Rectangle { required property var modelData; readonly property bool isCur: Status.aiAgent === modelData.id; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: isCur ? Theme.blue : Theme.bg; border.width: 1; border.color: isCur ? Theme.cyan : Theme.border; Text { anchors.centerIn: parent; text: parent.modelData.label; color: parent.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.selectAiAgent(parent.modelData.id) } } }
                    }
                }
            }
            LauncherMenu { Layout.fillWidth: true; Layout.fillHeight: true; activeSection: "state"; onExecuteCommand: (c, cl) => pg.executeCommand(c, cl) }
        }
    }
}
