import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth

// Omarchy Quattro + GNOME Top Bar: [SF] + Workspaces | Clock | Collapsible System Tray (◂/▸) + Clean Status Pill.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property int activeWsId: hyprMonitor && hyprMonitor.activeWorkspace
        ? hyprMonitor.activeWorkspace.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    visible: true
    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Auto
    implicitWidth: modelData.width; implicitHeight: Theme.barHeight
    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.barOpacity)

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    function openDeck(sec) {
        calendarPopup.mode = "";
        Status.toggleSuperDeck(sec || "");
    }

    function toggleCenter(targetMode) {
        Status.superDeckOpen = false;
        if (calendarPopup.mode === targetMode) calendarPopup.mode = "";
        else {
            if (targetMode === "date") calendarPopup.resetToToday(); else Status.refresh();
            calendarPopup.mode = targetMode;
        }
        Status.playSfx("click");
    }

    Calendar { id: calendarPopup; targetScreen: bar.modelData }
    StatusPopup { id: statusPopup; targetScreen: bar.modelData }

    // Omarchy Quattro: double-click empty bar space to toggle bar transparency
    MouseArea {
        anchors.fill: parent; z: -1
        onDoubleClicked: { Theme.barOpacity = Theme.barOpacity < 0.99 ? 1.0 : 0.82; Status.playSfx("toggle"); }
    }

    // ---------------- Left ----------------
    RowLayout {
        id: leftRow
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 }
        spacing: 0

        BarLabel {
            text: "󰣛"
            color: Status.superDeckOpen ? Theme.cyan : Theme.blue
            pixelSize: Theme.iconSize + 2
            onClicked: bar.openDeck("")
            onRightClicked: bar.openDeck("ai")
        }

        Workspaces { monitor: bar.hyprMonitor; thickness: bar.implicitHeight }

        BarLabel {
            id: modeLabel
            property string mode: ""
            visible: mode !== ""
            text: "󰌌 " + mode.toUpperCase() + "  ·  Esc to exit"
            color: Theme.yellow; pixelSize: Theme.fontSize; bold: true
            onClicked: Hyprland.dispatch("submap reset")
            Connections { target: Hyprland; function onRawEvent(event) { if (event.name === "submap") modeLabel.mode = event.data; } }
        }
    }

    // ---------------- Center ----------------
    Connections {
        target: Status
        function onCenterToggleSeqChanged() { if (bar.modelData === Quickshell.screens[0]) bar.toggleCenter("date"); }
    }

    RowLayout {
        id: centerClock
        anchors.centerIn: parent; spacing: 4
        property date now: new Date()
        Timer { interval: Status.clockSeconds ? 1000 : 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: centerClock.now = new Date() }

        BarLabel {
            pixelSize: Theme.fontSize; bold: true
            color: calendarPopup.mode === "date" ? Theme.blue : Theme.fg
            text: Qt.formatDateTime(centerClock.now, "ddd, MMM d")
            onClicked: bar.toggleCenter("date")
            onRightClicked: if (Status.notifAction) Status.notifAction("toggleDnd")
        }

        BarLabel {
            pixelSize: Theme.fontSize; bold: true
            color: calendarPopup.mode === "time" ? Theme.blue : Theme.fg
            text: Qt.formatDateTime(centerClock.now, Status.clock24h ? (Status.clockSeconds ? "HH:mm:ss" : "HH:mm") : (Status.clockSeconds ? "h:mm:ss AP" : "h:mm AP"))
            onClicked: bar.toggleCenter("time")
            onRightClicked: Status.saveClockPrefs(!Status.clock24h, Status.clockSeconds)
        }

        BarLabel {
            pixelSize: Theme.fontSize - 1; bold: Status.notifUnread > 0 || Status.dnd
            color: Status.dnd ? Theme.yellow : (Status.notifUnread > 0 ? Theme.cyan : (calendarPopup.mode === "date" ? Theme.blue : Theme.fgDim))
            text: Status.dnd ? ("󰂛" + (Status.notifUnread > 0 ? " " + Status.notifUnread : "")) : (Status.notifUnread > 0 ? ("󰂞 " + Status.notifUnread) : "󰂚")
            onClicked: bar.toggleCenter("date")
            onRightClicked: if (Status.notifAction) Status.notifAction("toggleDnd")
        }
    }

    // ---------------- Right: Collapsible System Tray + Clean Status Pill ----------------
    RowLayout {
        id: rightRow
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
        spacing: 6

        Rectangle {
            id: pocketDrawer
            visible: Status.pocketOpen
            implicitWidth: pocketLayout.implicitWidth + 6; implicitHeight: Theme.barHeight - 8
            color: "transparent"; border.width: 0

            RowLayout {
                id: pocketLayout; anchors.centerIn: parent; spacing: 2
                Tray { bar: bar }
            }
        }

        BarLabel {
            id: pocketToggle
            text: Status.pocketOpen ? "▸" : "◂"
            color: Status.pocketOpen ? Theme.cyan : Theme.fgDim
            pixelSize: Theme.fontSize
            onClicked: { Status.pocketOpen = !Status.pocketOpen; Status.playSfx("click"); }
        }

        Rectangle {
            id: quickPill
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property bool audioReady: sink !== null && sink.audio !== null
            readonly property real vol: audioReady ? sink.audio.volume : Status.spkVol
            readonly property bool muted: audioReady ? sink.audio.muted : Status.spkMuted
            readonly property var source: Pipewire.defaultAudioSource
            readonly property bool micReady: source !== null && source.audio !== null
            readonly property real micVol: micReady ? source.audio.volume : Status.micVol
            readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted
            readonly property var btAdapter: Bluetooth.defaultAdapter
            readonly property int btConnected: Bluetooth.devices.values.filter(d => d.connected).length
            readonly property var batDev: UPower.displayDevice
            readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
            readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
            readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

            implicitWidth: pillRow.implicitWidth + 12; implicitHeight: Theme.barHeight - 8
            color: "transparent"; border.width: 0

            RowLayout {
                id: pillRow; anchors.centerIn: parent; spacing: 8

                Text {
                    text: !Status.wifiEnabled ? "󰤮" : (Status.netType === "ethernet" ? "󰀂" : (Status.netType !== "wifi" ? "󰤯" : (Status.signal >= 80 ? "󰤨" : Status.signal >= 60 ? "󰤥" : Status.signal >= 40 ? "󰤢" : Status.signal >= 20 ? "󰤟" : "󰤯")))
                    color: (Status.superDeckOpen && Status.superDeckSection === "wifi") ? Theme.cyan : (!Status.wifiEnabled || Status.netType === "none" ? Theme.red : Theme.fg)
                    font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                    MouseArea {
                        anchors { fill: parent; margins: -3 } cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => { if (e.button === Qt.RightButton) Status.toggleWifiRadio(); else bar.openDeck("wifi"); }
                    }
                }
                Text {
                    text: !quickPill.btAdapter || !quickPill.btAdapter.enabled ? "󰂲" : (quickPill.btConnected > 0 ? "󰂱" : "󰂯")
                    color: (Status.superDeckOpen && Status.superDeckSection === "bluetooth") ? Theme.cyan : (quickPill.btAdapter && quickPill.btAdapter.enabled ? Theme.fg : Theme.muted)
                    font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                    MouseArea {
                        anchors { fill: parent; margins: -3 } cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => {
                            if (e.button === Qt.RightButton) { bar.run(quickPill.btAdapter && quickPill.btAdapter.enabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on"); Status.playSfx("toggle"); Status.refresh(); }
                            else bar.openDeck("bluetooth");
                        }
                    }
                }
                Text {
                    text: quickPill.muted ? "󰝟" : quickPill.vol >= 0.66 ? "󰕾" : quickPill.vol >= 0.33 ? "󰖀" : "󰕿"
                    color: quickPill.muted ? Theme.red : ((Status.superDeckOpen && Status.superDeckSection === "audio") ? Theme.cyan : Theme.fg)
                    font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                    MouseArea {
                        anchors { fill: parent; margins: -3 } cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => {
                            if (e.button === Qt.RightButton) { const m = !quickPill.muted; if (quickPill.audioReady) quickPill.sink.audio.muted = m; Status.toggleSpeakerMute(m); }
                            else bar.openDeck("audio");
                        }
                        onWheel: wheel => {
                            const v = Math.max(0, Math.min(1, quickPill.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                            if (quickPill.audioReady) quickPill.sink.audio.volume = v;
                            Status.setSpeakerVolume(v);
                        }
                    }
                }
                Text {
                    text: quickPill.micMuted ? "󰍭" : "󰍬"
                    color: quickPill.micMuted ? Theme.red : ((Status.superDeckOpen && Status.superDeckSection === "audio") ? Theme.cyan : Theme.fg)
                    font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                    MouseArea {
                        anchors { fill: parent; margins: -3 } cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => {
                            if (e.button === Qt.RightButton) { const m = !quickPill.micMuted; if (quickPill.micReady) quickPill.source.audio.muted = m; Status.toggleMicMute(m); }
                            else bar.openDeck("audio");
                        }
                        onWheel: wheel => {
                            const v = Math.max(0, Math.min(1, quickPill.micVol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                            if (quickPill.micReady) quickPill.source.audio.volume = v;
                            Status.setMicVolume(v);
                        }
                    }
                }
                Text {
                    text: Status.webcamEnabled ? "󰄀" : "󰗟"
                    color: !Status.webcamEnabled ? Theme.red : ((Status.superDeckOpen && Status.superDeckSection === "audio") ? Theme.cyan : Theme.fg)
                    font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                    MouseArea {
                        anchors { fill: parent; margins: -3 } cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => { if (e.button === Qt.RightButton) Status.toggleWebcam(); else bar.openDeck("audio"); }
                    }
                }
                Text {
                    visible: quickPill.batPresent
                    text: quickPill.batCharging ? "󰂄" : (quickPill.batPct <= 15 ? "󰁺" : quickPill.batPct <= 40 ? "󰁼" : quickPill.batPct <= 75 ? "󰂀" : "󰁹")
                    color: (Status.superDeckOpen && Status.superDeckSection === "power") ? Theme.cyan : (quickPill.batCharging ? Theme.green : (quickPill.batPct <= 15 ? Theme.red : Theme.fg))
                    font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                    MouseArea {
                        anchors { fill: parent; margins: -3 } cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: bar.openDeck("power")
                    }
                }
                Text {
                    id: pwrIcon; text: "󰐥"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                    MouseArea {
                        anchors { fill: parent; margins: -3 } cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: bar.openDeck("power")
                    }
                }
            }
        }
    }
}

