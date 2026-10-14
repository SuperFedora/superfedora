import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import ".."

// SuperDesk 16-Bit SNES Helper: [1] AI Inline Agent Bar + [4] AUDIO & CAM 16-Segment Power Deck.
ColumnLayout {
    id: audioDeck
    property string activeTab: "ai"
    property bool agentBarOpen: false
    signal executeCommand(string cmd, bool closeAfter)
    signal agentSelected()
    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10

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
                    required property var modelData
                    readonly property bool isCur: Status.aiAgent === modelData.id
                    Layout.fillWidth: true; implicitHeight: 24; radius: Theme.radiusSm
                    color: agM.containsMouse ? Theme.blue : (isCur ? Theme.bgAlt : Theme.bg)
                    border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: (parent.isCur ? "▸ " : "") + parent.modelData.label
                        color: agM.containsMouse ? Theme.bg : (parent.isCur ? Theme.cyan : Theme.fg)
                        font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                    }
                    MouseArea {
                        id: agM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { Status.selectAiAgent(parent.modelData.id); audioDeck.agentSelected(); }
                    }
                }
            }
            Rectangle {
                implicitWidth: 96; implicitHeight: 24; radius: Theme.radiusSm
                color: rspM.containsMouse ? Theme.yellow : Theme.bgAlt; border.width: 1; border.color: Theme.yellow
                Text { anchors.centerIn: parent; text: "󰑐 RESPAWN"; color: rspM.containsMouse ? Theme.bg : Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                MouseArea {
                    id: rspM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { audioDeck.agentSelected(); audioDeck.executeCommand("~/.config/hypr/scripts/quake-ai.sh restart", false); }
                }
            }
        }
    }

    // ---------------- [4] AUDIO & CAM: 16-Bit SNES Equipment Screen ----------------
    ColumnLayout {
        visible: audioDeck.activeTab === "audio"
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10

        // 1. Speakers & Microphone 16-Segment Energy Tanks
        Repeater {
            model: [
                { id: "spk", title: "SPEAKERS (OUTPUT)", icon: audioDeck.muted ? "󰝟" : "󰕾", val: audioDeck.vol, muted: audioDeck.muted, col: Theme.blue, hiCol: Theme.cyan },
                { id: "mic", title: "MICROPHONE (INPUT)", icon: audioDeck.micMuted ? "󰍭" : "󰍬", val: audioDeck.micVol, muted: audioDeck.micMuted, col: Theme.green, hiCol: Theme.cyan }
            ]
            Rectangle {
                id: tankCard; required property var modelData
                Layout.fillWidth: true; implicitHeight: 84; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: modelData.muted ? Theme.red : Theme.blue
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout {
                    anchors { fill: parent; margins: 12 } spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text { text: "▸ " + tankCard.modelData.icon + "  " + tankCard.modelData.title; color: tankCard.modelData.muted ? Theme.red : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true }
                        Text { text: tankCard.modelData.muted ? "[MUTED]" : (Math.round(tankCard.modelData.val * 100) + "%"); color: tankCard.modelData.muted ? Theme.red : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                        Rectangle {
                            implicitWidth: 112; implicitHeight: 28; radius: Theme.radiusSm
                            color: mBtn.containsMouse ? Theme.bgHover : Theme.bg; border.width: 2; border.color: tankCard.modelData.muted ? Theme.red : Theme.green
                            Text { anchors.centerIn: parent; text: tankCard.modelData.muted ? "[ 󰝟 MUTE ]" : "[ 󰕾 LIVE ]"; color: tankCard.modelData.muted ? Theme.red : Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                            MouseArea {
                                id: mBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (tankCard.modelData.id === "spk") { const m = !audioDeck.muted; if (audioDeck.audioReady) audioDeck.sink.audio.muted = m; Status.toggleSpeakerMute(m); }
                                    else { const m = !audioDeck.micMuted; if (audioDeck.micReady) audioDeck.source.audio.muted = m; Status.toggleMicMute(m); }
                                }
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true; height: 22
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
                                const v = Math.max(0, Math.min(1, Math.round((mx / width) * 16) / 16.0));
                                if (tankCard.modelData.id === "spk") { if (audioDeck.audioReady) audioDeck.sink.audio.volume = v; Status.setSpeakerVolume(v); }
                                else { if (audioDeck.micReady) audioDeck.source.audio.volume = v; Status.setMicVolume(v); }
                            }
                            onPressed: e => apply(e.x)
                            onPositionChanged: e => { if (pressed) apply(e.x); }
                        }
                    }
                }
            }
        }

        // 2. Web Camera Hardware Kill-Switch Card
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 58; radius: Theme.radius
            color: camM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: Status.webcamEnabled ? Theme.green : Theme.red
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 } spacing: 12
                Text { text: "▸ HARDWARE SENSOR GATE"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; Layout.fillWidth: true }
                Text {
                    text: Status.webcamEnabled ? "[ 󰄀 WEB CAMERA: ON (ACTIVE) ]" : "[ 󰗟 WEB CAMERA: OFF (BLOCKED) ]"
                    color: Status.webcamEnabled ? Theme.green : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
                }
            }
            MouseArea { id: camM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleWebcam() }
        }

        // 3. Display Brightness & ThinkPad Keyboard Backlight Cartridge
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 12 } spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "▸ 󰃠  DISPLAY BRIGHTNESS (Fn+F5 / Fn+F6)"; color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; Layout.fillWidth: true }
                    Text { text: Math.round(Status.brightness * 100) + "%"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                }
                Item {
                    Layout.fillWidth: true; height: 20
                    RowLayout {
                        anchors.fill: parent; spacing: 4
                        Repeater {
                            model: 16
                            Rectangle {
                                required property int index
                                readonly property bool lit: (index + 1) / 16.0 <= Status.brightness + 0.02
                                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                                color: lit ? Theme.yellow : Theme.bg; border.width: 1; border.color: lit ? Theme.cyan : Theme.border
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        function setB(mx) { Status.setBrightness(Math.max(0.06, Math.min(1, Math.round((mx / width) * 16) / 16.0))); }
                        onPressed: e => setB(e.x)
                        onPositionChanged: e => { if (pressed) setB(e.x); }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "▸ 󰌌  THINKPAD KEYBOARD BACKLIGHT (Fn+Space)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.fillWidth: true }
                    Repeater {
                        model: [ { lvl: 0, label: "[ OFF ]" }, { lvl: 1, label: "[ LOW ]" }, { lvl: 2, label: "[ HIGH ]" } ]
                        Rectangle {
                            required property var modelData
                            readonly property bool isCur: Status.kbdBacklight === modelData.lvl
                            implicitWidth: 88; implicitHeight: 26; radius: Theme.radiusSm
                            color: kbM.containsMouse ? Theme.bgHover : (isCur ? Theme.blue : Theme.bg)
                            border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border
                            Text { anchors.centerIn: parent; text: parent.modelData.label; color: parent.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                            MouseArea { id: kbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.setKbdBacklight(parent.modelData.lvl) }
                        }
                    }
                }
            }
        }

        // 4. Bottom 16-Bit Arcade TUI Launch Button
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 44; radius: Theme.radius
            color: wmM.containsMouse ? Theme.blue : Theme.bgAlt; border.width: 2; border.color: Theme.cyan
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            Text {
                anchors.centerIn: parent; text: "▸ [ 󰕾 LAUNCH AUDIO MIXER TUI (wiremix) ]"
                color: wmM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
            }
            MouseArea {
                id: wmM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: audioDeck.executeCommand("PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wiremix", true)
            }
        }
    }
}
