import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// COSMIC DE dynamic workspaces:
// - Occupied workspaces compact to 1..N with zero empty gaps in between.
// - Workspace N+1 is always shown at the end as the trailing empty workspace.
Grid {
    id: root
    property var monitor: null
    property bool vertical: false
    property int thickness: Theme.barHeight
    property int occupiedCount: 1
    columns: root.vertical ? 1 : Math.max(1, root.shown.length)
    spacing: 0

    readonly property int activeId: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.id
        : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    readonly property var shown: {
        const total = Math.max(root.occupiedCount + 1, root.activeId, 1);
        const list = [];
        for (let i = 1; i <= total; i++) list.push(i);
        return list;
    }

    Process {
        id: compactProc
        command: ["bash", "-c",
            "clients=\"$(hyprctl clients -j 2>/dev/null)\" || exit 0\n" +
            "active=\"$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')\"\n" +
            "mapfile -t occ < <(jq -r '[.[] | select(.workspace.id > 0 and .mapped) | .workspace.id] | unique | .[]' <<<\"$clients\")\n" +
            "n=\"${#occ[@]}\"\n" +
            "batch=\"\"\n" +
            "target_active=\"$active\"\n" +
            "shifted_into_active=0\n" +
            "for i in \"${!occ[@]}\"; do\n" +
            "    old=\"${occ[$i]}\"\n" +
            "    new=$((i + 1))\n" +
            "    if [ \"$old\" -ne \"$new\" ]; then\n" +
            "        while IFS= read -r addr; do\n" +
            "            [ -n \"$addr\" ] && batch+=\"dispatch movetoworkspacesilent ${new},address:${addr};\"\n" +
            "        done < <(jq -r --argjson w \"$old\" '.[] | select(.workspace.id == $w and .mapped) | .address' <<<\"$clients\")\n" +
            "        [ \"$active\" -eq \"$old\" ] && target_active=\"$new\"\n" +
            "        [ \"$active\" -eq \"$new\" ] && shifted_into_active=1\n" +
            "    fi\n" +
            "done\n" +
            "max_ws=$((n + 1))\n" +
            "[ \"$target_active\" -gt \"$max_ws\" ] && target_active=\"$max_ws\"\n" +
            "if [ \"$target_active\" -ne \"$active\" ] || [ \"$shifted_into_active\" -eq 1 ]; then\n" +
            "    batch+=\"dispatch workspace ${target_active};\"\n" +
            "fi\n" +
            "[ -n \"$batch\" ] && hyprctl --batch \"$batch\" >/dev/null 2>&1\n" +
            "echo \"$n\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim(), 10);
                if (!isNaN(n) && n >= 0) root.occupiedCount = n;
            }
        }
    }

    Timer {
        id: syncTimer
        interval: 60
        running: true
        repeat: false
        onTriggered: compactProc.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const e = event.name;
            if (e === "openwindow" || e === "closewindow" || e === "movewindow" ||
                e === "movewindowv2" || e === "workspace" || e === "workspacev2" ||
                e === "destroyworkspace" || e === "destroyworkspacev2") {
                syncTimer.restart();
            }
        }
    }

    Repeater {
        model: root.shown

        Item {
            required property int modelData
            readonly property bool active: modelData === root.activeId
            readonly property bool used: modelData <= root.occupiedCount
            readonly property bool isTrailingEmpty: modelData === root.occupiedCount + 1 && !used

            width: root.vertical ? root.thickness : 28
            height: root.vertical ? 28 : root.thickness

            Text {
                anchors.centerIn: parent
                text: parent.active ? "󱓻" : (parent.isTrailingEmpty ? "+" : String(parent.modelData))
                color: parent.active ? Theme.blue : (parent.used ? Theme.fg : Theme.muted)
                font.family: Theme.font
                font.pixelSize: parent.active ? Theme.iconSize : Theme.fontSize
                font.bold: parent.isTrailingEmpty
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + parent.modelData)
            }
        }
    }

    // Scroll anywhere on the strip to move between workspaces (including trailing empty)
    WheelHandler {
        onWheel: e => {
            if (e.angleDelta.y > 0) {
                if (root.activeId > 1) Hyprland.dispatch("workspace r-1");
            } else {
                if (root.activeId <= root.occupiedCount) Hyprland.dispatch("workspace r+1");
            }
        }
    }
}
