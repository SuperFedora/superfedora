import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth

// Unified "SuperDeck" — Omarchy Menu + GNOME Quick Settings + Control Center in One Surface.
PanelWindow {
    id: pop

    property bool leftAligned: false
    property int rightOffset: 6
    property var targetScreen: Quickshell.screens[0]

    visible: Status.superDeckOpen
    screen: pop.targetScreen
    color: "transparent"

    WlrLayershell.namespace: "superfedora-superdeck"
    WlrLayershell.keyboardFocus: Status.superDeckOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; left: pop.leftAligned; right: !pop.leftAligned }
    margins { top: Theme.barHeight + 6; left: pop.leftAligned ? 6 : 0; right: pop.leftAligned ? 0 : Math.max(6, pop.rightOffset) }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 420; implicitHeight: box.implicitHeight

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioReady: sink !== null && sink.audio !== null
    readonly property real vol: audioReady ? sink.audio.volume : Status.spkVol
    readonly property bool muted: audioReady ? sink.audio.muted : Status.spkMuted
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micReady: source !== null && source.audio !== null
    readonly property real micVol: micReady ? source.audio.volume : Status.micVol
    readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var batDev: UPower.displayDevice
    readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 0
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    onVisibleChanged: if (pop.visible) { searchInput.text = ""; searchInput.forceActiveFocus(); }

    function runCmd(cmd, closeAfter) {
        if (closeAfter) Status.superDeckOpen = false;
        Status.playSfx("confirm");
        Quickshell.execDetached(["sh", "-c", cmd]);
        Status.refresh();
    }

    readonly property var quickTiles: [
        {
            icon: Status.netType === "ethernet" ? "󰀂" : (Status.netType === "wifi" ? "󰤨" : "󰤮"),
            title: "Wi-Fi / Net",
            sub: Status.netType === "wifi" ? (Status.ssid || "Connected") : (Status.netType === "ethernet" ? "Ethernet" : "Offline"),
            active: Status.netType !== "none",
            cmd: (Status.netType === "wifi" ? "nmcli radio wifi off" : "nmcli radio wifi on") + "; sleep 0.4",
            sec: "net"
        },
        {
            icon: pop.btEnabled ? "󰂯" : "󰂲", title: "Bluetooth", sub: pop.btEnabled ? "Enabled" : "Off", active: pop.btEnabled,
            cmd: pop.btEnabled ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on", sec: "net"
        },
        {
            icon: Theme.mode === "light" ? "󰖙" : "󰖔", title: Theme.mode === "light" ? "Day Mode" : "Night Mode", sub: Theme.themeName,
            active: Theme.mode === "dark", cmd: "~/.local/bin/sf theme toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh toggle", sec: "style"
        },
        {
            icon: Theme.corners === "rounded" ? "󰙀" : "󰝣", title: "Corners", sub: Theme.corners === "rounded" ? "Rounded" : "Square 90°",
            active: Theme.corners === "rounded", cmd: "~/.local/bin/sf theme corners toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh corners toggle", sec: "style"
        },
        {
            icon: Status.idleEnabled ? "󰒲" : "󰅶", title: "Caffeine", sub: Status.idleEnabled ? "Auto-Idle" : "Stay Awake",
            active: !Status.idleEnabled, cmd: "~/.config/hypr/scripts/toggle-idle.sh", sec: "dock"
        },
        {
            icon: Status.sfxEnabled ? "󰕾" : "󰝟", title: "16-Bit SFX", sub: Status.sfxEnabled ? "Chimes On" : "Muted",
            active: Status.sfxEnabled, action: "sfx", sec: "style"
        }
    ]

    Rectangle {
        id: box
        width: parent.width; implicitHeight: mainCol.implicitHeight + 22
        color: Theme.bg; radius: Theme.radius; border.width: 2
        border.color: Status.superDeckSection === "power" ? Theme.red : Theme.blue

        ColumnLayout {
            id: mainCol
            anchors.fill: parent; anchors.margins: 11; spacing: 8

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "󰣛 SUPERDECK"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm; color: Theme.bgAlt
                    border.width: searchInput.activeFocus ? 2 : 1; border.color: searchInput.activeFocus ? Theme.blue : Theme.border

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                        Text { text: "󰍉"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                        TextInput {
                            id: searchInput; Layout.fillWidth: true; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; clip: true
                            Keys.onEscapePressed: Status.superDeckOpen = false
                            Keys.onReturnPressed: if (catalog.filteredRows.length > 0) { const first = catalog.filteredRows[0]; pop.runCmd(first.cmd, first.close); }
                            Text { visible: searchInput.text === ""; text: "Search settings, apps, or owner/repo..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                        }
                    }
                }
                Rectangle {
                    visible: pop.batPresent; implicitWidth: batHdrTxt.implicitWidth + 12; implicitHeight: 28; radius: Theme.radiusSm
                    color: Theme.bgAlt; border.width: 1; border.color: pop.batCharging ? Theme.green : Theme.border
                    Text {
                        id: batHdrTxt; anchors.centerIn: parent
                        text: (pop.batCharging ? "󰂄 " : (pop.batPct <= 15 ? "󰁺 " : pop.batPct <= 40 ? "󰁼 " : pop.batPct <= 75 ? "󰂀 " : "󰁹 ")) + pop.batPct + "%"
                        color: pop.batCharging ? Theme.green : (pop.batPct <= 15 ? Theme.red : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Status.superDeckSection = "power"; Status.playSfx("click"); } }
                }
            }

            // Input / Output Section (Speakers, Microphone, Web Camera, Brightness)
            ColumnLayout {
                Layout.fillWidth: true; spacing: 5

                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text { text: "INPUT / OUTPUT"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: spkBtnTxt.implicitWidth + 12; implicitHeight: 22; radius: Theme.radiusSm
                        color: !pop.muted ? Theme.bgAlt : Theme.bg; border.width: 1; border.color: !pop.muted ? Theme.blue : Theme.red
                        Text { id: spkBtnTxt; anchors.centerIn: parent; text: pop.muted ? "󰝟 Spk: Muted" : ("󰕾 Spk: " + Math.round(pop.vol * 100) + "%"); color: pop.muted ? Theme.red : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const m = !pop.muted; if (pop.audioReady) pop.sink.audio.muted = m; Status.toggleSpeakerMute(m); } }
                    }
                    Rectangle {
                        implicitWidth: micBtnTxt.implicitWidth + 12; implicitHeight: 22; radius: Theme.radiusSm
                        color: !pop.micMuted ? Theme.bgAlt : Theme.bg; border.width: 1; border.color: !pop.micMuted ? Theme.green : Theme.red
                        Text { id: micBtnTxt; anchors.centerIn: parent; text: pop.micMuted ? "󰍭 Mic: Muted" : ("󰍬 Mic: " + Math.round(pop.micVol * 100) + "%"); color: pop.micMuted ? Theme.red : Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const m = !pop.micMuted; if (pop.micReady) pop.source.audio.muted = m; Status.toggleMicMute(m); } }
                    }
                    Rectangle {
                        implicitWidth: camBtnTxt.implicitWidth + 12; implicitHeight: 22; radius: Theme.radiusSm
                        color: Status.webcamEnabled ? Theme.bgAlt : Theme.bg; border.width: 1; border.color: Status.webcamEnabled ? Theme.green : Theme.red
                        Text { id: camBtnTxt; anchors.centerIn: parent; text: Status.webcamEnabled ? "󰄀 Camera: ON" : "󰗟 Camera: OFF"; color: Status.webcamEnabled ? Theme.green : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleWebcam() }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text {
                        text: pop.muted ? "󰝟" : (pop.vol >= 0.5 ? "󰕾" : "󰖀"); color: pop.muted ? Theme.red : Theme.cyan; font.family: Theme.font; font.pixelSize: 16; Layout.preferredWidth: 18
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const m = !pop.muted; if (pop.audioReady) pop.sink.audio.muted = m; Status.toggleSpeakerMute(m); } }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 10; radius: Theme.radiusSm; color: Theme.bgAlt
                        Rectangle { width: parent.width * Math.max(0, Math.min(1, pop.vol)); height: parent.height; radius: Theme.radiusSm; color: pop.muted ? Theme.muted : Theme.blue }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onPressed: e => { const v = Math.max(0, Math.min(1, e.x / width)); if (pop.audioReady) pop.sink.audio.volume = v; Status.setSpeakerVolume(v); }
                            onPositionChanged: e => { if (pressed) { const v = Math.max(0, Math.min(1, e.x / width)); if (pop.audioReady) pop.sink.audio.volume = v; Status.setSpeakerVolume(v); } }
                        }
                    }
                    Text { text: pop.muted ? "MUTE" : (Math.round(pop.vol * 100) + "%"); color: pop.muted ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text {
                        text: pop.micMuted ? "󰍭" : "󰍬"; color: pop.micMuted ? Theme.red : Theme.green; font.family: Theme.font; font.pixelSize: 16; Layout.preferredWidth: 18
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const m = !pop.micMuted; if (pop.micReady) pop.source.audio.muted = m; Status.toggleMicMute(m); } }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 10; radius: Theme.radiusSm; color: Theme.bgAlt
                        Rectangle { width: parent.width * Math.max(0, Math.min(1, pop.micVol)); height: parent.height; radius: Theme.radiusSm; color: pop.micMuted ? Theme.muted : Theme.green }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onPressed: e => { const v = Math.max(0, Math.min(1, e.x / width)); if (pop.micReady) pop.source.audio.volume = v; Status.setMicVolume(v); }
                            onPositionChanged: e => { if (pressed) { const v = Math.max(0, Math.min(1, e.x / width)); if (pop.micReady) pop.source.audio.volume = v; Status.setMicVolume(v); } }
                        }
                    }
                    Text { text: pop.micMuted ? "MUTE" : (Math.round(pop.micVol * 100) + "%"); color: pop.micMuted ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "󰃠"; color: Theme.yellow; font.family: Theme.font; font.pixelSize: 16; Layout.preferredWidth: 18 }
                    Rectangle {
                        Layout.fillWidth: true; height: 10; radius: Theme.radiusSm; color: Theme.bgAlt
                        Rectangle { width: parent.width * Math.max(0, Math.min(1, Status.brightness)); height: parent.height; radius: Theme.radiusSm; color: Theme.yellow }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onPressed: e => Status.setBrightness(e.x / width)
                            onPositionChanged: e => { if (pressed) Status.setBrightness(e.x / width); }
                        }
                    }
                    Text { text: Math.round(Status.brightness * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                }
            }

            GridLayout {
                visible: searchInput.text.trim() === ""
                Layout.fillWidth: true; columns: 3; rowSpacing: 6; columnSpacing: 6

                Repeater {
                    model: pop.quickTiles
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 42; radius: Theme.radiusSm
                        color: modelData.active ? Theme.bgAlt : Theme.bg
                        border.width: modelData.active || tileMouse.containsMouse ? 2 : 1
                        border.color: modelData.active ? Theme.blue : (tileMouse.containsMouse ? Theme.cyan : Theme.border)

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 6; spacing: 6
                            Text { text: parent.parent.modelData.icon; color: parent.parent.modelData.active ? Theme.cyan : Theme.muted; font.family: Theme.font; font.pixelSize: 16 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { Layout.fillWidth: true; text: parent.parent.parent.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: parent.parent.parent.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; elide: Text.ElideRight }
                            }
                        }

                        MouseArea {
                            id: tileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: e => {
                                const t = parent.modelData;
                                if (e.button === Qt.RightButton && t.sec) { Status.superDeckSection = t.sec; Status.playSfx("click"); }
                                else if (t.action === "sfx") Status.toggleSfx();
                                else if (t.cmd) pop.runCmd(t.cmd, false);
                            }
                        }
                    }
                }
            }

            LauncherMenu {
                id: catalog; searchQuery: searchInput.text
                batPresent: pop.batPresent; batPct: pop.batPct; batCharging: pop.batCharging
                onExecuteCommand: (cmd, closeAfter) => pop.runCmd(cmd, closeAfter)
            }
        }
    }
}
