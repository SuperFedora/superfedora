import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// Quake-style top drop-down AI Console HUD & Agent Switcher (bound to SUPER + grave).
PanelWindow {
    id: win
    property var targetScreen: Quickshell.screens[0]
    property bool open: false
    property int consoleWidth: 1180
    property string activeAgent: "agy"

    readonly property int targetTop: win.open ? (Theme.barHeight + 4) : -42
    property real animTop: -42

    Behavior on animTop {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    onTargetTopChanged: win.animTop = win.targetTop

    visible: win.open || win.animTop > -38
    screen: win.targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true }
    margins.top: Math.round(win.animTop)
    implicitWidth: Math.min(win.consoleWidth, (win.targetScreen ? win.targetScreen.width - 40 : 1180))
    implicitHeight: 32

    function runCmd(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "activespecialv2") {
                const d = String(event.data || "");
                win.open = d.includes("special:ai");
            }
        }
    }

    IpcHandler {
        target: "ai"
        function toggle(): void {
            win.runCmd("~/.config/hypr/scripts/quake-ai.sh toggle");
        }
        function show(w: string, agent: string): void {
            const parsed = Number(w);
            if (parsed >= 600) win.consoleWidth = parsed;
            if (agent) win.activeAgent = agent;
            win.open = true;
        }
        function hide(): void {
            win.open = false;
        }
        function setAgent(agent: string): void {
            if (agent) win.activeAgent = agent;
            win.runCmd("~/.config/hypr/scripts/quake-ai.sh set-agent " + agent);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        radius: 4
        border.width: 2
        border.color: Theme.blue

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
            spacing: 8

            Rectangle {
                width: 8; height: 8; radius: 4
                color: Theme.green
            }

            Text {
                text: "󰚩  QUAKE AI // DROP-DOWN"
                color: Theme.blue
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: [
                    { id: "agy",   label: "Antigravity (agy)" },
                    { id: "grok",  label: "Grok CLI" },
                    { id: "mcode", label: "MiniMax" },
                    { id: "vibe",  label: "Mistral Vibe" }
                ]

                Rectangle {
                    required property var modelData
                    readonly property bool isCurrent: win.activeAgent === modelData.id
                    implicitWidth: lbl.implicitWidth + 16
                    implicitHeight: 22
                    radius: 3
                    color: isCurrent ? Theme.blue : (tabMouse.containsMouse ? Theme.bgHover : Theme.bgAlt)
                    border.width: 1
                    border.color: isCurrent ? Theme.cyan : Theme.border

                    Text {
                        id: lbl
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.isCurrent ? Theme.bg : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                        font.bold: parent.isCurrent
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.activeAgent = parent.modelData.id;
                            win.runCmd("~/.config/hypr/scripts/quake-ai.sh set-agent " + parent.modelData.id);
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 68; implicitHeight: 22; radius: 3
                color: respMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
                border.width: 1; border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    text: "Respawn"
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                }
                MouseArea {
                    id: respMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: win.runCmd("~/.config/hypr/scripts/quake-ai.sh restart")
                }
            }

            Rectangle {
                implicitWidth: 92; implicitHeight: 22; radius: 3
                color: hideMouse.containsMouse ? Theme.red : Theme.bgAlt
                border.width: 1; border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    text: "Hide [Super+`]"
                    color: hideMouse.containsMouse ? Theme.bg : Theme.cyan
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                    font.bold: true
                }
                MouseArea {
                    id: hideMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: win.runCmd("~/.config/hypr/scripts/quake-ai.sh hide")
                }
            }
        }
    }
}
