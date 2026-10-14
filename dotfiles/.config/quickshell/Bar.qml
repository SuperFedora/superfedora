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

    // Omarchy Quattro: click empty bar space to close popups; double-click to toggle bar transparency
    MouseArea {
        anchors.fill: parent; z: -1
        onClicked: { Status.superDeckOpen = false; calendarPopup.mode = ""; }
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
            id: pocketDrawer; visible: Status.pocketOpen
            implicitWidth: visible ? trayRow.implicitWidth + 4 : 0; implicitHeight: Theme.barHeight - 8
            color: "transparent"; border.width: 0
            Tray { id: trayRow; anchors.centerIn: parent; bar: bar }
        }

        Rectangle {
            id: pocketToggle; implicitWidth: 26; implicitHeight: Theme.barHeight - 8; radius: Theme.radiusSm
            color: ptMouse.containsMouse ? Theme.bgHover : "transparent"
            Text { anchors.centerIn: parent; text: Status.pocketOpen ? "▸" : "◂"; color: Status.pocketOpen || ptMouse.containsMouse ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize }
            MouseArea { id: ptMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.pocketOpen = !Status.pocketOpen; Status.playSfx("click"); } }
        }

        Rectangle { implicitWidth: 1; implicitHeight: 14; color: Theme.border }

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

            function iconGlyph(id) {
                if (id === "wifi") return !Status.wifiEnabled ? "󰤮" : (Status.netType === "ethernet" ? "󰀂" : (Status.netType !== "wifi" ? "󰤯" : (Status.signal >= 80 ? "󰤨" : Status.signal >= 60 ? "󰤥" : Status.signal >= 40 ? "󰤢" : Status.signal >= 20 ? "󰤟" : "󰤯")));
                if (id === "bluetooth") return !quickPill.btAdapter || !quickPill.btAdapter.enabled ? "󰂲" : (quickPill.btConnected > 0 ? "󰂱" : "󰂯");
                if (id === "speaker") return quickPill.muted ? "󰝟" : quickPill.vol >= 0.66 ? "󰕾" : quickPill.vol >= 0.33 ? "󰖀" : "󰕿";
                if (id === "mic") return quickPill.micMuted ? "󰍭" : "󰍬";
                if (id === "camera") return Status.webcamEnabled ? "󰄀" : "󰗟";
                if (id === "battery") return quickPill.batCharging ? "󰂄" : (quickPill.batPct <= 15 ? "󰁺" : quickPill.batPct <= 40 ? "󰁼" : quickPill.batPct <= 75 ? "󰂀" : "󰁹");
                return "󰐥";
            }
            function iconSection(id) {
                return (id === "wifi" || id === "bluetooth") ? id : ((id === "battery" || id === "power") ? "power" : "audio");
            }
            function iconColor(id, hovered) {
                if (Status.superDeckOpen && Status.superDeckSection === quickPill.iconSection(id)) return Theme.cyan;
                if (hovered) return id === "power" ? Theme.red : Theme.cyan;
                if (id === "wifi") return (!Status.wifiEnabled || Status.netType === "none") ? Theme.muted : Theme.fg;
                if (id === "bluetooth") return (quickPill.btAdapter && quickPill.btAdapter.enabled) ? (quickPill.btConnected > 0 ? Theme.fg : Theme.fgDim) : Theme.muted;
                if (id === "speaker") return quickPill.muted ? Theme.muted : Theme.fg;
                if (id === "mic") return quickPill.micMuted ? Theme.muted : Theme.fg;
                if (id === "camera") return Status.webcamEnabled ? Theme.fg : Theme.muted;
                if (id === "battery") return quickPill.batCharging ? Theme.cyan : (quickPill.batPct <= 15 ? Theme.red : Theme.fg);
                return Theme.fgDim;
            }
            function toggleHardware(id) {
                if (id === "wifi") Status.toggleWifiRadio();
                else if (id === "bluetooth") { bar.run(quickPill.btAdapter && quickPill.btAdapter.enabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on"); Status.playSfx("toggle"); Status.refresh(); }
                else if (id === "speaker") { const m = !quickPill.muted; if (quickPill.audioReady) quickPill.sink.audio.muted = m; Status.toggleSpeakerMute(m); }
                else if (id === "mic") { const m = !quickPill.micMuted; if (quickPill.micReady) quickPill.source.audio.muted = m; Status.toggleMicMute(m); }
                else if (id === "camera") Status.toggleWebcam();
                else bar.openDeck("power");
            }

            implicitWidth: pillRow.implicitWidth + 6; implicitHeight: Theme.barHeight - 6
            color: "transparent"; border.width: 0

            RowLayout {
                id: pillRow; anchors.centerIn: parent; spacing: 2
                Repeater {
                    model: Status.barIcons
                    Item {
                        id: slotItem; required property string modelData; required property int index
                        readonly property bool isDiv: modelData === "|"
                        readonly property bool isVis: isDiv ? (index > 0 && index < Status.barIcons.length - 1) : (Status.barHiddenIcons.indexOf(modelData) < 0 && (modelData !== "battery" || quickPill.batPresent))
                        visible: isVis; implicitWidth: !isVis ? 0 : (isDiv ? 9 : 26); implicitHeight: Theme.barHeight - 8

                        Rectangle { visible: slotItem.isDiv; anchors.centerIn: parent; width: 1; height: 14; color: Theme.border }

                        Rectangle {
                            visible: !slotItem.isDiv; anchors.fill: parent; radius: Theme.radiusSm
                            color: slotMouse.pressed ? Theme.bgAlt : (slotMouse.containsMouse ? Theme.bgHover : "transparent")
                            border.width: slotMouse.pressed ? 1 : 0; border.color: Theme.cyan
                            Text {
                                anchors.centerIn: parent; text: slotItem.isDiv ? "" : quickPill.iconGlyph(slotItem.modelData)
                                color: slotItem.isDiv ? "transparent" : quickPill.iconColor(slotItem.modelData, slotMouse.containsMouse)
                                font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                            }
                            MouseArea {
                                id: slotMouse; property real dragStartX: 0; property bool didDrag: false
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPressed: e => { dragStartX = e.x; didDrag = false; }
                                onPositionChanged: e => {
                                    if (!(pressedButtons & Qt.LeftButton)) return;
                                    const dx = e.x - dragStartX;
                                    if (Math.abs(dx) >= 24) { didDrag = true; Status.moveBarIcon(slotItem.modelData, dx > 0 ? 1 : -1); dragStartX = e.x; }
                                }
                                onClicked: e => { if (!didDrag) { if (e.button === Qt.RightButton) quickPill.toggleHardware(slotItem.modelData); else bar.openDeck(quickPill.iconSection(slotItem.modelData)); } }
                                onWheel: wheel => {
                                    const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                    if (slotItem.modelData === "speaker") { const v = Math.max(0, Math.min(1, quickPill.vol + step)); if (quickPill.audioReady) quickPill.sink.audio.volume = v; Status.setSpeakerVolume(v); }
                                    else if (slotItem.modelData === "mic") { const v = Math.max(0, Math.min(1, quickPill.micVol + step)); if (quickPill.micReady) quickPill.source.audio.volume = v; Status.setMicVolume(v); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

