import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "panels"

// Unified "SuperDesk" — Quake Drop-Down AI Console + Zero-Trust & First-Principles Workstation Control Center.
PanelWindow {
    id: pop
    property var targetScreen: Quickshell.screens[0]
    readonly property var hyprMon: Hyprland.monitorFor(pop.targetScreen)
    readonly property bool isTargetMon: !Hyprland.focusedMonitor ? (pop.targetScreen === Quickshell.screens[0]) : (pop.hyprMon !== null && pop.hyprMon.id === Hyprland.focusedMonitor.id)
    readonly property string activeTab: Status.normalizeDeckTab(Status.superDeckSection)
    property string confirmCmd: ""; property string confirmLabel: ""

    visible: Status.superDeckOpen && pop.isTargetMon; screen: pop.targetScreen; color: "transparent"
    WlrLayershell.namespace: "superfedora-superdeck"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: pop.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors.top: true; margins.top: Theme.barHeight + 6; exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.max(860, Math.min(1280, Math.round(pop.targetScreen.width * 0.68)))
    implicitHeight: Math.max(520, Math.min(720, Math.round(pop.targetScreen.height * 0.58)))

    readonly property var sink: Pipewire.defaultAudioSink; readonly property bool audioReady: sink !== null && sink.audio !== null
    readonly property real vol: audioReady ? sink.audio.volume : Status.spkVol; readonly property bool muted: audioReady ? sink.audio.muted : Status.spkMuted
    readonly property var source: Pipewire.defaultAudioSource; readonly property bool micReady: source !== null && source.audio !== null
    readonly property real micVol: micReady ? source.audio.volume : Status.micVol; readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted
    readonly property var btAdapter: Bluetooth.defaultAdapter; readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    readonly property var tabs: [
        { id: "ai", label: "[1] 󰚩 AI AGENT" }, { id: "zerotrust", label: "[2] 󰒃 ZERO TRUST & I/O" },
        { id: "state", label: "[3] 󰋊 STATE & SNAPSHOTS" }, { id: "software", label: "[4] 󰏖 SOFTWARE & FORGE" },
        { id: "surface", label: "[5] 󰏘 SURFACE & FEEL" }
    ]

    function focusActiveTab() { if (pop.activeTab === "ai") aiTabView.focusPrompt(); else if (pop.activeTab === "software") catalogView.focusSearch(); else keyRoot.forceActiveFocus(); }
    function selectTab(idx) {
        if (idx < 0 || idx >= pop.tabs.length) return;
        pop.confirmCmd = ""; Status.superDeckPowerHighlight = false; Status.superDeckSection = pop.tabs[idx].id; Status.playSfx("click"); pop.focusActiveTab();
    }
    function stepTab(back) { const cur = pop.tabs.findIndex(t => t.id === pop.activeTab); pop.selectTab((Math.max(0, cur) + (back ? (pop.tabs.length - 1) : 1)) % pop.tabs.length); }
    function runCmd(cmd, closeAfter) { if (closeAfter) Status.superDeckOpen = false; Status.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", cmd]); Status.refresh(); }
    function askConfirm(label, cmd) { pop.confirmLabel = label; pop.confirmCmd = cmd; Status.playSfx("alert"); }
    onVisibleChanged: if (pop.visible) { pop.confirmCmd = ""; pop.focusActiveTab(); }
    onActiveTabChanged: if (pop.visible) pop.focusActiveTab()

    Rectangle {
        id: box; anchors.fill: parent; color: Theme.bg; radius: Theme.radius; border.width: 2
        border.color: (Status.superDeckPowerHighlight && pop.activeTab === "zerotrust") ? Theme.red : Theme.blue

        Item {
            id: keyRoot; anchors.fill: parent; focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { Status.superDeckOpen = false; event.accepted = true; }
                else if ((event.modifiers & (Qt.AltModifier | Qt.ControlModifier)) && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) { pop.selectTab(event.key - Qt.Key_1); event.accepted = true; }
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { pop.stepTab(event.key === Qt.Key_Backtab || Boolean(event.modifiers & Qt.ShiftModifier)); event.accepted = true; }
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 12 } spacing: 8
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: "󰣛 SUPERDESK"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.rightMargin: 4 }
                Repeater {
                    model: pop.tabs
                    Rectangle {
                        required property var modelData; required property int index; readonly property bool isCur: pop.activeTab === modelData.id
                        Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm; border.width: isCur ? 0 : 1; border.color: Theme.border; color: isCur ? Theme.blue : (tMouse.containsMouse ? Theme.bgHover : Theme.bgAlt)
                        Text { anchors.centerIn: parent; text: parent.modelData.label; color: parent.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: parent.isCur }
                        MouseArea { id: tMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.selectTab(parent.index) }
                    }
                }
                Rectangle {
                    implicitWidth: 68; implicitHeight: 32; radius: Theme.radiusSm; color: escM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: Theme.border
                    Text { anchors.centerIn: parent; text: "Esc [X]"; color: escM.containsMouse ? Theme.bg : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    MouseArea { id: escM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.superDeckOpen = false }
                }
            }
            Rectangle {
                visible: pop.confirmCmd !== ""; Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 2; border.color: Theme.red
                RowLayout {
                    anchors { fill: parent; margins: 6 } spacing: 8
                    Text { Layout.fillWidth: true; text: "Confirm destructive action: " + pop.confirmLabel + "?"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; elide: Text.ElideRight }
                    Rectangle { implicitWidth: 74; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.red; Text { anchors.centerIn: parent; text: "Confirm"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const c = pop.confirmCmd; pop.confirmCmd = ""; pop.runCmd(c, true); } } }
                    Rectangle { implicitWidth: 64; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bgHover; Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.confirmCmd = "" } }
                }
            }
            AiTab { id: aiTabView; visible: pop.activeTab === "ai"; active: pop.visible && pop.activeTab === "ai"; onSwitchTabRequested: idx => pop.selectTab(idx); onCycleTabRequested: back => pop.stepTab(back); onCloseRequested: Status.superDeckOpen = false }

            // TAB 2: [2] ZERO TRUST & I/O (Layer 0: Physical Sensor Kill-Switches, Radio Gates & Session Perimeter)
            RowLayout {
                visible: pop.activeTab === "zerotrust"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: ioCol.implicitHeight + 18; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                        ColumnLayout {
                            id: ioCol; anchors { fill: parent; margins: 9 } spacing: 7
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: "LAYER 0 // PHYSICAL SENSOR GATES & I/O"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.fillWidth: true }
                                Rectangle { implicitWidth: wmTxt.implicitWidth + 12; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.blue; Text { id: wmTxt; anchors.centerIn: parent; text: "󰕾 Audio Mixer (wiremix)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wiremix", true) } }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Repeater {
                                    model: [
                                        { id: "cam", label: Status.webcamEnabled ? "󰄀 Camera: ON (Live)" : "󰗟 Camera: OFF (ACL)", col: Status.webcamEnabled ? Theme.green : Theme.red },
                                        { id: "mic", label: pop.micMuted ? "󰍭 Mic: Muted" : ("󰍬 Mic: Live (" + Math.round(pop.micVol * 100) + "%)"), col: pop.micMuted ? Theme.red : Theme.green },
                                        { id: "spk", label: pop.muted ? "󰝟 Spk: Muted" : ("󰕾 Spk: Live (" + Math.round(pop.vol * 100) + "%)"), col: pop.muted ? Theme.red : Theme.cyan }
                                    ]
                                    Rectangle {
                                        required property var modelData; Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: modelData.col
                                        Text { anchors.centerIn: parent; text: parent.modelData.label; color: parent.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const id = parent.modelData.id;
                                                if (id === "cam") Status.toggleWebcam();
                                                else if (id === "mic") { const m = !pop.micMuted; if (pop.micReady) pop.source.audio.muted = m; Status.toggleMicMute(m); }
                                                else { const m = !pop.muted; if (pop.audioReady) pop.sink.audio.muted = m; Status.toggleSpeakerMute(m); }
                                            }
                                        }
                                    }
                                }
                            }
                            Repeater {
                                model: [
                                    { id: "spk", icon: pop.muted ? "󰝟" : "󰕾", label: "Speakers Vol", val: pop.vol, muted: pop.muted, col: Theme.blue },
                                    { id: "mic", icon: pop.micMuted ? "󰍭" : "󰍬", label: "Mic Input Gain", val: pop.micVol, muted: pop.micMuted, col: Theme.green },
                                    { id: "bri", icon: "󰃠", label: "Display Lumen", val: Status.brightness, muted: false, col: Theme.yellow }
                                ]
                                RowLayout {
                                    id: sRow; required property var modelData; Layout.fillWidth: true; spacing: 8
                                    Text { text: sRow.modelData.icon + " " + sRow.modelData.label; color: sRow.modelData.muted ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.preferredWidth: 118 }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 12; radius: Theme.radiusSm; color: Theme.bg
                                        Rectangle { width: parent.width * Math.max(0, Math.min(1, sRow.modelData.val)); height: parent.height; radius: Theme.radiusSm; color: sRow.modelData.muted ? Theme.muted : sRow.modelData.col }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            function applyVal(mx) {
                                                const v = Math.max(0, Math.min(1, mx / width));
                                                if (sRow.modelData.id === "spk") { if (pop.audioReady) pop.sink.audio.volume = v; Status.setSpeakerVolume(v); }
                                                else if (sRow.modelData.id === "mic") { if (pop.micReady) pop.source.audio.volume = v; Status.setMicVolume(v); } else Status.setBrightness(v);
                                            }
                                            onPressed: e => applyVal(e.x)
                                            onPositionChanged: e => { if (pressed) applyVal(e.x); }
                                        }
                                    }
                                    Text { text: sRow.modelData.muted ? "MUTE" : (Math.round(sRow.modelData.val * 100) + "%"); color: sRow.modelData.muted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: Status.superDeckPowerHighlight ? 2 : 1; border.color: Status.superDeckPowerHighlight ? Theme.red : Theme.border
                        ColumnLayout {
                            anchors { fill: parent; margins: 9 } spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "SESSION SECURITY & POWER PERIMETER"; color: Status.superDeckPowerHighlight ? Theme.red : Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.fillWidth: true }
                                Text { visible: pop.batPresent; text: (pop.batCharging ? "󰂄 AC Charging " : "󰁹 Battery ") + pop.batPct + "%"; color: pop.batCharging ? Theme.green : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                            }
                            GridLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 6; columnSpacing: 6
                                Repeater {
                                    model: [
                                        { label: "󰌾 Lock Screen (SUPER+Esc)", cmd: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session", close: true, col: Theme.cyan },
                                        { label: Status.idleEnabled ? "󰒲 Caffeine: Auto-Idle" : "󰅶 Caffeine: Stay Awake", cmd: "~/.config/hypr/scripts/toggle-idle.sh", close: false, col: Status.idleEnabled ? Theme.fg : Theme.yellow },
                                        { label: "󰒲 Start 16-Bit IdleScreen", cmd: "idlescreen start", close: true, col: Theme.fg },
                                        { label: "󰤄 Suspend Workstation", cmd: "systemctl suspend", confirm: true, col: Theme.yellow },
                                        { label: "󰍃 Log Out of Session", cmd: "hyprctl dispatch exit", confirm: true, col: Theme.orange },
                                        { label: "󰜉 Reboot Workstation", cmd: "systemctl reboot", confirm: true, col: Theme.orange },
                                        { label: "󰐥 Shut Down Workstation", cmd: "systemctl poweroff", confirm: true, col: Theme.red }
                                    ]
                                    Rectangle {
                                        required property var modelData; Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm; color: pM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: modelData.confirm ? Theme.red : Theme.border
                                        Text { anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8 } text: parent.modelData.label; color: parent.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                                        MouseArea { id: pM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const d = parent.modelData; if (d.confirm) pop.askConfirm(d.label, d.cmd); else pop.runCmd(d.cmd, d.close); } }
                                    }
                                }
                            }
                        }
                    }
                }

                // Right Column: Radio & Network Perimeter Gates (Wi-Fi & Bluetooth)
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        anchors { fill: parent; margins: 9 } spacing: 5
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "WI-FI RADIO (" + (Status.netType === "wifi" ? (Status.ssid || "ON") : Status.netType.toUpperCase()) + ")"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.fillWidth: true }
                            Rectangle { implicitWidth: 74; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Status.netType !== "none" ? Theme.green : Theme.red; Text { anchors.centerIn: parent; text: Status.netType === "wifi" ? "Radio: ON" : "Radio: OFF"; color: Status.netType === "wifi" ? Theme.green : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd((Status.netType === "wifi" ? "nmcli radio wifi off" : "nmcli radio wifi on") + "; sleep 0.4", false) } }
                            Rectangle { implicitWidth: 74; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.blue; Text { anchors.centerIn: parent; text: "󰤨 wlctl TUI"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wlctl", true) } }
                        }
                        Repeater {
                            model: Status.wifiList
                            Rectangle {
                                id: wfRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 24; radius: Theme.radiusSm; color: wfM.containsMouse ? Theme.bgHover : (modelData.active ? Theme.bg : "transparent")
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    Text { Layout.fillWidth: true; text: (wfRow.modelData.active ? "[*] " : "[ ] ") + wfRow.modelData.ssid; color: wfRow.modelData.active ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: wfRow.modelData.active === true; elide: Text.ElideRight }
                                    Text { text: wfRow.modelData.signal + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                                }
                                MouseArea { id: wfM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const w = wfRow.modelData, s = w.ssid.replace(/'/g, "'\\''"); pop.runCmd(w.active ? ("nmcli connection down '" + s + "'") : ("nmcli device wifi connect '" + s + "'"), false); } }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 2; Layout.bottomMargin: 2 }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "BLUETOOTH PERIMETER"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.fillWidth: true }
                            Rectangle { implicitWidth: 74; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: pop.btEnabled ? Theme.green : Theme.red; Text { anchors.centerIn: parent; text: pop.btEnabled ? "BT: ON" : "BT: OFF"; color: pop.btEnabled ? Theme.green : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd(pop.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", false) } }
                            Rectangle { implicitWidth: 82; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.blue; Text { anchors.centerIn: parent; text: "󰂯 bluetui TUI"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e bluetui", true) } }
                        }
                        Repeater {
                            model: Bluetooth.defaultAdapter ? Bluetooth.devices.values.filter(d => d.connected || d.paired).slice(0, 5) : []
                            Rectangle {
                                id: btRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 24; radius: Theme.radiusSm; color: btM.containsMouse ? Theme.bgHover : (modelData.connected ? Theme.bg : "transparent")
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    Text { Layout.fillWidth: true; text: (btRow.modelData.connected ? "[*] " : "[ ] ") + (btRow.modelData.name || btRow.modelData.address); color: btRow.modelData.connected ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight }
                                    Text { text: btRow.modelData.connected ? "CONNECTED" : "PAIRED"; color: btRow.modelData.connected ? Theme.green : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                                }
                                MouseArea { id: btM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("bluetoothctl " + (btRow.modelData.connected ? "disconnect " : "connect ") + btRow.modelData.address, false) }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            LauncherMenu {
                id: catalogView; visible: pop.activeTab === "state" || pop.activeTab === "software" || pop.activeTab === "surface"
                activeSection: pop.activeTab; batPresent: pop.batPresent; batPct: pop.batPct; batCharging: pop.batCharging
                onExecuteCommand: (cmd, closeAfter) => pop.runCmd(cmd, closeAfter)
                onRequestConfirm: (label, cmd) => pop.askConfirm(label, cmd)
                onSwitchTabRequested: idx => pop.selectTab(idx)
                onCycleTabRequested: back => pop.stepTab(back)
                onCloseRequested: Status.superDeckOpen = false
            }
        }
    }
}
