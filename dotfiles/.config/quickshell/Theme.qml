pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property color bg: "#1a1b26"
    property color bgAlt: "#24283b"
    property color bgHover: "#292e42"
    property color border: "#414868"
    property color fg: "#c0caf5"
    property color fgDim: "#a9b1d6"
    property color muted: "#565f89"
    property color blue: "#7aa2f7"
    property color cyan: "#bcd3ff"
    readonly property color green: "#9ece6a"
    readonly property color yellow: "#e0af68"
    readonly property color orange: "#ff9e64"
    readonly property color red: "#f7768e"
    readonly property color magenta: "#bb9af7"
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14
    readonly property int iconSize: 18
    readonly property int barHeight: 36
    readonly property int pad: 14

    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.config/superfedora/quickshell-theme.json"
    }

    function reload(): void {
        themeFile.reload();
        const raw = themeFile.text().trim();
        if (!raw) return;
        try {
            const d = JSON.parse(raw);
            if (d.bg) root.bg = d.bg;
            if (d.bgAlt) root.bgAlt = d.bgAlt;
            if (d.bgHover) root.bgHover = d.bgHover;
            if (d.border) root.border = d.border;
            if (d.fg) root.fg = d.fg;
            if (d.fgDim) root.fgDim = d.fgDim;
            if (d.muted) root.muted = d.muted;
            if (d.blue) root.blue = d.blue;
            if (d.cyan) root.cyan = d.cyan;
        } catch (e) {}
    }

    Component.onCompleted: root.reload()

    IpcHandler {
        target: "theme"
        function reload(): void { root.reload(); }
    }
}
