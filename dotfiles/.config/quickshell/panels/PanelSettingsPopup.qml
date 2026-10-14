import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

// Interactive Multi-Edge Panels & Dock Configurator modal (<=256 lines).
PanelWindow {
    id: win
    property var targetScreen: Quickshell.screens[0]

    visible: Status.settingsOpen
    screen: win.targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true; bottom: true }

    MouseArea { anchors.fill: parent; onClicked: Status.settingsOpen = false }

    Rectangle {
        id: card
        width: 580
        implicitHeight: col.implicitHeight + 28
        anchors.centerIn: parent
        color: Theme.bg
        radius: Theme.radius
        border.width: 2
        border.color: Theme.blue

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            anchors { fill: parent; margins: 14 }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰕮  PANELS, DOCK & THEME STUDIO"
                    color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true
                }
                Rectangle {
                    implicitWidth: 64; implicitHeight: 24; radius: Theme.radiusSm; border.width: 1; border.color: Theme.border
                    color: resetMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
                    Text { anchors.centerIn: parent; text: "Reset"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                    MouseArea {
                        id: resetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["sh", "-c", "~/.local/bin/superfedora panel reset 2>/dev/null || ~/Projects/superfedora/superfedora/lib/panel-ctl.sh reset"])
                    }
                }
                Rectangle {
                    implicitWidth: 28; implicitHeight: 24; radius: Theme.radiusSm; color: closeMouse.containsMouse ? Theme.red : Theme.bgAlt
                    Text { anchors.centerIn: parent; text: "X"; color: closeMouse.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                    MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.settingsOpen = false }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: "CORNERS:"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                Repeater {
                    model: [
                        { id: "square",  label: "[90°] Square Corners", cmd: "~/.config/hypr/scripts/wallpaper.sh corners square" },
                        { id: "rounded", label: "( ) Rounded Edges",    cmd: "~/.config/hypr/scripts/wallpaper.sh corners rounded" },
                        { id: "color",   label: "Next 16-Bit Color",    cmd: "~/.config/hypr/scripts/wallpaper.sh next" },
                        { id: "mode",    label: "Dark / Light Mode",    cmd: "~/.config/hypr/scripts/wallpaper.sh toggle" }
                    ]
                    Rectangle {
                        required property var modelData
                        readonly property bool active: (modelData.id === "square" && Theme.corners === "square") || (modelData.id === "rounded" && Theme.corners === "rounded")
                        Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm
                        color: active ? Theme.bgHover : (cMouse.containsMouse ? Theme.bgHover : Theme.bgAlt)
                        border.width: active ? 2 : 1; border.color: active ? Theme.blue : (cMouse.containsMouse ? Theme.cyan : Theme.border)
                        Text { anchors.centerIn: parent; text: parent.modelData.label; color: parent.active ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: parent.active }
                        MouseArea { id: cMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["sh", "-c", parent.modelData.cmd]) }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: "PRESETS:"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                Repeater {
                    model: [
                        { id: "default",   label: "Top + Bottom Dock" },
                        { id: "top-only",  label: "Top Bar Only" },
                        { id: "dock-left", label: "Top + Left Dock" },
                        { id: "quad",      label: "All 4 Edges" }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm
                        color: pMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
                        border.width: 1; border.color: pMouse.containsMouse ? Theme.cyan : Theme.border
                        Text { anchors.centerIn: parent; text: parent.modelData.label; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                        MouseArea {
                            id: pMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["sh", "-c", "~/.local/bin/superfedora panel preset " + parent.modelData.id + " 2>/dev/null || ~/Projects/superfedora/superfedora/lib/panel-ctl.sh preset " + parent.modelData.id])
                        }
                    }
                }
            }

            Repeater {
                model: ["top", "bottom", "left", "right"]

                Rectangle {
                    id: edgeCard
                    required property string modelData
                    readonly property var cfg: (Status.panels && Status.panels[modelData]) ? Status.panels[modelData] : ({})
                    readonly property bool isOn: cfg.enabled === true
                    readonly property string span: cfg.span || "hug"
                    readonly property int pct: cfg.percent || 70
                    readonly property int thick: cfg.thickness || 40
                    readonly property string hide: cfg.hideMode || "never"

                    Layout.fillWidth: true; implicitHeight: edgeCol.implicitHeight + 16
                    radius: Theme.radiusSm; color: Theme.bgAlt
                    border.width: edgeCard.isOn ? 2 : 1; border.color: edgeCard.isOn ? Theme.blue : Theme.border

                    ColumnLayout {
                        id: edgeCol
                        anchors { fill: parent; margins: 8 }
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true; spacing: 6

                            Rectangle {
                                implicitWidth: 96; implicitHeight: 26; radius: Theme.radiusSm
                                color: edgeCard.isOn ? Theme.blue : Theme.bg
                                border.width: 1; border.color: edgeCard.isOn ? Theme.cyan : Theme.border
                                Text {
                                    anchors.centerIn: parent; text: (edgeCard.isOn ? "[ON] " : "[OFF] ") + edgeCard.modelData.toUpperCase()
                                    color: edgeCard.isOn ? Theme.bg : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.updatePanel(edgeCard.modelData, "enabled", edgeCard.isOn ? "false" : "true") }
                            }

                            Repeater {
                                model: [
                                    { k: "hug",  v: "hug",  l: "Hug Dock" },
                                    { k: "p65",  v: "65",   l: "65% Bar" },
                                    { k: "p85",  v: "85",   l: "85% Bar" },
                                    { k: "full", v: "full", l: "100% Full" }
                                ]
                                Rectangle {
                                    required property var modelData
                                    readonly property bool active: (modelData.k === "hug" && edgeCard.span === "hug")
                                        || (modelData.k === "full" && edgeCard.span === "full")
                                        || (modelData.k === "p65" && edgeCard.span === "percent" && edgeCard.pct <= 75)
                                        || (modelData.k === "p85" && edgeCard.span === "percent" && edgeCard.pct > 75)
                                    implicitWidth: 74; implicitHeight: 26; radius: Theme.radiusSm
                                    color: active ? Theme.bgHover : Theme.bg
                                    border.width: active ? 2 : 1; border.color: active ? Theme.cyan : Theme.border
                                    Text {
                                        anchors.centerIn: parent; text: parent.modelData.l
                                        color: parent.active ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: parent.active
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (parent.modelData.v === "hug" || parent.modelData.v === "full")
                                                Status.updatePanel(edgeCard.modelData, "span", parent.modelData.v);
                                            else
                                                Quickshell.execDetached(["sh", "-c", "~/.local/bin/superfedora panel set " + edgeCard.modelData + " span percent && ~/.local/bin/superfedora panel set " + edgeCard.modelData + " percent " + parent.modelData.v]);
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            RowLayout {
                                spacing: 4
                                Rectangle {
                                    implicitWidth: 24; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.border
                                    Text { anchors.centerIn: parent; text: "-"; color: Theme.fg; font.family: Theme.font; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.updatePanel(edgeCard.modelData, "thickness", String(Math.max(28, edgeCard.thick - 4))) }
                                }
                                Text { text: edgeCard.thick + "px"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                                Rectangle {
                                    implicitWidth: 24; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.border
                                    Text { anchors.centerIn: parent; text: "+"; color: Theme.fg; font.family: Theme.font; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.updatePanel(edgeCard.modelData, "thickness", String(Math.min(80, edgeCard.thick + 4))) }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "HIDE MODE:"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                            Repeater {
                                model: [
                                    { id: "never",      label: "Always Visible" },
                                    { id: "intellihide",label: "Intellihide (Smart)" },
                                    { id: "autohide",   label: "Autohide (Edge Hover)" }
                                ]
                                Rectangle {
                                    required property var modelData
                                    readonly property bool active: edgeCard.hide === modelData.id
                                    Layout.fillWidth: true; implicitHeight: 22; radius: Theme.radiusSm
                                    color: active ? Theme.bgHover : Theme.bg
                                    border.width: active ? 2 : 1; border.color: active ? Theme.blue : Theme.border
                                    Text {
                                        anchors.centerIn: parent; text: parent.modelData.label
                                        color: parent.active ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: parent.active
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Status.updatePanel(edgeCard.modelData, "hideMode", parent.modelData.id) }
                                }
                            }
                        }

                        RowLayout {
                            visible: edgeCard.modelData !== "top"
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "CONTENT:  "; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                            Repeater {
                                model: [
                                    { id: "hardware",           label: "Hardware Telemetry" },
                                    { id: "apps",               label: "Apps Dock" },
                                    { id: "workspaces,apps",    label: "Workspaces + Apps" },
                                    { id: "workspaces,hardware",label: "Workspaces + HW" }
                                ]
                                Rectangle {
                                    required property var modelData
                                    readonly property bool active: (edgeCard.cfg.center || []).join(",") === modelData.id
                                    Layout.fillWidth: true; implicitHeight: 22; radius: Theme.radiusSm
                                    color: active ? Theme.bgHover : Theme.bg
                                    border.width: active ? 2 : 1; border.color: active ? Theme.cyan : Theme.border
                                    Text {
                                        anchors.centerIn: parent; text: parent.modelData.label
                                        color: parent.active ? Theme.cyan : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: parent.active
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["sh", "-c", "~/.local/bin/superfedora panel set " + edgeCard.modelData + " start none && ~/.local/bin/superfedora panel set " + edgeCard.modelData + " end none && ~/.local/bin/superfedora panel set " + edgeCard.modelData + " center '" + parent.modelData.id + "'"])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
