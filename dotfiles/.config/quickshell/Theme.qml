pragma Singleton

import QtQuick
import Quickshell

// Tokyo Night palette + bar metrics shared by every component.
Singleton {
    readonly property color bg: "#1a1b26"
    readonly property color bgAlt: "#24283b"
    readonly property color bgHover: "#292e42"
    readonly property color border: "#414868"
    readonly property color fg: "#c0caf5"
    readonly property color fgDim: "#a9b1d6"
    readonly property color muted: "#565f89"
    readonly property color blue: "#7aa2f7"
    readonly property color cyan: "#7dcfff"
    readonly property color green: "#9ece6a"
    readonly property color yellow: "#e0af68"
    readonly property color orange: "#ff9e64"
    readonly property color red: "#f7768e"
    readonly property color magenta: "#bb9af7"

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12
    readonly property int iconSize: 14
    readonly property int barHeight: 26
    readonly property int pad: 10
}
