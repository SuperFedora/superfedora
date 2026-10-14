import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth

// Per-icon quick-action popover anchored beneath the clicked right-side bar icon.
PanelWindow {
    id: pop

    property string tab: ""
    property int rightOffset: 6
    property var targetScreen: Quickshell.screens[0]

    visible: pop.tab !== "" && pop.tab !== "ai"
    screen: pop.targetScreen
    color: "transparent"

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barHeight + 6
        right: Math.max(6, pop.rightOffset)
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 260
    implicitHeight: box.implicitHeight

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioReady: sink !== null && sink.audio !== null
    readonly property real vol: audioReady ? sink.audio.volume : 0
    readonly property bool muted: audioReady ? sink.audio.muted : true

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled

    readonly property var batDev: UPower.displayDevice
    readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    function runCmd(cmd, closeAfter) {
        if (closeAfter) pop.tab = "";
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    readonly property var rows: {
        if (pop.tab === "bluetooth") {
            const list = [
                { header: "BLUETOOTH" },
                { info: pop.btEnabled ? "Status: Enabled" : "Status: Off" },
                { label: pop.btEnabled ? "Turn Bluetooth Off" : "Turn Bluetooth On",
                  cmd: pop.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", close: false }
            ];
            if (pop.btAdapter) {
                for (const d of Bluetooth.devices.values) {
                    if (d.connected || d.paired) {
                        list.push({ label: (d.connected ? "[*] " : "[ ] ") + (d.name || d.address),
                                    cmd: "bluetoothctl " + (d.connected ? "disconnect " : "connect ") + d.address, close: false });
                    }
                }
            }
            list.push({ label: "More Settings (bluetui)...", cmd: "PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e bluetui", close: true, accent: true });
            return list;
        }
        if (pop.tab === "network") {
            const statusText = Status.netType === "wifi"
                ? ("Wi-Fi: " + (Status.ssid || "Connected") + " (" + Status.signal + "%)")
                : (Status.netType === "ethernet" ? "Ethernet: Connected" : "Status: Offline");
            const list = [
                { header: "NETWORK" },
                { info: statusText },
                { label: Status.netType === "wifi" ? "Turn Wi-Fi Off" : "Turn Wi-Fi On",
                  cmd: (Status.netType === "wifi" ? "nmcli radio wifi off" : "nmcli radio wifi on") + "; sleep 0.5", close: false }
            ];
            for (const w of Status.wifiList) {
                const safe = w.ssid.replace(/'/g, "'\\''");
                list.push({
                    label: (w.active ? "[*] " : "[ ] ") + w.ssid + " (" + w.signal + "%)",
                    cmd: w.active
                        ? "nmcli connection down '" + safe + "'"
                        : "nmcli device wifi connect '" + safe + "' || PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wlctl",
                    close: false
                });
            }
            list.push({ label: "More Settings (wlctl)...", cmd: "PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wlctl", close: true, accent: true });
            return list;
        }
        if (pop.tab === "audio") {
            const pct = Math.round(pop.vol * 100);
            return [
                { header: "AUDIO OUTPUT" },
                { info: (pop.muted ? "Muted" : ("Volume: " + pct + "%")), barValue: pop.vol, isAudioBar: true },
                { label: pop.muted ? "Unmute Output" : "Mute Output", action: "mute" },
                { label: "Volume +10%", action: "vol_up" },
                { label: "Volume -10%", action: "vol_down" },
                { label: "More Settings (wiremix)...", cmd: "PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wiremix", close: true, accent: true }
            ];
        }
        if (pop.tab === "cpu") {
            return [
                { header: "SYSTEM MONITOR" },
                { info: "CPU Load: " + Status.cpu + "%", barValue: Status.cpu / 100.0 },
                { info: "Memory Used: " + Status.mem + "%", barValue: Status.mem / 100.0 },
                { label: Status.idleEnabled ? "Enable Stay-Awake Mode" : "Resume Idle Screensaver",
                  cmd: "~/.config/hypr/scripts/toggle-idle.sh", close: false },
                { label: "More Settings (btop)...", cmd: "kitty --class floating-term -e btop", close: true, accent: true }
            ];
        }
        if (pop.tab === "battery") {
            return [
                { header: "BATTERY & POWER" },
                { info: (pop.batCharging ? "Charging: " : "On Battery: ") + pop.batPct + "%", barValue: pop.batPct / 100.0 },
                { label: "Profile: Performance", cmd: "tuned-adm profile throughput-performance 2>/dev/null || powerprofilesctl set performance 2>/dev/null", close: false },
                { label: "Profile: Balanced",    cmd: "tuned-adm profile balanced 2>/dev/null || powerprofilesctl set balanced 2>/dev/null", close: false },
                { label: "Profile: Power Saver", cmd: "tuned-adm profile powersave 2>/dev/null || powerprofilesctl set power-saver 2>/dev/null", close: false },
                { label: "More Settings (Power TUI)...",
                  cmd: "kitty --class floating-term -e bash -c 'upower -i $(upower -e | grep -m1 BAT); echo; tuned-adm active 2>/dev/null || true; echo; read -n1 -rsp \"Press any key to close\"'",
                  close: true, accent: true }
            ];
        }
        if (pop.tab === "power") {
            return [
                { header: "SESSION & POWER" },
                { label: "Lock Screen",       cmd: "qs ipc call lock activate >/dev/null 2>&1 || loginctl lock-session", close: true },
                { label: "Start IdleScreen",  cmd: "idlescreen start",      close: true },
                { label: "Suspend",           cmd: "systemctl suspend",     close: true },
                { label: "Log Out",           cmd: "hyprctl dispatch exit", close: true },
                { label: "Restart",           cmd: "systemctl reboot",      close: true },
                { label: "Shut Down",         cmd: "systemctl poweroff",    close: true, accent: true }
            ];
        }
        return [];
    }

    Rectangle {
        id: box
        width: parent.width
        implicitHeight: col.implicitHeight + 20
        color: Theme.bg
        radius: Theme.radius
        border.width: 2
        border.color: pop.tab === "power" ? Theme.red : Theme.blue

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            Repeater {
                model: pop.rows

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        visible: parent.modelData.header !== undefined
                        text: parent.modelData.header || ""
                        color: pop.tab === "power" ? Theme.red : Theme.blue
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                        font.bold: true
                    }

                    Text {
                        visible: parent.modelData.info !== undefined
                        text: parent.modelData.info || ""
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }

                    Rectangle {
                        visible: parent.modelData.barValue !== undefined
                        Layout.fillWidth: true
                        height: 8
                        radius: Theme.radiusSm
                        color: Theme.bgAlt

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, parent.parent.modelData.barValue || 0))
                            height: parent.height
                            radius: Theme.radiusSm
                            color: Theme.blue
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.parent.modelData.isAudioBar === true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: e => {
                                if (pop.audioReady) pop.sink.audio.volume = Math.max(0, Math.min(1, e.x / width));
                            }
                        }
                    }

                    Rectangle {
                        visible: parent.modelData.label !== undefined
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Theme.radiusSm
                        color: btnMouse.containsMouse ? Theme.bgHover : (parent.modelData.accent ? Theme.bgAlt : "transparent")

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            text: parent.parent.modelData.label || ""
                            color: parent.parent.modelData.accent ? Theme.blue : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: parent.parent.modelData.accent === true
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const d = parent.parent.modelData;
                                if (d.action === "mute" && pop.audioReady) pop.sink.audio.muted = !pop.sink.audio.muted;
                                else if (d.action === "vol_up" && pop.audioReady) pop.sink.audio.volume = Math.min(1, pop.vol + 0.1);
                                else if (d.action === "vol_down" && pop.audioReady) pop.sink.audio.volume = Math.max(0, pop.vol - 0.1);
                                else if (d.cmd) {
                                    pop.runCmd(d.cmd, d.close === true);
                                    Status.refresh();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
