import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// StatusNotifier tray. Left click activates, right click opens the app menu.
Row {
    id: root
    property var bar: null
    spacing: 4

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property SystemTrayItem modelData
            width: 20
            height: Theme.barHeight

            IconImage {
                anchors.centerIn: parent
                implicitSize: 15
                source: trayItem.modelData.icon
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: e => {
                    if (e.button === Qt.MiddleButton)
                        trayItem.modelData.secondaryActivate();
                    else if (e.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                        if (trayItem.modelData.hasMenu) menuAnchor.open();
                    } else
                        trayItem.modelData.activate();
                }
            }
        }
    }
}
