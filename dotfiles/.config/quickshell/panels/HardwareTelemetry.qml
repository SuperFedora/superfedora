import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

// 16-Bit Localhost Hardware Telemetry Strip for Left/Right/Bottom/Top docks.
// Displays CPU %, GPU %, Memory %, Temperature (C), and Network Throughput (RX/TX).
GridLayout {
    id: root
    property bool vertical: true
    property int thickness: 56

    columns: root.vertical ? 1 : 99
    rows: root.vertical ? 99 : 1
    rowSpacing: 6
    columnSpacing: 6

    function fmtRate(kbps) {
        if (kbps >= 1024) return (kbps / 1024).toFixed(1) + "M";
        return Math.round(kbps) + "K";
    }

    readonly property var metrics: [
        {
            id: "cpu",
            icon: "󰍛",
            label: "CPU",
            val: Status.cpu + "%",
            pct: Status.cpu / 100.0,
            color: Status.cpu >= 85 ? Theme.red : (Status.cpu >= 60 ? Theme.yellow : Theme.blue)
        },
        {
            id: "gpu",
            icon: "󰢮",
            label: "GPU",
            val: Status.gpu + "%",
            pct: Status.gpu / 100.0,
            color: Status.gpu >= 85 ? Theme.red : (Status.gpu >= 60 ? Theme.yellow : Theme.cyan)
        },
        {
            id: "mem",
            icon: "󰘚",
            label: "RAM",
            val: Status.mem + "%",
            pct: Status.mem / 100.0,
            color: Status.mem >= 85 ? Theme.red : (Status.mem >= 70 ? Theme.yellow : Theme.green)
        },
        {
            id: "temp",
            icon: "󰔏",
            label: "TMP",
            val: Status.tempC + "°C",
            pct: Math.min(1.0, Math.max(0.0, (Status.tempC - 30) / 65.0)),
            color: Status.tempC >= 80 ? Theme.red : (Status.tempC >= 65 ? Theme.orange : Theme.yellow)
        },
        {
            id: "rx",
            icon: "󰇚",
            label: "NET↓",
            val: root.fmtRate(Status.netRxKbps),
            pct: Math.min(1.0, Status.netRxKbps / 10240.0),
            color: Theme.cyan
        },
        {
            id: "tx",
            icon: "󰕒",
            label: "NET↑",
            val: root.fmtRate(Status.netTxKbps),
            pct: Math.min(1.0, Status.netTxKbps / 5120.0),
            color: Theme.magenta
        }
    ]

    Repeater {
        model: root.metrics

        Rectangle {
            id: card
            required property var modelData
            readonly property int boxW: root.vertical ? Math.max(42, root.thickness - 8) : 64
            readonly property int boxH: root.vertical ? 50 : Math.max(32, root.thickness - 8)

            implicitWidth: card.boxW
            implicitHeight: card.boxH
            radius: Theme.radiusSm
            color: cardMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
            border.width: 1
            border.color: cardMouse.containsMouse ? card.modelData.color : Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 1

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 3
                    Text {
                        text: card.modelData.icon
                        color: card.modelData.color
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    Text {
                        text: card.modelData.label
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: card.modelData.val
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                }

                // 16-bit progress bar gauge
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 1
                    color: Theme.bg
                    Rectangle {
                        width: Math.max(2, Math.round(parent.width * Math.max(0, Math.min(1, card.modelData.pct))))
                        height: parent.height
                        radius: 1
                        color: card.modelData.color
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["sh", "-c", "kitty --class floating-term -e btop"])
            }
        }
    }
}
