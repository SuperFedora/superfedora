import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "panels"

// Omarchy Quattro + GNOME Top Bar: [SF] + Workspaces | Clock | Collapsible Pocket (◂/▸) + Unified Quick Settings Pill.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property int activeWsId: hyprMonitor && hyprMonitor.activeWorkspace
        ? hyprMonitor.activeWorkspace.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
    property bool aiOpen: false

    visible: true
    anchors { top: true; left: true; right: true }
    exclusionMode: ExclusionMode.Auto
    implicitWidth: modelData.width; implicitHeight: Theme.barHeight
    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.barOpacity)

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    function openDeck(sec, alignLeft) {
        calendarPopup.mode = ""; bar.aiOpen = false;
        statusPopup.leftAligned = alignLeft === true;
        Status.toggleSuperDeck(sec || "quick");
    }

    function toggleCenter(targetMode) {
        Status.superDeckOpen = false; bar.aiOpen = false;
        if (calendarPopup.mode === targetMode) calendarPopup.mode = "";
        else {
            if (targetMode === "date") calendarPopup.resetToToday(); else Status.refresh();
            calendarPopup.mode = targetMode;
        }
        Status.playSfx("click");
    }

    Calendar { id: calendarPopup; targetScreen: bar.modelData }
    StatusPopup { id: statusPopup; targetScreen: bar.modelData }
    AiPopup { id: aiPopup; targetScreen: bar.modelData; open: bar.aiOpen; rightOffset: 90; onCloseRequested: bar.aiOpen = false }

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
            color: (Status.superDeckOpen && statusPopup.leftAligned) ? Theme.cyan : Theme.blue
            pixelSize: Theme.iconSize + 2
            onClicked: bar.openDeck("quick", true)
            onRightClicked: bar.run("fuzzel")
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

    // ---------------- Right: Collapsible Pocket Drawer + Unified Quick Settings Pill ----------------
    RowLayout {
        id: rightRow
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
        spacing: 6

        Rectangle {
            id: pocketDrawer
            visible: Status.pocketOpen
            implicitWidth: pocketLayout.implicitWidth + 10; implicitHeight: Theme.barHeight - 8
            radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border

            RowLayout {
                id: pocketLayout; anchors.centerIn: parent; spacing: 2
                Tray { bar: bar; Layout.rightMargin: 4 }

                BarLabel {
                    text: "󰍛 " + Status.cpu + "%"; pixelSize: Theme.fontSize - 2
                    color: Status.cpu >= 80 ? Theme.red : Theme.fgDim
                    onClicked: bar.openDeck("snapshots", false)
                    onRightClicked: bar.run("kitty --class floating-term -e btop")
                }

                BarLabel {
                    id: aiBtn; text: "󰚩"; color: bar.aiOpen ? Theme.blue : Theme.cyan
                    onClicked: { Status.superDeckOpen = false; calendarPopup.mode = ""; bar.aiOpen = !bar.aiOpen; }
                    onRightClicked: { bar.aiOpen = false; bar.run("~/.config/hypr/scripts/quake-ai.sh toggle"); }
                }

                BarLabel {
                    text: Status.idleEnabled ? "󰒲" : "󰅶"; color: Status.idleEnabled ? Theme.fgDim : Theme.yellow
                    onClicked: { bar.run("~/.config/hypr/scripts/toggle-idle.sh"); Status.refresh(); }
                }

                BarLabel {
                    text: "󰀻"; color: Status.appGridOpen ? Theme.cyan : Theme.fgDim
                    onClicked: Status.appGridOpen = !Status.appGridOpen
                    onRightClicked: Status.runDockCmd("always toggle")
                }
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
            readonly property real vol: audioReady ? sink.audio.volume : 0
            readonly property bool muted: audioReady ? sink.audio.muted : true
            readonly property var btAdapter: Bluetooth.defaultAdapter
            readonly property int btConnected: Bluetooth.devices.values.filter(d => d.connected).length
            readonly property var batDev: UPower.displayDevice
            readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
            readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
            readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

            implicitWidth: pillRow.implicitWidth + 18; implicitHeight: Theme.barHeight - 8
            radius: Theme.radiusSm
            color: (Status.superDeckOpen && !statusPopup.leftAligned) || pillMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
            border.width: (Status.superDeckOpen && !statusPopup.leftAligned) ? 2 : 1
            border.color: (Status.superDeckOpen && !statusPopup.leftAligned) ? Theme.blue : Theme.border

            RowLayout {
                id: pillRow; anchors.centerIn: parent; spacing: 8
                Text {
                    text: Status.netType === "ethernet" ? "󰀂" : (Status.netType !== "wifi" ? "󰤮" : (Status.signal >= 80 ? "󰤨" : Status.signal >= 60 ? "󰤥" : Status.signal >= 40 ? "󰤢" : Status.signal >= 20 ? "󰤟" : "󰤯"))
                    color: Status.netType === "none" ? Theme.muted : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                }
                Text {
                    visible: quickPill.btAdapter !== null
                    text: !quickPill.btAdapter || !quickPill.btAdapter.enabled ? "󰂲" : (quickPill.btConnected > 0 ? "󰂱" : "󰂯")
                    color: quickPill.btAdapter && quickPill.btAdapter.enabled ? Theme.fg : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                }
                Text {
                    text: quickPill.muted ? "󰝟" : quickPill.vol >= 0.66 ? "󰕾" : quickPill.vol >= 0.33 ? "󰖀" : "󰕿"
                    color: quickPill.muted ? Theme.muted : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                }
                Text {
                    visible: quickPill.batPresent
                    text: quickPill.batCharging ? "󰂄" : (quickPill.batPct <= 15 ? "󰁺" : quickPill.batPct <= 40 ? "󰁼" : quickPill.batPct <= 75 ? "󰂀" : "󰁹")
                    color: quickPill.batCharging ? Theme.green : (quickPill.batPct <= 15 ? Theme.red : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.iconSize - 2
                }
                Text { text: "󰐥"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.iconSize - 2 }
            }

            MouseArea {
                id: pillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => bar.openDeck(e.button === Qt.RightButton ? "power" : "quick", false)
                onWheel: wheel => { if (quickPill.audioReady) quickPill.sink.audio.volume = Math.max(0, Math.min(1, quickPill.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))); }
            }
        }
    }
}
