import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".."

// 16-bit Dock & Running App Strip for horizontal (top/bottom) or vertical (left/right) panels.
// Supports drag-to-reorder pinned items and smooth hover tracking across tiles.
GridLayout {
    id: root
    property bool vertical: false
    property int thickness: 48
    property int hoveredCount: 0
    property int draggingIndex: -1
    property string draggingId: ""
    property real dragStartPos: 0
    readonly property bool isInteracting: root.hoveredCount > 0 || root.draggingIndex >= 0

    columns: root.vertical ? 1 : 99
    rows: root.vertical ? 99 : 1
    rowSpacing: 6
    columnSpacing: 6

    readonly property var catalog: ({
        launcher: { id: "launcher", title: "App Launcher",     icon: "󰣛", match: "fuzzel",        cmd: "fuzzel" },
        terminal: { id: "terminal", title: "Terminal",         icon: "󰆍", match: "kitty|alacritty|foot|wezterm", cmd: "xdg-terminal-exec" },
        browser:  { id: "browser",  title: "Web Browser",      icon: "󰈹", match: "firefox|chromium|brave|zen|chrome", cmd: "gtk-launch \"$(xdg-settings get default-web-browser)\"" },
        files:    { id: "files",    title: "Files",            icon: "󰉋", match: "nautilus|thunar|dolphin|files", cmd: "gtk-launch \"$(xdg-mime query default inode/directory)\"" },
        editor:   { id: "editor",   title: "Code / Neovim",    icon: "󰨞", match: "code|codium|zed|nvim|neovide", cmd: "kitty -e nvim" },
        monitor:  { id: "monitor",  title: "Activity Monitor", icon: "󰍛", match: "btop",          cmd: "kitty --class floating-term -e btop" },
        panels:   { id: "panels",   title: "Panels & Dock",    icon: "󰕮", match: "__panels__",    action: "panels" },
        theme:    { id: "theme",    title: "16-Bit Theme",     icon: "󰏘", match: "__theme__",     cmd: "~/.config/hypr/scripts/wallpaper.sh next" }
    })

    readonly property var orderedPinned: {
        const order = Status.dockOrder || ["launcher", "terminal", "browser", "files", "editor", "monitor", "panels", "theme"];
        const list = [];
        const seen = {};
        for (const k of order) {
            if (root.catalog[k] && !seen[k]) {
                seen[k] = true;
                list.push(root.catalog[k]);
            }
        }
        for (const k in root.catalog) {
            if (!seen[k]) list.push(root.catalog[k]);
        }
        return list;
    }

    function movePinned(fromIdx, toIdx) {
        const current = root.orderedPinned.map(p => p.id);
        if (fromIdx < 0 || fromIdx >= current.length || toIdx < 0 || toIdx >= current.length || fromIdx === toIdx)
            return;
        const item = current.splice(fromIdx, 1)[0];
        current.splice(toIdx, 0, item);
        Status.saveDockOrder(current);
    }

    function classIcon(cls) {
        const c = (cls || "").toLowerCase();
        if (c.includes("kitty") || c.includes("term")) return "󰆍";
        if (c.includes("firefox") || c.includes("chrome") || c.includes("brave")) return "󰈹";
        if (c.includes("nautilus") || c.includes("thunar") || c.includes("files")) return "󰉋";
        if (c.includes("code") || c.includes("zed") || c.includes("nvim")) return "󰨞";
        if (c.includes("spotify") || c.includes("music") || c.includes("mpv")) return "󰎆";
        if (c.includes("discord") || c.includes("slack") || c.includes("signal")) return "󰙯";
        if (c.includes("steam") || c.includes("lutris")) return "󰓓";
        return "󰣆";
    }

    readonly property var items: {
        const out = [];
        const clients = Status.clients || [];
        const matchedAddrs = {};

        for (let i = 0; i < root.orderedPinned.length; i++) {
            const p = root.orderedPinned[i];
            const re = new RegExp(p.match, "i");
            const matches = clients.filter(c => re.test(c.class || "") || re.test(c.title || ""));
            for (const m of matches) matchedAddrs[m.address] = true;
            const focused = matches.some(m => m.focusHistoryID === 0);
            out.push({
                id: p.id,
                pinIdx: i,
                title: matches.length > 0 ? (matches[0].title || p.title) : p.title,
                icon: p.icon,
                count: matches.length,
                focused: focused || (p.action === "panels" && Status.settingsOpen),
                address: matches.length > 0 ? matches[0].address : "",
                cmd: p.cmd || "",
                action: p.action || ""
            });
        }

        for (const c of clients) {
            if (matchedAddrs[c.address]) continue;
            out.push({
                id: "win-" + c.address,
                pinIdx: -1,
                title: c.title || c.class || "Window",
                icon: root.classIcon(c.class),
                count: 1,
                focused: c.focusHistoryID === 0,
                address: c.address,
                cmd: "",
                action: ""
            });
        }
        return out;
    }

    Repeater {
        model: root.items

        Rectangle {
            id: tile
            required property var modelData
            required property int index
            readonly property int boxSize: Math.max(24, root.thickness - 10)
            readonly property bool isBeingDragged: root.draggingId !== "" && root.draggingId === modelData.id

            implicitWidth: tile.boxSize
            implicitHeight: tile.boxSize
            radius: 3
            scale: tile.isBeingDragged ? 1.08 : 1.0
            color: tile.isBeingDragged
                ? Theme.bgHover
                : (tileMouse.containsMouse ? Theme.bgHover : (modelData.focused ? Theme.bgAlt : "transparent"))
            border.width: tile.isBeingDragged || modelData.focused || tileMouse.containsMouse ? 2 : 1
            border.color: tile.isBeingDragged
                ? Theme.yellow
                : (modelData.focused ? Theme.blue : (tileMouse.containsMouse ? Theme.cyan : Theme.border))

            Text {
                anchors.centerIn: parent
                text: tile.modelData.icon
                color: tile.isBeingDragged
                    ? Theme.yellow
                    : (tile.modelData.focused ? Theme.cyan : (tile.modelData.count > 0 ? Theme.fg : Theme.fgDim))
                font.family: Theme.font
                font.pixelSize: Math.max(14, Math.round(tile.boxSize * 0.52))
            }

            Rectangle {
                visible: tile.modelData.count > 0
                width: tile.modelData.focused ? 12 : 5
                height: 3
                radius: 1
                color: tile.modelData.focused ? Theme.cyan : Theme.blue
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                anchors.horizontalCenter: parent.horizontalCenter
            }

            MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: root.draggingIndex >= 0 ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                property bool didDrag: false

                onContainsMouseChanged: {
                    root.hoveredCount = Math.max(0, root.hoveredCount + (containsMouse ? 1 : -1));
                }
                onPressed: e => {
                    tileMouse.didDrag = false;
                    if (e.button === Qt.LeftButton && tile.modelData.pinIdx >= 0) {
                        root.draggingIndex = tile.modelData.pinIdx;
                        root.draggingId = tile.modelData.id;
                        root.dragStartPos = root.vertical ? e.y : e.x;
                    }
                }
                onPositionChanged: e => {
                    if (root.draggingIndex < 0 || tile.modelData.pinIdx < 0) return;
                    const step = tile.boxSize + 6;
                    const delta = (root.vertical ? e.y : e.x) - root.dragStartPos;
                    if (Math.abs(delta) > step * 0.65) {
                        const dir = delta > 0 ? 1 : -1;
                        const targetIdx = Math.max(0, Math.min(root.orderedPinned.length - 1, root.draggingIndex + dir));
                        if (targetIdx !== root.draggingIndex) {
                            tileMouse.didDrag = true;
                            root.movePinned(root.draggingIndex, targetIdx);
                            root.draggingIndex = targetIdx;
                        }
                    }
                }
                onReleased: e => {
                    const wasDrag = tileMouse.didDrag;
                    root.draggingIndex = -1;
                    root.draggingId = "";
                    if (wasDrag) return;

                    const d = tile.modelData;
                    if (d.action === "panels") {
                        Status.settingsOpen = !Status.settingsOpen;
                    } else if (e.button === Qt.MiddleButton && d.address) {
                        Hyprland.dispatch("closewindow address:" + d.address);
                    } else if (e.button === Qt.RightButton && d.cmd) {
                        Quickshell.execDetached(["sh", "-c", d.cmd]);
                    } else if (d.address) {
                        Hyprland.dispatch("focuswindow address:" + d.address);
                    } else if (d.cmd) {
                        Quickshell.execDetached(["sh", "-c", d.cmd]);
                    }
                }
                onCanceled: {
                    root.draggingIndex = -1;
                    root.draggingId = "";
                }
            }
        }
    }
}
