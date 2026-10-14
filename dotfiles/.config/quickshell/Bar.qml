import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "panels"

// Omarchy-style top bar: menu + workspaces | clock | tray + status.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    readonly property var topCfg: (Status.panels && Status.panels.top) ? Status.panels.top : ({
        enabled: true, span: "full", percent: 100, thickness: 36, hideMode: "never"
    })
    readonly property bool isFull: (topCfg.span || "full") === "full"
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property int activeWsId: hyprMonitor && hyprMonitor.activeWorkspace
        ? hyprMonitor.activeWorkspace.id
        : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
    readonly property bool wsHasWindows: (Status.clients || []).some(c => c.workspace && c.workspace.id === bar.activeWsId)

    visible: (topCfg.enabled !== false) && (
        (topCfg.hideMode || "never") === "never" ||
        Status.settingsOpen ||
        launcherMenu.open || calendarPopup.mode !== "" || statusPopup.tab !== "" ||
        ((topCfg.hideMode === "intellihide") && !bar.wsHasWindows)
    )

    anchors { top: true; left: bar.isFull; right: bar.isFull }
    margins.top: bar.isFull ? 0 : 4
    exclusionMode: (bar.isFull && (topCfg.hideMode || "never") === "never") ? ExclusionMode.Auto : ExclusionMode.Ignore
    implicitWidth: bar.isFull
        ? modelData.width
        : ((topCfg.span === "percent")
            ? Math.round(modelData.width * ((topCfg.percent || 85) / 100.0))
            : (leftRow.implicitWidth + centerClock.implicitWidth + rightRow.implicitWidth + 64))
    implicitHeight: topCfg.thickness || Theme.barHeight
    color: Theme.bg

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    function toggleLauncher() {
        const next = !launcherMenu.open;
        calendarPopup.mode = "";
        statusPopup.tab = "";
        launcherMenu.open = next;
    }

    function toggleCenter(targetMode) {
        launcherMenu.open = false;
        statusPopup.tab = "";
        if (calendarPopup.mode === targetMode) calendarPopup.mode = "";
        else {
            if (targetMode === "date") calendarPopup.resetToToday();
            else Status.refresh();
            calendarPopup.mode = targetMode;
        }
    }

    function toggleStatus(tabName, item) {
        launcherMenu.open = false;
        calendarPopup.mode = "";
        if (statusPopup.tab === tabName) statusPopup.tab = "";
        else {
            const pt = item.mapToItem(null, 0, 0);
            statusPopup.rightOffset = Math.max(6, Math.round(bar.width - (pt.x + item.width)));
            Status.refresh();
            statusPopup.tab = tabName;
        }
    }

    LauncherMenu { id: launcherMenu; targetScreen: bar.modelData }
    Calendar { id: calendarPopup; targetScreen: bar.modelData }
    StatusPopup { id: statusPopup; targetScreen: bar.modelData }
    AiPopup { id: aiPopup; targetScreen: bar.modelData; open: statusPopup.tab === "ai"; rightOffset: statusPopup.rightOffset; onCloseRequested: statusPopup.tab = "" }

    // ---------------- Left ----------------
    RowLayout {
        id: leftRow
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 }
        spacing: 0

        BarLabel {
            text: "󰣛"
            color: launcherMenu.open ? Theme.cyan : Theme.blue
            pixelSize: Theme.iconSize + 2
            onClicked: bar.toggleLauncher()
            onRightClicked: bar.run("fuzzel")
        }

        Workspaces { monitor: bar.hyprMonitor; thickness: bar.implicitHeight }

        BarLabel {
            id: modeLabel
            property string mode: ""
            visible: mode !== ""
            text: "󰌌 " + mode.toUpperCase() + "  ·  Esc to exit"
            color: Theme.yellow
            pixelSize: Theme.fontSize
            bold: true
            onClicked: Hyprland.dispatch("submap reset")
            Connections {
                target: Hyprland
                function onRawEvent(event) { if (event.name === "submap") modeLabel.mode = event.data; }
            }
        }
    }

    // ---------------- Center ----------------
    RowLayout {
        id: centerClock
        anchors.centerIn: parent
        spacing: 8
        property date now: new Date()

        Timer { interval: 1000; running: true; repeat: true; onTriggered: centerClock.now = new Date() }

        BarLabel {
            pixelSize: Theme.fontSize
            bold: true
            color: calendarPopup.mode === "date" ? Theme.blue : Theme.fg
            text: Qt.formatDateTime(centerClock.now, "ddd, MMM d")
            onClicked: bar.toggleCenter("date")
        }

        BarLabel {
            pixelSize: Theme.fontSize
            bold: true
            color: calendarPopup.mode === "time" ? Theme.blue : Theme.fg
            text: {
                const fmt = Status.clock24h
                    ? (Status.clockSeconds ? "HH:mm:ss" : "HH:mm")
                    : (Status.clockSeconds ? "h:mm:ss AP" : "h:mm AP");
                return Qt.formatDateTime(centerClock.now, fmt);
            }
            onClicked: bar.toggleCenter("time")
            onRightClicked: Status.saveClockPrefs(!Status.clock24h, Status.clockSeconds)
        }
    }

    // ---------------- Right ----------------
    RowLayout {
        id: rightRow
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
        spacing: 0

        Tray { bar: bar; Layout.rightMargin: 6 }

        BarLabel {
            id: aiBtn
            text: "󰚩"
            color: statusPopup.tab === "ai" ? Theme.blue : Theme.cyan
            onClicked: bar.toggleStatus("ai", aiBtn)
            onRightClicked: { statusPopup.tab = ""; bar.run("~/.config/hypr/scripts/quake-ai.sh toggle"); }
        }

        BarLabel {
            text: "󰕮"
            color: Status.settingsOpen ? Theme.cyan : Theme.fgDim
            onClicked: Status.settingsOpen = !Status.settingsOpen
            onRightClicked: bar.run("~/.local/bin/superfedora panel toggle bottom")
        }

        BarLabel {
            visible: !Status.idleEnabled
            text: "󰅶"
            color: Theme.yellow
            onClicked: { bar.run("~/.config/hypr/scripts/toggle-idle.sh"); Status.refresh(); }
        }

        BarLabel {
            id: btBtn
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property int connected: Bluetooth.devices.values.filter(d => d.connected).length
            visible: adapter !== null
            text: !adapter || !adapter.enabled ? "󰂲" : (connected > 0 ? "󰂱" : "󰂯")
            color: statusPopup.tab === "bluetooth" ? Theme.blue : (adapter && adapter.enabled ? Theme.fg : Theme.muted)
            onClicked: bar.toggleStatus("bluetooth", btBtn)
            onRightClicked: bar.run("PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e bluetui")
        }

        BarLabel {
            id: netBtn
            text: {
                if (Status.netType === "ethernet") return "󰀂";
                if (Status.netType !== "wifi") return "󰤮";
                const s = Status.signal;
                return s >= 80 ? "󰤨" : s >= 60 ? "󰤥" : s >= 40 ? "󰤢" : s >= 20 ? "󰤟" : "󰤯";
            }
            color: statusPopup.tab === "network" ? Theme.blue : (Status.netType === "none" ? Theme.muted : Theme.fg)
            onClicked: bar.toggleStatus("network", netBtn)
            onRightClicked: bar.run("PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wlctl")
        }

        BarLabel {
            id: audioBtn
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property bool ready: sink !== null && sink.audio !== null
            readonly property real vol: ready ? sink.audio.volume : 0
            readonly property bool muted: ready ? sink.audio.muted : true
            text: muted ? "󰝟" : vol >= 0.66 ? "󰕾" : vol >= 0.33 ? "󰖀" : "󰕿"
            color: statusPopup.tab === "audio" ? Theme.blue : (muted ? Theme.muted : Theme.fg)
            onClicked: bar.toggleStatus("audio", audioBtn)
            onRightClicked: bar.run("PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wiremix")
            onScrolled: delta => {
                if (ready) sink.audio.volume = Math.max(0, Math.min(1, vol + (delta > 0 ? 0.05 : -0.05)));
            }
        }

        BarLabel {
            id: cpuBtn
            text: "󰍛"
            color: statusPopup.tab === "cpu" ? Theme.blue : (Status.cpu >= 80 ? Theme.red : Theme.fg)
            onClicked: bar.toggleStatus("cpu", cpuBtn)
            onRightClicked: bar.run("kitty --class floating-term -e btop")
        }

        BarLabel {
            id: batBtn
            readonly property var dev: UPower.displayDevice
            readonly property bool present: dev !== null && dev.isLaptopBattery
            readonly property int pct: present ? Math.round(dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 0
            readonly property bool charging: present
                && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
            visible: present
            text: charging ? "󰂄" : ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][Math.min(10, Math.floor(pct / 10))]
            color: statusPopup.tab === "battery" ? Theme.blue : (charging ? Theme.green : pct <= 15 ? Theme.red : pct <= 30 ? Theme.yellow : Theme.fg)
            onClicked: bar.toggleStatus("battery", batBtn)
            onRightClicked: bar.run("kitty --class floating-term -e btop")
        }

        BarLabel {
            id: powerBtn
            text: "󰐥"
            color: statusPopup.tab === "power" ? Theme.orange : Theme.red
            onClicked: bar.toggleStatus("power", powerBtn)
            onRightClicked: bar.run("~/.config/hypr/scripts/menu.sh system")
        }
    }
}
