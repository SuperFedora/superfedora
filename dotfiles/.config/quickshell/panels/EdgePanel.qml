import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".."

// Universal Multi-Edge Panel & Dock Window for bottom, left, and right screen edges.
// Supports independent on/off, length (full / percent / hug), thickness, and hideMode (never / intellihide / autohide).
Scope {
    id: scope
    required property var modelData
    required property string edge // "bottom" | "left" | "right"

    readonly property bool isVert: scope.edge === "left" || scope.edge === "right"
    readonly property var cfg: (Status.panels && Status.panels[scope.edge]) ? Status.panels[scope.edge] : ({
        enabled: scope.edge === "bottom",
        span: "hug",
        percent: 65,
        thickness: scope.isVert ? 58 : 52,
        hideMode: scope.isVert ? "never" : "intellihide",
        start: [],
        center: [scope.isVert ? "hardware" : "apps"],
        end: []
    })

    readonly property bool enabled: cfg.enabled === true
    readonly property string span: cfg.span || "hug"
    readonly property int pct: cfg.percent || 65
    readonly property int thickness: cfg.thickness || 48
    readonly property string hideMode: cfg.hideMode || "intellihide"
    readonly property var hyprMon: Hyprland.monitorFor(scope.modelData)

    readonly property int activeWsId: hyprMon && hyprMon.activeWorkspace
        ? hyprMon.activeWorkspace.id
        : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    readonly property bool wsHasWindows: {
        const list = Status.clients || [];
        return list.some(c => c.workspace && c.workspace.id === scope.activeWsId);
    }

    property bool sensorHovered: false
    property bool keepRevealed: false
    readonly property bool activelyHovered: scope.sensorHovered
        || winHover.hovered
        || dockApps.isInteracting
        || Status.settingsOpen

    onActivelyHoveredChanged: {
        if (scope.activelyHovered) {
            scope.keepRevealed = true;
            hideDelay.stop();
        } else {
            hideDelay.restart();
        }
    }

    Timer {
        id: hideDelay
        interval: 1600
        repeat: false
        onTriggered: {
            if (!scope.activelyHovered)
                scope.keepRevealed = false;
        }
    }

    readonly property bool shouldShow: {
        if (!scope.enabled) return false;
        if (scope.hideMode === "never") return true;
        if (scope.activelyHovered || scope.keepRevealed) return true;
        if (scope.hideMode === "intellihide") return !scope.wsHasWindows;
        return false; // autohide
    }

    // 1. Screen-edge hover sensor when hidden in intellihide / autohide mode
    PanelWindow {
        id: edgeSensor
        screen: scope.modelData
        visible: scope.enabled && scope.hideMode !== "never" && !scope.shouldShow
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            bottom: scope.edge === "bottom"
            left: scope.edge === "left" || scope.edge === "bottom"
            right: scope.edge === "right" || scope.edge === "bottom"
            top: scope.edge === "left" || scope.edge === "right"
        }
        implicitWidth: scope.isVert ? 6 : 320
        implicitHeight: scope.isVert ? 320 : 6

        HoverHandler {
            id: sensorHover
            onHoveredChanged: scope.sensorHovered = sensorHover.hovered
        }
    }

    // 2. Main Panel / Dock Window
    PanelWindow {
        id: win
        screen: scope.modelData
        visible: scope.shouldShow
        color: "transparent"
        exclusionMode: (scope.hideMode === "never" && scope.span === "full")
            ? ExclusionMode.Auto
            : ExclusionMode.Ignore

        anchors {
            bottom: scope.edge === "bottom"
            left: scope.edge === "left" || (scope.edge === "bottom" && scope.span === "full")
            right: scope.edge === "right" || (scope.edge === "bottom" && scope.span === "full")
            top: (scope.edge === "left" || scope.edge === "right") && scope.span === "full"
        }

        margins {
            bottom: scope.edge === "bottom" && scope.span !== "full" ? 6 : 0
            left: scope.edge === "left" && scope.span !== "full" ? 6 : 0
            right: scope.edge === "right" && scope.span !== "full" ? 6 : 0
        }

        readonly property int screenLen: scope.isVert ? scope.modelData.height : scope.modelData.width
        readonly property int targetLen: {
            if (scope.span === "full") return win.screenLen;
            if (scope.span === "percent") return Math.round(win.screenLen * (scope.pct / 100.0));
            return (scope.isVert ? contentGrid.implicitHeight : contentGrid.implicitWidth) + 20;
        }

        implicitWidth: scope.isVert ? scope.thickness : Math.max(64, win.targetLen)
        implicitHeight: scope.isVert ? Math.max(64, win.targetLen) : scope.thickness

        Rectangle {
            id: surface
            anchors.fill: parent
            color: Theme.bg
            radius: scope.span === "full" ? 0 : 4
            border.width: scope.span === "full" ? 0 : 2
            border.color: Theme.blue

            // Non-blocking HoverHandler tracks the cursor across the entire dock and all child tiles simultaneously
            HoverHandler {
                id: winHover
            }

            GridLayout {
                id: contentGrid
                anchors.centerIn: parent
                columns: scope.isVert ? 1 : 99
                rows: scope.isVert ? 99 : 1
                rowSpacing: 8
                columnSpacing: 8

                readonly property var allSlots: {
                    const s = scope.cfg.start || [];
                    const c = scope.cfg.center || [];
                    const e = scope.cfg.end || [];
                    return s.concat(c).concat(e);
                }

                BarLabel {
                    visible: contentGrid.allSlots.includes("launcher")
                    text: "󰣛"
                    color: Theme.blue
                    pixelSize: Theme.iconSize + 2
                    onClicked: Quickshell.execDetached(["sh", "-c", "fuzzel"])
                }

                Workspaces {
                    visible: contentGrid.allSlots.includes("workspaces")
                    monitor: scope.hyprMon
                    vertical: scope.isVert
                    thickness: scope.thickness - 8
                }

                HardwareTelemetry {
                    visible: contentGrid.allSlots.includes("hardware")
                    vertical: scope.isVert
                    thickness: scope.thickness
                }

                DockApps {
                    id: dockApps
                    visible: contentGrid.allSlots.includes("apps")
                    vertical: scope.isVert
                    thickness: scope.thickness
                }

                BarLabel {
                    visible: contentGrid.allSlots.includes("theme")
                    text: "󰏘"
                    color: Theme.cyan
                    onClicked: Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/wallpaper.sh next"])
                    onRightClicked: Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/wallpaper.sh toggle"])
                }

                BarLabel {
                    visible: contentGrid.allSlots.includes("status")
                    text: "󰕮"
                    color: Status.settingsOpen ? Theme.cyan : Theme.fg
                    onClicked: Status.settingsOpen = !Status.settingsOpen
                }
            }
        }
    }
}
