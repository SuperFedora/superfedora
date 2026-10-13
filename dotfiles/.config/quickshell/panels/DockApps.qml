import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".."

// 16-bit Dock & Running App Strip for horizontal (top/bottom) or vertical (left/right) panels.
GridLayout {
    id: root
    property bool vertical: false
    property int thickness: 48
    signal hoveredChanged(bool isHovered)

    columns: root.vertical ? 1 : 99
    rows: root.vertical ? 99 : 1
    rowSpacing: 6
    columnSpacing: 6

    readonly property var pinned: [
        { id: "launcher", title: "App Launcher",     icon: "󰣛", match: "fuzzel",        cmd: "fuzzel" },
        { id: "terminal", title: "Terminal",         icon: "󰆍", match: "kitty|alacritty|foot|wezterm", cmd: "xdg-terminal-exec" },
        { id: "browser",  title: "Web Browser",      icon: "󰈹", match: "firefox|chromium|brave|zen|chrome", cmd: "gtk-launch \"$(xdg-settings get default-web-browser)\"" },
        { id: "files",    title: "Files",            icon: "󰉋", match: "nautilus|thunar|dolphin|files", cmd: "gtk-launch \"$(xdg-mime query default inode/directory)\"" },
        { id: "editor",   title: "Code / Neovim",    icon: "󰨞", match: "code|codium|zed|nvim|neovide", cmd: "kitty -e nvim" },
        { id: "monitor",  title: "Activity Monitor", icon: "󰍛", match: "btop",          cmd: "kitty --class floating-term -e btop" },
        { id: "panels",   title: "Panels & Dock",    icon: "󰕮", match: "__panels__",    action: "panels" },
        { id: "theme",    title: "16-Bit Theme",     icon: "󰏘", match: "__theme__",     cmd: "~/.config/hypr/scripts/wallpaper.sh next" }
    ]

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

        for (const p of root.pinned) {
            const re = new RegExp(p.match, "i");
            const matches = clients.filter(c => re.test(c.class || "") || re.test(c.title || ""));
            for (const m of matches) matchedAddrs[m.address] = true;
            const focused = matches.some(m => m.focusHistoryID === 0);
            out.push({
                title: matches.length > 0 ? (matches[0].title || p.title) : p.title,
                icon: p.iconText || p.icon,
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
            readonly property int boxSize: Math.max(24, root.thickness - 10)

            implicitWidth: tile.boxSize
            implicitHeight: tile.boxSize
            radius: 3
            color: tileMouse.containsMouse
                ? Theme.bgHover
                : (modelData.focused ? Theme.bgAlt : "transparent")
            border.width: modelData.focused || tileMouse.containsMouse ? 2 : 1
            border.color: modelData.focused
                ? Theme.blue
                : (tileMouse.containsMouse ? Theme.cyan : Theme.border)

            Text {
                anchors.centerIn: parent
                text: tile.modelData.icon
                color: tile.modelData.focused
                    ? Theme.cyan
                    : (tile.modelData.count > 0 ? Theme.fg : Theme.fgDim)
                font.family: Theme.font
                font.pixelSize: Math.max(14, Math.round(tile.boxSize * 0.52))
            }

            // Active running window indicator pip
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
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredChanged(true)
                onExited: root.hoveredChanged(false)
                onClicked: e => {
                    const d = tile.modelData;
                    if (d.action === "panels") {
                        Status.settingsOpen = !Status.settingsOpen;
                        return;
                    }
                    if (e.button === Qt.MiddleButton && d.address) {
                        Hyprland.dispatch("closewindow address:" + d.address);
                        return;
                    }
                    if (e.button === Qt.RightButton && d.cmd) {
                        Quickshell.execDetached(["sh", "-c", d.cmd]);
                        return;
                    }
                    if (d.address) {
                        Hyprland.dispatch("focuswindow address:" + d.address);
                    } else if (d.cmd) {
                        Quickshell.execDetached(["sh", "-c", d.cmd]);
                    }
                }
            }
        }
    }
}
