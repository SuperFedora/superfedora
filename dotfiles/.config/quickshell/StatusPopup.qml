import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "panels"

// SuperDesk 16-Bit Quick-Action Console: Uniform size & animation across [1] AI -> [2] WI-FI -> [3] BT -> [4] AUDIO -> [5] DISPLAY -> [6] THEME -> [7] DOCK -> [8] FORGE -> [9] STATE -> [0] POWER.
PanelWindow {
    id: pop
    property var targetScreen: Quickshell.screens[0]
    readonly property var hyprMon: Hyprland.monitorFor(pop.targetScreen)
    readonly property bool isTargetMon: !Hyprland.focusedMonitor ? (pop.targetScreen === Quickshell.screens[0]) : (pop.hyprMon !== null && pop.hyprMon.id === Hyprland.focusedMonitor.id)
    readonly property string activeTab: Status.normalizeDeckTab(Status.superDeckSection)
    readonly property int fullW: Math.max(960, Math.min(1080, Math.round(pop.targetScreen.width * 0.62)))
    readonly property int fullH: Math.max(410, Math.min(460, Math.round(pop.targetScreen.height * 0.43)))
    property string confirmCmd: ""; property string confirmLabel: ""
    property int wifiIdx: 0; property string wifiPassSsid: ""; property int btIdx: 0

    visible: Status.superDeckOpen && pop.isTargetMon; screen: pop.targetScreen; color: "transparent"
    WlrLayershell.namespace: "superfedora-superdeck"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: pop.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors.top: true; margins.top: Theme.barHeight + 6; exclusionMode: ExclusionMode.Ignore
    implicitWidth: pop.fullW; implicitHeight: pop.fullH

    readonly property var btAdapter: Bluetooth.defaultAdapter; readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var btList: btAdapter ? Bluetooth.devices.values.slice(0, 7) : []
    readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    readonly property var tabs: [
        { id: "ai", label: "[1] AI" }, { id: "wifi", label: "[2] WI-FI" }, { id: "bluetooth", label: "[3] BT" },
        { id: "audio", label: "[4] AUDIO" }, { id: "display", label: "[5] DISPLAY" }, { id: "theme", label: "[6] THEME" },
        { id: "shell", label: "[7] DOCK" }, { id: "forge", label: "[8] FORGE" }, { id: "state", label: "[9] STATE" },
        { id: "power", label: "[0] POWER" }
    ]

    NumberAnimation { id: fadeAnim; target: box; property: "opacity"; from: 0.82; to: 1.0; duration: 60; easing.type: Easing.OutQuad }

    function focusActiveTab() { if (pop.activeTab === "ai") aiAndAudioView.focusInput(); else if (pop.activeTab === "wifi" && pop.wifiPassSsid !== "") wifiPassInput.forceActiveFocus(); else if (pop.activeTab === "forge") catalogView.focusSearch(); else box.forceActiveFocus(); }
    function selectTab(idx) { if (idx < 0 || idx >= pop.tabs.length) return; pop.confirmCmd = ""; pop.wifiPassSsid = ""; Status.superDeckPowerHighlight = (pop.tabs[idx].id === "power"); Status.superDeckSection = pop.tabs[idx].id; Status.playSfx("click"); pop.focusActiveTab(); }
    function stepTab(back) { const cur = pop.tabs.findIndex(t => t.id === pop.activeTab); pop.selectTab((Math.max(0, cur) + (back ? (pop.tabs.length - 1) : 1)) % pop.tabs.length); }
    function runCmd(cmd, closeAfter) { if (closeAfter) Status.superDeckOpen = false; Status.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", cmd]); Status.refresh(); }
    function askConfirm(label, cmd) { pop.confirmLabel = label; pop.confirmCmd = cmd; Status.playSfx("alert"); }
    function escSh(s) { return String(s || "").replace(/'/g, "'\\''"); }
    function wifiTrigger(w) { if (!w) return; const s = pop.escSh(w.ssid); if (w.active) pop.runCmd("nmcli connection down '" + s + "'; sleep 0.5 && qs ipc call status refresh", false); else if (w.saved || w.open) pop.runCmd("nmcli device wifi connect '" + s + "'; sleep 0.8 && qs ipc call status refresh", false); else { pop.wifiPassSsid = w.ssid; wifiPassInput.text = ""; wifiPassInput.forceActiveFocus(); Status.playSfx("click"); } }
    function submitWifiPass() { if (!pop.wifiPassSsid) return; const s = pop.escSh(pop.wifiPassSsid), p = pop.escSh(wifiPassInput.text); pop.wifiPassSsid = ""; wifiPassInput.text = ""; box.forceActiveFocus(); pop.runCmd("nmcli device wifi connect '" + s + "' password '" + p + "'; sleep 0.9 && qs ipc call status refresh", false); }
    function btTrigger(d) { if (!d) return; const m = d.address; pop.runCmd(d.connected ? ("bluetoothctl disconnect " + m) : (d.paired ? ("bluetoothctl connect " + m) : ("bluetoothctl pair " + m + " && bluetoothctl trust " + m + " && bluetoothctl connect " + m)), false); }

    onVisibleChanged: if (pop.visible) { pop.confirmCmd = ""; pop.wifiPassSsid = ""; fadeAnim.restart(); pop.focusActiveTab(); }
    onActiveTabChanged: if (pop.visible) { pop.confirmCmd = ""; pop.wifiPassSsid = ""; fadeAnim.restart(); pop.focusActiveTab(); }

    Rectangle {
        id: box; anchors.fill: parent; color: Theme.bg; radius: Theme.radius; border.width: 2; focus: true
        border.color: pop.activeTab === "power" ? Theme.red : Theme.blue
        Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (pop.wifiPassSsid !== "") { pop.wifiPassSsid = ""; box.forceActiveFocus(); } else Status.superDeckOpen = false;
                event.accepted = true;
            } else if (((event.modifiers & (Qt.MetaModifier | Qt.AltModifier | Qt.ControlModifier)) || !wifiPassInput.activeFocus) && ((event.key >= Qt.Key_1 && event.key <= Qt.Key_9) || event.key === Qt.Key_0)) {
                pop.selectTab(event.key === Qt.Key_0 ? 9 : (event.key - Qt.Key_1)); event.accepted = true;
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                pop.stepTab(event.key === Qt.Key_Backtab || Boolean(event.modifiers & Qt.ShiftModifier)); event.accepted = true;
            } else if (pop.activeTab === "wifi" && !wifiPassInput.activeFocus) {
                const n = Status.wifiList.length;
                if ((event.key === Qt.Key_Down || event.key === Qt.Key_J) && n > 0) { pop.wifiIdx = (pop.wifiIdx + 1) % n; event.accepted = true; }
                else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K) && n > 0) { pop.wifiIdx = (pop.wifiIdx + n - 1) % n; event.accepted = true; }
                else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && n > 0) { pop.wifiTrigger(Status.wifiList[Math.min(pop.wifiIdx, n - 1)]); event.accepted = true; }
                else if (event.key === Qt.Key_S) { pop.runCmd("nmcli device wifi rescan; sleep 1 && qs ipc call status refresh", false); event.accepted = true; }
                else if (event.key === Qt.Key_D && n > 0) { const w = Status.wifiList[Math.min(pop.wifiIdx, n - 1)]; if (w) pop.runCmd("nmcli connection delete '" + pop.escSh(w.ssid) + "'; sleep 0.5 && qs ipc call status refresh", false); event.accepted = true; }
            } else if (pop.activeTab === "bluetooth") {
                const n = pop.btList.length;
                if ((event.key === Qt.Key_Down || event.key === Qt.Key_J) && n > 0) { pop.btIdx = (pop.btIdx + 1) % n; event.accepted = true; }
                else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K) && n > 0) { pop.btIdx = (pop.btIdx + n - 1) % n; event.accepted = true; }
                else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && n > 0) { pop.btTrigger(pop.btList[Math.min(pop.btIdx, n - 1)]); event.accepted = true; }
                else if (event.key === Qt.Key_S) { pop.runCmd("bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &", false); event.accepted = true; }
                else if (event.key === Qt.Key_D && n > 0) { const d = pop.btList[Math.min(pop.btIdx, n - 1)]; if (d) pop.runCmd("bluetoothctl remove " + d.address, false); event.accepted = true; }
            }
        }

        ColumnLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 6; bottomMargin: 10 }
            spacing: 8

            // ---------------- 16-Bit SNES Top Tab Bar (1 2 3 4 5 6 7 8 9 0 + SETTINGS + ESC) ----------------
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 32; spacing: 4
                Text { text: "󰣛"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true; Layout.rightMargin: 2 }
                Repeater {
                    model: pop.tabs
                    Rectangle {
                        required property var modelData; required property int index; readonly property bool isCur: pop.activeTab === modelData.id
                        Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm; border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border
                        color: isCur ? Theme.blue : (tMouse.containsMouse ? Theme.bgHover : Theme.bgAlt)
                        Text { anchors.centerIn: parent; text: (parent.isCur ? "▸" : "") + parent.modelData.label; color: parent.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                        MouseArea { id: tMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.selectTab(parent.index) }
                    }
                }
                Rectangle {
                    implicitWidth: 96; implicitHeight: 30; radius: Theme.radiusSm; color: setM.containsMouse ? Theme.cyan : Theme.bgAlt; border.width: 2; border.color: Theme.cyan
                    Text { anchors.centerIn: parent; text: "[ 󰒓 SETTINGS ]"; color: setM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    MouseArea { id: setM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.openSettings(pop.activeTab) }
                }
                Rectangle {
                    implicitWidth: 50; implicitHeight: 30; radius: Theme.radiusSm; color: escM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 2; border.color: escM.containsMouse ? Theme.red : Theme.border
                    Text { anchors.centerIn: parent; text: "[ESC]"; color: escM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    MouseArea { id: escM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.superDeckOpen = false }
                }
            }

            // Inline 16-Bit Destructive Confirmation Banner
            Rectangle {
                visible: pop.confirmCmd !== ""
                Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 2; border.color: Theme.red
                RowLayout {
                    anchors { fill: parent; margins: 6 } spacing: 8
                    Text { Layout.fillWidth: true; text: "▸ CONFIRM ACTION: " + pop.confirmLabel + "?"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; elide: Text.ElideRight }
                    Rectangle { implicitWidth: 96; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.red; Text { anchors.centerIn: parent; text: "[ CONFIRM ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const c = pop.confirmCmd; pop.confirmCmd = ""; pop.runCmd(c, true); } } }
                    Rectangle { implicitWidth: 84; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bgHover; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "[ CANCEL ]"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.confirmCmd = "" } }
                }
            }

            // ---------------- TAB 2: [2] WI-FI (Quick Wi-Fi Actions) ----------------
            ColumnLayout {
                visible: pop.activeTab === "wifi"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 48; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Status.wifiEnabled ? Theme.green : Theme.blue
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                        Text { Layout.fillWidth: true; text: "▸ QUICK WI-FI  —  " + (!Status.wifiEnabled ? "RADIO OFF" : (Status.netType === "wifi" && Status.ssid ? ("CONNECTED: " + Status.ssid) : "DISCONNECTED")); color: Status.wifiEnabled ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; elide: Text.ElideRight }
                        Rectangle { implicitWidth: 92; implicitHeight: 30; radius: Theme.radiusSm; color: wfScn.containsMouse ? Theme.blue : Theme.bg; border.width: 2; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ SCAN ]"; color: wfScn.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: wfScn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("nmcli device wifi rescan; sleep 1 && qs ipc call status refresh", false) } }
                        Rectangle { implicitWidth: 140; implicitHeight: 30; radius: Theme.radiusSm; color: wfTog.containsMouse ? Theme.bgHover : Theme.bg; border.width: 2; border.color: Status.wifiEnabled ? Theme.green : Theme.red; Text { anchors.centerIn: parent; text: Status.wifiEnabled ? "[ WI-FI: ON ]" : "[ WI-FI: OFF ]"; color: Status.wifiEnabled ? Theme.green : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: wfTog; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleWifiRadio() } }
                    }
                }
                Rectangle {
                    visible: pop.wifiPassSsid !== ""; Layout.fillWidth: true; implicitHeight: 42; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 2; border.color: Theme.cyan
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 8
                        Text { text: "PASSWORD FOR " + pop.wifiPassSsid + ":"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.cyan
                            TextInput { id: wifiPassInput; anchors { fill: parent; leftMargin: 8; rightMargin: 8 } verticalAlignment: TextInput.AlignVCenter; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; echoMode: TextInput.Password; clip: true; Keys.onReturnPressed: pop.submitWifiPass(); Keys.onEscapePressed: { pop.wifiPassSsid = ""; box.forceActiveFocus(); } }
                        }
                        Rectangle { implicitWidth: 102; implicitHeight: 28; radius: Theme.radiusSm; color: Theme.green; Text { anchors.centerIn: parent; text: "[ CONNECT ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.submitWifiPass() } }
                        Rectangle { implicitWidth: 88; implicitHeight: 28; radius: Theme.radiusSm; color: Theme.bgHover; border.width: 1; border.color: Theme.border; Text { anchors.centerIn: parent; text: "[ CANCEL ]"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { pop.wifiPassSsid = ""; box.forceActiveFocus(); } } }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 } spacing: 4
                        Repeater {
                            model: Status.wifiList.slice(0, 7)
                            Rectangle {
                                id: wfRow; required property var modelData; required property int index; readonly property bool isSel: index === pop.wifiIdx || wfM.containsMouse || wfFgM.containsMouse
                                Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: isSel ? Theme.bgHover : (modelData.active ? Theme.bg : "transparent"); border.width: modelData.active || isSel ? 1 : 0; border.color: modelData.active ? Theme.cyan : Theme.border
                                MouseArea { id: wfM; anchors.fill: parent; z: 0; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: pop.wifiIdx = wfRow.index; onClicked: { pop.wifiIdx = wfRow.index; pop.wifiTrigger(wfRow.modelData); } }
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8; z: 1
                                    Text { Layout.fillWidth: true; text: (wfRow.isSel ? "▸ " : "  ") + wfRow.modelData.ssid; color: wfRow.modelData.active ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: wfRow.modelData.active || wfRow.isSel; elide: Text.ElideRight }
                                    Text { text: "[" + (wfRow.modelData.security || "WPA") + "]"; color: wfRow.modelData.open ? Theme.yellow : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                                    Text { text: (wfRow.modelData.signal >= 75 ? "▂▄▆█ " : wfRow.modelData.signal >= 50 ? "▂▄▆░ " : wfRow.modelData.signal >= 25 ? "▂▄░░ " : "▂░░░ ") + wfRow.modelData.signal + "%"; color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.preferredWidth: 82; horizontalAlignment: Text.AlignRight }
                                    Rectangle { implicitWidth: wfActTxt.implicitWidth + 14; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: wfRow.modelData.active ? Theme.green : (wfRow.modelData.saved ? Theme.cyan : Theme.blue); Text { id: wfActTxt; anchors.centerIn: parent; text: wfRow.modelData.active ? "[ CONNECTED ]" : (wfRow.modelData.saved ? "[ SAVED — CONNECT ]" : "[ CONNECT ]"); color: wfRow.modelData.active ? Theme.green : (wfRow.modelData.saved ? Theme.cyan : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                                    Rectangle { visible: wfRow.modelData.active || wfRow.modelData.saved; implicitWidth: 78; implicitHeight: 24; radius: Theme.radiusSm; color: wfFgM.containsMouse ? Theme.red : Theme.bg; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ FORGET ]"; color: wfFgM.containsMouse ? Theme.bg : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: wfFgM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: pop.wifiIdx = wfRow.index; onClicked: pop.runCmd("nmcli connection delete '" + pop.escSh(wfRow.modelData.ssid) + "'; sleep 0.5 && qs ipc call status refresh", false) } }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // ---------------- TAB 3: [3] BLUETOOTH (Quick Bluetooth Actions) ----------------
            ColumnLayout {
                visible: pop.activeTab === "bluetooth"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 48; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: pop.btEnabled ? Theme.green : Theme.blue
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                        Text { Layout.fillWidth: true; text: "▸ QUICK BLUETOOTH"; color: pop.btEnabled ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                        Rectangle { implicitWidth: 132; implicitHeight: 30; radius: Theme.radiusSm; color: btScn.containsMouse ? Theme.blue : Theme.bg; border.width: 2; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ SCAN / PAIR ]"; color: btScn.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: btScn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd("bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &", false) } }
                        Rectangle { implicitWidth: 140; implicitHeight: 30; radius: Theme.radiusSm; color: btTog.containsMouse ? Theme.bgHover : Theme.bg; border.width: 2; border.color: pop.btEnabled ? Theme.green : Theme.red; Text { anchors.centerIn: parent; text: pop.btEnabled ? "[ BT: ON ]" : "[ BT: OFF ]"; color: pop.btEnabled ? Theme.green : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: btTog; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.runCmd(pop.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", false) } }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 } spacing: 4
                        Repeater {
                            model: pop.btList
                            Rectangle {
                                id: btRow; required property var modelData; required property int index; readonly property bool isSel: index === pop.btIdx || btM.containsMouse || btFgM.containsMouse
                                Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: isSel ? Theme.bgHover : (modelData.connected ? Theme.bg : "transparent"); border.width: modelData.connected || isSel ? 1 : 0; border.color: modelData.connected ? Theme.cyan : Theme.border
                                MouseArea { id: btM; anchors.fill: parent; z: 0; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: pop.btIdx = btRow.index; onClicked: { pop.btIdx = btRow.index; pop.btTrigger(btRow.modelData); } }
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8; z: 1
                                    Text { Layout.fillWidth: true; text: (btRow.isSel ? "▸ " : "  ") + (btRow.modelData.name || "Unknown") + "  [" + btRow.modelData.address + "]"; color: btRow.modelData.connected ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: btRow.modelData.connected || btRow.isSel; elide: Text.ElideRight }
                                    Text { text: btRow.modelData.connected ? "[ CONNECTED ]" : (btRow.modelData.paired ? "[ PAIRED ]" : "[ DISCOVERED ]"); color: btRow.modelData.connected ? Theme.green : (btRow.modelData.paired ? Theme.cyan : Theme.yellow); font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                                    Rectangle { visible: btRow.modelData.paired || btRow.modelData.connected; implicitWidth: 78; implicitHeight: 24; radius: Theme.radiusSm; color: btFgM.containsMouse ? Theme.red : Theme.bg; border.width: 1; border.color: Theme.red; Text { anchors.centerIn: parent; text: "[ FORGET ]"; color: btFgM.containsMouse ? Theme.bg : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: btFgM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: pop.btIdx = btRow.index; onClicked: pop.runCmd("bluetoothctl remove " + btRow.modelData.address, false) } }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // ---------------- TAB 1 [1] AI + TAB 4 [4] AUDIO + TAB 5 [5] DISPLAY ----------------
            AiTab {
                id: aiAndAudioView; visible: pop.activeTab === "ai" || pop.activeTab === "audio" || pop.activeTab === "display"
                activeTab: pop.activeTab
                onExecuteCommand: (cmd, closeAfter) => pop.runCmd(cmd, closeAfter)
                onSwitchTabRequested: idx => pop.selectTab(idx)
                onCycleTabRequested: back => pop.stepTab(back)
                onCloseRequested: Status.superDeckOpen = false
            }

            // ---------------- TABS 6..0: [6] THEME, [7] DOCK, [8] FORGE, [9] STATE, [0] POWER ----------------
            LauncherMenu {
                id: catalogView; visible: pop.activeTab === "theme" || pop.activeTab === "shell" || pop.activeTab === "forge" || pop.activeTab === "state" || pop.activeTab === "power"
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
