import QtQuick
import Quickshell.Hyprland

// Omarchy-style workspaces: 1–5 always shown, extra ones appear when used.
Row {
    id: root
    property var monitor: null
    spacing: 0

    readonly property var occupied: {
        const ids = {};
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0) ids[ws.id] = true;
        return ids;
    }

    readonly property var shown: {
        const list = [1, 2, 3, 4, 5];
        for (const id in occupied)
            if (!list.includes(Number(id))) list.push(Number(id));
        return list.sort((a, b) => a - b);
    }

    readonly property int activeId: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.id
        : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    Repeater {
        model: root.shown

        Item {
            required property int modelData
            readonly property bool active: modelData === root.activeId
            readonly property bool used: root.occupied[modelData] === true

            width: 22
            height: Theme.barHeight

            Text {
                anchors.centerIn: parent
                text: parent.active ? "󱓻" : String(parent.modelData)
                color: parent.active ? Theme.blue : (parent.used ? Theme.fg : Theme.muted)
                font.family: Theme.font
                font.pixelSize: parent.active ? Theme.iconSize : Theme.fontSize
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + parent.modelData)
            }
        }
    }

    // Scroll anywhere on the strip to move between workspaces
    WheelHandler {
        onWheel: e => Hyprland.dispatch(e.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
    }
}
