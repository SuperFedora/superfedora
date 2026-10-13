//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io

// Entry point: one bar per monitor + notification popups + OSD.
ShellRoot {
    id: root
    property bool barVisible: true

    Variants {
        model: root.barVisible ? Quickshell.screens : []
        Bar {}
    }

    Notifications {}
    Osd {}

    // `qs ipc call bar toggle` (bound to SUPER+SHIFT+Space)
    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
    }
}
