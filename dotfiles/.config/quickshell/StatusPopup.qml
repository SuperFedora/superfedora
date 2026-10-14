import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "panels"

// SuperDesk 16-Bit SNES Pause Menu: Full-Canvas Live AI Agent on [1] AI + 5 Hardware/System Cartridge Tabs.
PanelWindow {
    id: pop
    property var targetScreen: Quickshell.screens[0]
    readonly property var hyprMon: Hyprland.monitorFor(pop.targetScreen)
    readonly property bool isTargetMon: !Hyprland.focusedMonitor ? (pop.targetScreen === Quickshell.screens[0]) : (pop.hyprMon !== null && pop.hyprMon.id === Hyprland.focusedMonitor.id)
    readonly property string activeTab: Status.normalizeDeckTab(Status.superDeckSection)
    readonly property int fullW: Math.max(860, Math.min(1280, Math.round(pop.targetScreen.width * 0.68)))
    readonly property int fullH: Math.max(520, Math.min(720, Math.round(pop.targetScreen.height * 0.58)))
    property bool agentBarOpen: false
    property string confirmCmd: ""; property string confirmLabel: ""

    visible: Status.superDeckOpen && pop.isTargetMon; screen: pop.targetScreen; color: "transparent"
    WlrLayershell.namespace: "superfedora-superdeck"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (pop.visible && pop.activeTab !== "ai") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors.top: true; margins.top: Theme.barHeight + 6; exclusionMode: ExclusionMode.Ignore
    implicitWidth: pop.fullW
    implicitHeight: pop.activeTab === "ai" ? (pop.agentBarOpen ? 82 : 40) : pop.fullH

    readonly property var btAdapter: Bluetooth.defaultAdapter; readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    readonly property var tabs: [
        { id: "ai",        label: "[1] AI" },
        { id: "wifi",      label: "[2] WI-FI" },
        { id: "bluetooth", label: "[3] BLUETOOTH" },
        { id: "audio",     label: "[4] AUDIO & CAM" },
        { id: "system",    label: "[5] SYSTEM" },
        { id: "power",     label: "[6] POWER" }
    ]

    function focusActiveTab() {
        if (pop.activeTab === "system") catalogView.focusSearch();
        else if (pop.activeTab !== "ai") keyRoot.forceActiveFocus();
    }
    function selectTab(idx) {
        if (idx < 0 || idx >= pop.tabs.length) return;
        pop.confirmCmd = ""; pop.agentBarOpen = false;
        Status.superDeckPowerHighlight = (pop.tabs[idx].id === "power");
        Status.superDeckSection = pop.tabs[idx].id; Status.playSfx("click"); pop.focusActiveTab();
    }
    function stepTab(back) { const cur = pop.tabs.findIndex(t => t.id === pop.activeTab); pop.selectTab((Math.max(0, cur) + (back ? (pop.tabs.length - 1) : 1)) % pop.tabs.length); }
    function runCmd(cmd, closeAfter) { if (closeAfter) Status.superDeckOpen = false; Status.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", cmd]); Status.refresh(); }
    function askConfirm(label, cmd) { pop.confirmLabel = label; pop.confirmCmd = cmd; Status.playSfx("alert"); }
    onVisibleChanged: if (pop.visible) { pop.confirmCmd = ""; pop.agentBarOpen = false; pop.focusActiveTab(); }
    onActiveTabChanged: if (pop.visible) { pop.agentBarOpen = false; pop.focusActiveTab(); }

    Rectangle {
        id: box; anchors.fill: parent; color: Theme.bg; radius: Theme.radius; border.width: 2
        border.color: pop.activeTab === "power" ? Theme.red : Theme.blue
        Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }

        Item {
            id: keyRoot; anchors.fill: parent; focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { Status.superDeckOpen = false; event.accepted = true; }
                else if ((event.modifiers & (Qt.AltModifier | Qt.ControlModifier)) && event.key >= Qt.Key_1 && event.key <= Qt.Key_6) { pop.selectTab(event.key - Qt.Key_1); event.accepted = true; }
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { pop.stepTab(event.key === Qt.Key_Backtab || Boolean(event.modifiers & Qt.ShiftModifier)); event.accepted = true; }
            }
        }

        ColumnLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: pop.activeTab === "ai" ? 4 : 10 }
            spacing: 6

            // ---------------- 40px 16-Bit SNES Top Tab Bar ----------------
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 32; spacing: 6
                Text { text: "󰣛 SUPERDESK"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.rightMargin: 4 }
                Repeater {
                    model: pop.tabs
                    Rectangle {
                        required property var modelData; required property int index; readonly property bool isCur: pop.activeTab === modelData.id
                        Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm
                        border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border
                        color: isCur ? Theme.blue : (tMouse.containsMouse ? Theme.bgHover : Theme.bgAlt)
                        Text {
                            anchors.centerIn: parent
                            text: (parent.isCur || tMouse.containsMouse ? "▸ " : "") + parent.modelData.label
                            color: parent.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
                        }
                        MouseArea { id: tMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.selectTab(parent.index) }
                    }
                }
                Rectangle {
                    visible: pop.activeTab === "ai"
                    implicitWidth: agPillTxt.implicitWidth + 16; implicitHeight: 30; radius: Theme.radiusSm
                    color: agPillM.containsMouse ? Theme.blue : Theme.bgAlt; border.width: 2; border.color: Theme.cyan
                    Text {
                        id: agPillTxt; anchors.centerIn: parent
                        text: "[AGENT: " + Status.aiAgent.toUpperCase() + (pop.agentBarOpen ? " ▴]" : " ▾]")
                        color: agPillM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
                    }
                    MouseArea {
                        id: agPillM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => {
                            if (e.button === Qt.RightButton) pop.runCmd("~/.config/hypr/scripts/quake-ai.sh next-agent", false);
                            else { pop.agentBarOpen = !pop.agentBarOpen; Status.playSfx("click"); }
                        }
                    }
                }
                Rectangle {
                    implicitWidth: 64; implicitHeight: 30; radius: Theme.radiusSm; color: escM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 2; border.color: escM.containsMouse ? Theme.red : Theme.border
                    Text { anchors.centerIn: parent; text: "ESC [X]"; color: escM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    MouseArea { id: escM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.superDeckOpen = false }
                }
            }

            // Inline 16-Bit Destructive Confirmation Banner
            Rectangle {
                visible: pop.confirmCmd !== "" && pop.activeTab !== "ai"
                Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 2; border.color: Theme.red
                RowLayout {
                    anchors { fill: parent; margins: 6 } spacing: 8
                    Text { Layout.fillWidth: true; text: "▸ CONFIRM ACTION: " + pop.confirmLabel + "?"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; elide: Text.ElideRight }
                    Rectangle { implicitWidth: 96; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.red; Text { anchors.centerIn: parent; text: "[ CONFIRM ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const c = pop.confirmCmd; pop.confirmCmd = ""; pop.runCmd(c, true); } } }
                    Rectangle { implicitWidth: 84; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bgHover; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "[ CANCEL ]"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.confirmCmd = "" } }
                }
            }

            // ---------------- TAB 2: [2] WI-FI (16-Bit SNES Network Deck) ----------------
            ColumnLayout {
                visible: pop.activeTab === "wifi"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 58; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Status.netType === "wifi" ? Theme.green : Theme.blue
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 } spacing: 12
                        Text {
                            Layout.fillWidth: true
                            text: "▸ 󰤨  WI-FI: " + (Status.netType === "wifi" ? ((Status.ssid || "CONNECTED") + " (" + Status.signal + "%)") : Status.netType.toUpperCase())
                            color: Status.netType === "wifi" ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true; elide: Text.ElideRight
                        }
                        Rectangle {
                            implicitWidth: 196; implicitHeight: 34; radius: Theme.radiusSm
                            color: wfTog.containsMouse ? Theme.bgHover : Theme.bg; border.width: 2; border.color: Status.netType === "wifi" ? Theme.green : Theme.red
                            Text { anchors.centerIn: parent; text: Status.netType === "wifi" ? "[ WI-FI RADIO: ON ]" : "[ WI-FI RADIO: OFF ]"; color: Status.netType === "wifi" ? Theme.green : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                            MouseArea { id: wfTog; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd((Status.netType === "wifi" ? "nmcli radio wifi off" : "nmcli radio wifi on") + "; sleep 0.4", false) }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 } spacing: 6
                        Text { text: "NEARBY WIRELESS NETWORKS (CLICK TO CONNECT / DISCONNECT)"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                        Repeater {
                            model: Status.wifiList
                            Rectangle {
                                id: wfRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 36; radius: Theme.radiusSm
                                color: wfM.containsMouse ? Theme.bgHover : (modelData.active ? Theme.bg : "transparent")
                                border.width: modelData.active || wfM.containsMouse ? 1 : 0; border.color: modelData.active ? Theme.cyan : Theme.border
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                                    Text { Layout.fillWidth: true; text: (wfRow.modelData.active || wfM.containsMouse ? "▸ " : "  ") + (wfRow.modelData.active ? "[*] " : "[ ] ") + wfRow.modelData.ssid; color: wfRow.modelData.active ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: wfRow.modelData.active === true; elide: Text.ElideRight }
                                    Text { text: wfRow.modelData.active ? "[CONNECTED]" : "[READY]"; color: wfRow.modelData.active ? Theme.green : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                                    Text { text: wfRow.modelData.signal + "%"; color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }
                                MouseArea { id: wfM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const w = wfRow.modelData, s = w.ssid.replace(/'/g, "'\\''"); pop.runCmd(w.active ? ("nmcli connection down '" + s + "'") : ("nmcli device wifi connect '" + s + "'"), false); } }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 44; radius: Theme.radius; color: wlM.containsMouse ? Theme.blue : Theme.bgAlt; border.width: 2; border.color: Theme.cyan
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    Text { anchors.centerIn: parent; text: "▸ [ 󰤨 LAUNCH WI-FI TUI (wlctl) ]"; color: wlM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    MouseArea { id: wlM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e bash -c 'command -v wlctl >/dev/null && exec wlctl || exec nmtui'", true) }
                }
            }

            // ---------------- TAB 3: [3] BLUETOOTH (16-Bit SNES Bluetooth Deck) ----------------
            ColumnLayout {
                visible: pop.activeTab === "bluetooth"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 58; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: pop.btEnabled ? Theme.green : Theme.blue
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 } spacing: 12
                        Text { Layout.fillWidth: true; text: "▸ 󰂯  BLUETOOTH CONTROLLER // " + (pop.btEnabled ? "ONLINE" : "OFFLINE"); color: pop.btEnabled ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
                        Rectangle {
                            implicitWidth: 196; implicitHeight: 34; radius: Theme.radiusSm
                            color: btTog.containsMouse ? Theme.bgHover : Theme.bg; border.width: 2; border.color: pop.btEnabled ? Theme.green : Theme.red
                            Text { anchors.centerIn: parent; text: pop.btEnabled ? "[ BLUETOOTH: ON ]" : "[ BLUETOOTH: OFF ]"; color: pop.btEnabled ? Theme.green : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                            MouseArea { id: btTog; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd(pop.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", false) }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 } spacing: 6
                        Text { text: "PAIRED & CONNECTED BLUETOOTH PERIPHERALS"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                        Repeater {
                            model: Bluetooth.defaultAdapter ? Bluetooth.devices.values.filter(d => d.connected || d.paired).slice(0, 7) : []
                            Rectangle {
                                id: btRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm
                                color: btM.containsMouse ? Theme.bgHover : (modelData.connected ? Theme.bg : "transparent")
                                border.width: modelData.connected || btM.containsMouse ? 1 : 0; border.color: modelData.connected ? Theme.cyan : Theme.border
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                                    Text { Layout.fillWidth: true; text: (btRow.modelData.connected || btM.containsMouse ? "▸ " : "  ") + (btRow.modelData.connected ? "[*] " : "[ ] ") + (btRow.modelData.name || btRow.modelData.address); color: btRow.modelData.connected ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: btRow.modelData.connected; elide: Text.ElideRight }
                                    Text { text: btRow.modelData.connected ? "[CONNECTED]" : "[PAIRED]"; color: btRow.modelData.connected ? Theme.green : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                                }
                                MouseArea { id: btM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("bluetoothctl " + (btRow.modelData.connected ? "disconnect " : "connect ") + btRow.modelData.address, false) }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 44; radius: Theme.radius; color: btTui.containsMouse ? Theme.blue : Theme.bgAlt; border.width: 2; border.color: Theme.cyan
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    Text { anchors.centerIn: parent; text: "▸ [ 󰂯 LAUNCH BLUETOOTH TUI (bluetui) ]"; color: btTui.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    MouseArea { id: btTui; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e bluetui", true) }
                }
            }

            // ---------------- TAB 1 Inline Agent Bar + TAB 4: [4] AUDIO & CAM ----------------
            AiTab {
                id: aiAndAudioView
                visible: (pop.activeTab === "ai" && pop.agentBarOpen) || pop.activeTab === "audio"
                activeTab: pop.activeTab; agentBarOpen: pop.agentBarOpen
                onExecuteCommand: (cmd, closeAfter) => pop.runCmd(cmd, closeAfter)
                onAgentSelected: pop.agentBarOpen = false
            }

            // ---------------- TABS 5 & 6: [5] SYSTEM & [6] POWER ----------------
            LauncherMenu {
                id: catalogView; visible: pop.activeTab === "system" || pop.activeTab === "power"
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
