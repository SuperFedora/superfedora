import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification daemon + top-right popups (replaces mako).
Scope {
    id: root
    property bool dnd: false

    // qs ipc call notifications dismiss|dismissAll|toggleDnd
    IpcHandler {
        target: "notifications"
        function dismiss(): void {
            const list = server.trackedNotifications.values;
            if (list.length > 0) list[list.length - 1].dismiss();
        }
        function dismissAll(): void {
            for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        }
        function toggleDnd(): void {
            root.dnd = !root.dnd;
            Quickshell.execDetached(["notify-send", "-a", "System", "-u", "critical",
                root.dnd ? "Do not disturb on" : "Do not disturb off"]);
        }
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            // In DND only critical notifications are shown
            n.tracked = !root.dnd || n.urgency === NotificationUrgency.Critical;
        }
    }

    PanelWindow {
        id: popup
        visible: server.trackedNotifications.values.length > 0
        screen: Quickshell.screens[0]
        color: "transparent"

        anchors {
            top: true
            right: true
        }
        margins {
            top: Theme.barHeight + 8
            right: 10
        }
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 360
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                Rectangle {
                    id: card
                    required property Notification modelData

                    Layout.fillWidth: true
                    implicitHeight: content.implicitHeight + 24
                    color: Theme.bg
                    border.width: 2
                    border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.red : Theme.blue

                    Timer {
                        running: card.modelData.urgency !== NotificationUrgency.Critical
                        interval: card.modelData.expireTimeout > 0 ? card.modelData.expireTimeout : 5000
                        onTriggered: card.modelData.expire()
                    }

                    RowLayout {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        IconImage {
                            readonly property string src: card.modelData.image || card.modelData.appIcon
                            visible: src !== ""
                            source: src.startsWith("/") ? "file://" + src : (src !== "" ? Quickshell.iconPath(src, true) : "")
                            implicitSize: 40
                            Layout.alignment: Qt.AlignTop
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: card.modelData.body
                                color: Theme.fgDim
                                font.family: Theme.font
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                            }
                            Text {
                                text: card.modelData.appName
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 10
                            }

                            Row {
                                visible: card.modelData.actions.length > 0
                                spacing: 6
                                Repeater {
                                    model: card.modelData.actions
                                    Rectangle {
                                        required property NotificationAction modelData
                                        width: actText.implicitWidth + 16
                                        height: 22
                                        color: actMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
                                        Text {
                                            id: actText
                                            anchors.centerIn: parent
                                            text: parent.modelData.text
                                            color: Theme.fg
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                        }
                                        MouseArea {
                                            id: actMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: parent.modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Click the card body to dismiss
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: card.modelData.dismiss()
                    }
                }
            }
        }
    }
}
