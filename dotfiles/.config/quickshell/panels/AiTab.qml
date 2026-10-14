import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import ".."

// SuperDesk 16-Bit SNES Helper: [1] AI Inline Agent Bar + [4] SENSORS & I/O (Zero Trust Layer 0C Hardware Gates & PipeWire Routing).
ColumnLayout {
    id: audioDeck
    property string activeTab: "ai"
    property bool agentBarOpen: false
    signal executeCommand(string cmd, bool closeAfter)
    signal agentSelected()
    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

    readonly property var sink: Pipewire.defaultAudioSink; readonly property bool audioReady: sink !== null && sink.audio !== null
    readonly property real vol: audioReady ? sink.audio.volume : Status.spkVol; readonly property bool muted: audioReady ? sink.audio.muted : Status.spkMuted
    readonly property var source: Pipewire.defaultAudioSource; readonly property bool micReady: source !== null && source.audio !== null
    readonly property real micVol: micReady ? source.audio.volume : Status.micVol; readonly property bool micMuted: micReady ? source.audio.muted : Status.micMuted

    readonly property var agentList: [
        { id: "agy", label: "AGY" }, { id: "mcode", label: "MCODE" }, { id: "grok", label: "GROK" },
        { id: "vibe", label: "VIBE" }, { id: "claude", label: "CLAUDE" }, { id: "chatgpt", label: "CHATGPT" },
        { id: "ollama", label: "OLLAMA" }
    ]

    // ---------------- [1] AI: Compact Inline 16-Bit Agent Picker Bar ----------------
    Rectangle {
        visible: audioDeck.activeTab === "ai" && audioDeck.agentBarOpen
        Layout.fillWidth: true; implicitHeight: 36; radius: Theme.radius; color: Theme.bg; border.width: 2; border.color: Theme.cyan
        Rectangle { anchors { fill: parent; margins: 2 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 } spacing: 6
            Text { text: "SELECT AGENT ▸"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
            Repeater {
                model: audioDeck.agentList
                Rectangle {
                    required property var modelData; readonly property bool isCur: Status.aiAgent === modelData.id
                    Layout.fillWidth: true; implicitHeight: 24; radius: Theme.radiusSm
                    color: agM.containsMouse ? Theme.blue : (isCur ? Theme.bgAlt : Theme.bg)
                    border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border
                    Text {
                        anchors.centerIn: parent; text: (parent.isCur ? "▸ " : "") + parent.modelData.label
                        color: agM.containsMouse ? Theme.bg : (parent.isCur ? Theme.cyan : Theme.fg)
                        font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                    }
                    MouseArea { id: agM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Status.selectAiAgent(parent.modelData.id); audioDeck.agentSelected(); } }
                }
            }
            Rectangle {
                implicitWidth: 96; implicitHeight: 24; radius: Theme.radiusSm
                color: rspM.containsMouse ? Theme.yellow : Theme.bgAlt; border.width: 1; border.color: Theme.yellow
                Text { anchors.centerIn: parent; text: "󰑐 RESPAWN"; color: rspM.containsMouse ? Theme.bg : Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                MouseArea { id: rspM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { audioDeck.agentSelected(); audioDeck.executeCommand("~/.config/hypr/scripts/quake-ai.sh restart", false); } }
            }
        }
    }

    // ---------------- [4] SENSORS & I/O: Zero Trust Layer 0C Hardware Gates ----------------
    ColumnLayout {
        visible: audioDeck.activeTab === "audio"
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

        // 1. Top Row — 3 Big 16-Bit Hardware Kill-Switch Cards (Camera, Mic, Speakers)
        RowLayout {
            Layout.fillWidth: true; implicitHeight: 58; spacing: 10
            Repeater {
                model: [
                    { id: "cam", label: Status.webcamEnabled ? "[ 󰄀 CAMERA: ON ]" : "[ 󰗟 CAMERA: OFF ]", live: Status.webcamEnabled, col: Status.webcamEnabled ? Theme.green : Theme.red },
                    { id: "mic", label: !audioDeck.micMuted ? "[ 󰍬 MIC: LIVE ]" : "[ 󰍭 MIC: MUTED ]", live: !audioDeck.micMuted, col: !audioDeck.micMuted ? Theme.green : Theme.red },
                    { id: "spk", label: !audioDeck.muted ? "[ 󰕾 SPEAKERS: LIVE ]" : "[ 󰝟 SPEAKERS: MUTED ]", live: !audioDeck.muted, col: !audioDeck.muted ? Theme.cyan : Theme.red }
                ]
                Rectangle {
                    id: gateCard; required property var modelData
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius
                    color: gMouse.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    Text {
                        anchors.centerIn: parent; text: (gMouse.containsMouse ? "▸ " : "") + gateCard.modelData.label
                        color: gateCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
                    }
                    MouseArea {
                        id: gMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const k = gateCard.modelData.id;
                            if (k === "cam") Status.toggleWebcam();
                            else if (k === "mic") { const m = !audioDeck.micMuted; if (audioDeck.micReady) audioDeck.source.audio.muted = m; Status.toggleMicMute(m); }
                            else { const m = !audioDeck.muted; if (audioDeck.audioReady) audioDeck.sink.audio.muted = m; Status.toggleSpeakerMute(m); }
                        }
                    }
                }
            }
        }

        // 2. Middle — 3 Big 16-Segment 16-Bit Energy Bars (Speakers Volume, Microphone Gain, Display Brightness)
        Repeater {
            model: [
                { id: "spk", title: "󰕾  SPEAKERS VOLUME", val: audioDeck.vol, muted: audioDeck.muted, col: Theme.blue, hiCol: Theme.cyan },
                { id: "mic", title: "󰍬  MICROPHONE GAIN", val: audioDeck.micVol, muted: audioDeck.micMuted, col: Theme.green, hiCol: Theme.cyan },
                { id: "bri", title: "󰃠  DISPLAY BRIGHTNESS", val: Status.brightness, muted: false, col: Theme.yellow, hiCol: Theme.yellow }
            ]
            Rectangle {
                id: tankCard; required property var modelData
                Layout.fillWidth: true; implicitHeight: 68; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: modelData.muted ? Theme.red : Theme.blue
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout {
                    anchors { fill: parent; margins: 10 } spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text { text: "▸ " + tankCard.modelData.title; color: tankCard.modelData.muted ? Theme.red : tankCard.modelData.hiCol; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; Layout.fillWidth: true }
                        Text { text: (tankCard.modelData.muted ? "[MUTED] " : "") + Math.round(tankCard.modelData.val * 100) + "%"; color: tankCard.modelData.muted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    }
                    Item {
                        Layout.fillWidth: true; height: 20
                        RowLayout {
                            anchors.fill: parent; spacing: 4
                            Repeater {
                                model: 16
                                Rectangle {
                                    required property int index
                                    readonly property bool lit: (index + 1) / 16.0 <= tankCard.modelData.val + 0.02
                                    Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                                    color: !lit ? Theme.bg : (tankCard.modelData.muted ? Theme.muted : (index >= 12 ? tankCard.modelData.hiCol : tankCard.modelData.col))
                                    border.width: 1; border.color: lit ? Theme.cyan : Theme.border
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            function apply(mx) {
                                const v = Math.max(tankCard.modelData.id === "bri" ? 0.06 : 0, Math.min(1, Math.round((mx / width) * 16) / 16.0));
                                if (tankCard.modelData.id === "spk") { if (audioDeck.audioReady) audioDeck.sink.audio.volume = v; Status.setSpeakerVolume(v); }
                                else if (tankCard.modelData.id === "mic") { if (audioDeck.micReady) audioDeck.source.audio.volume = v; Status.setMicVolume(v); }
                                else Status.setBrightness(v);
                            }
                            onPressed: e => apply(e.x)
                            onPositionChanged: e => { if (pressed) apply(e.x); }
                        }
                    }
                }
            }
        }

        // 3. Bottom — Inline Audio Output & Input Device Switcher (Replaces wiremix)
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 12 } spacing: 8
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text { text: "OUTPUT DEVICE:"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.preferredWidth: 132 }
                    Repeater {
                        model: Status.audioSinks
                        Rectangle {
                            id: snkBtn; required property var modelData
                            Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm
                            color: snkM.containsMouse ? Theme.bgHover : (modelData.active ? Theme.blue : Theme.bg)
                            border.width: modelData.active ? 2 : 1; border.color: modelData.active ? Theme.cyan : Theme.border
                            Text {
                                anchors.centerIn: parent; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                text: (snkBtn.modelData.active ? "▸ " : "") + snkBtn.modelData.name
                                color: snkBtn.modelData.active ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                            }
                            MouseArea { id: snkM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setAudioDefault(snkBtn.modelData.id) }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text { text: "INPUT DEVICE:"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.preferredWidth: 132 }
                    Repeater {
                        model: Status.audioSources
                        Rectangle {
                            id: srcBtn; required property var modelData
                            Layout.fillWidth: true; implicitHeight: 30; radius: Theme.radiusSm
                            color: srcM.containsMouse ? Theme.bgHover : (modelData.active ? Theme.blue : Theme.bg)
                            border.width: modelData.active ? 2 : 1; border.color: modelData.active ? Theme.cyan : Theme.border
                            Text {
                                anchors.centerIn: parent; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                text: (srcBtn.modelData.active ? "▸ " : "") + srcBtn.modelData.name
                                color: srcBtn.modelData.active ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                            }
                            MouseArea { id: srcM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setAudioDefault(srcBtn.modelData.id) }
                        }
                    }
                    Rectangle {
                        implicitWidth: 158; implicitHeight: 30; radius: Theme.radiusSm
                        color: kbM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 2; border.color: Status.kbdBacklight > 0 ? Theme.cyan : Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: "[ 󰌌 KBD LIGHT: " + (Status.kbdBacklight === 2 ? "HIGH" : (Status.kbdBacklight === 1 ? "LOW" : "OFF")) + " ]"
                            color: Status.kbdBacklight > 0 ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                        }
                        MouseArea { id: kbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setKbdBacklight() }
                    }
                }
            }
        }
    }
}
