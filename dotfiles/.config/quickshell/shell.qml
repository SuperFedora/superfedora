//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "panels"

// Entry point: multi-edge bars/docks per monitor + notification popups + OSD + Panel Studio.
ShellRoot {
    id: root
    property bool barVisible: true

    Variants {
        model: root.barVisible ? Quickshell.screens : []
        Bar {}
    }

    Variants {
        model: root.barVisible ? Quickshell.screens : []
        EdgePanel { edge: "bottom" }
    }

    Variants {
        model: root.barVisible ? Quickshell.screens : []
        EdgePanel { edge: "left" }
    }

    Variants {
        model: root.barVisible ? Quickshell.screens : []
        EdgePanel { edge: "right" }
    }

    PanelSettingsPopup {}
    Notifications {}
    Osd {}
    LockScreen {}

    // `qs ipc call bar toggle` (bound to SUPER+SHIFT+Space)
    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
    }

    IpcHandler {
        target: "ai"
        function toggle(): void { Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh toggle"]); }
        function setAgent(agent: string): void { Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh set-agent '" + agent + "'"]); }
    }
}
