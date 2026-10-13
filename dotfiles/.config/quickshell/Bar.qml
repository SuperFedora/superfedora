import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth

// Omarchy-style top bar: menu + workspaces | clock | tray + status.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.bg

    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    function toggleLauncher() {
        const next = !launcherMenu.open;
        calendarPopup.open = false;
        statusPopup.tab = "";
        launcherMenu.open = next;
    }

    function toggleCalendar() {
        const next = !calendarPopup.open;
        launcherMenu.open = false;
        statusPopup.tab = "";
        if (next) calendarPopup.resetToToday();
        calendarPopup.open = next;
    }

    function toggleStatus(tabName, item) {
        launcherMenu.open = false;
        calendarPopup.open = false;
        if (statusPopup.tab === tabName) {
            statusPopup.tab = "";
        } else {
            const pt = item.mapToItem(null, 0, 0);
            statusPopup.rightOffset = Math.max(6, Math.round(bar.width - (pt.x + item.width)));
            Status.refresh();
            statusPopup.tab = tabName;
        }
    }

    LauncherMenu {
        id: launcherMenu
        targetScreen: bar.modelData
    }

    Calendar {
        id: calendarPopup
        targetScreen: bar.modelData
    }

    StatusPopup {
        id: statusPopup
        targetScreen: bar.modelData
    }

    // ---------------- Left ----------------
    RowLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 4
        spacing: 0

        BarLabel {
            text: "󰣛"
            color: launcherMenu.open ? Theme.cyan : Theme.blue
            pixelSize: Theme.iconSize + 2
            onClicked: bar.toggleLauncher()
            onRightClicked: bar.run("fuzzel")
        }

        Workspaces {
            monitor: bar.hyprMonitor
        }

        // Shows SWAP / RESIZE while SUPER+X or SUPER+R mode is active
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
                function onRawEvent(event) {
                    if (event.name === "submap") modeLabel.mode = event.data;
                }
            }
        }
    }

    // ---------------- Center ----------------
    BarLabel {
        id: clock
        anchors.centerIn: parent
        property date now: new Date()
        pixelSize: Theme.fontSize
        bold: true
        color: calendarPopup.open ? Theme.blue : Theme.fg
        text: Qt.formatDateTime(now, "ddd, MMM d  ·  HH:mm")
        onClicked: bar.toggleCalendar()

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.now = new Date()
        }
    }

    // ---------------- Right ----------------
    RowLayout {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 6
        spacing: 0

        Tray {
            bar: bar
            Layout.rightMargin: 6
        }

        // Stay-awake indicator (only visible when hypridle is off)
        BarLabel {
            visible: !Status.idleEnabled
            text: "󰅶"
            color: Theme.yellow
            onClicked: {
                bar.run("~/.config/hypr/scripts/toggle-idle.sh");
                Status.refresh();
            }
        }

        // Bluetooth
        BarLabel {
            id: btBtn
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property int connected: Bluetooth.devices.values.filter(d => d.connected).length
            visible: adapter !== null
            text: !adapter || !adapter.enabled ? "󰂲" : (connected > 0 ? "󰂱" : "󰂯")
            color: statusPopup.tab === "bluetooth" ? Theme.blue : (adapter && adapter.enabled ? Theme.fg : Theme.muted)
            onClicked: bar.toggleStatus("bluetooth", btBtn)
            onRightClicked: bar.run("gnome-control-center bluetooth")
        }

        // Network
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
            onRightClicked: bar.run("gnome-control-center wifi")
        }

        // Audio
        BarLabel {
            id: audioBtn
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property bool ready: sink !== null && sink.audio !== null
            readonly property real vol: ready ? sink.audio.volume : 0
            readonly property bool muted: ready ? sink.audio.muted : true
            text: muted ? "󰝟" : vol >= 0.66 ? "󰕾" : vol >= 0.33 ? "󰖀" : "󰕿"
            color: statusPopup.tab === "audio" ? Theme.blue : (muted ? Theme.muted : Theme.fg)
            onClicked: bar.toggleStatus("audio", audioBtn)
            onRightClicked: bar.run("gnome-control-center sound")
            onScrolled: delta => {
                if (!ready) return;
                sink.audio.volume = Math.max(0, Math.min(1, vol + (delta > 0 ? 0.05 : -0.05)));
            }
        }

        // CPU
        BarLabel {
            id: cpuBtn
            text: "󰍛"
            color: statusPopup.tab === "cpu" ? Theme.blue : (Status.cpu >= 80 ? Theme.red : Theme.fg)
            onClicked: bar.toggleStatus("cpu", cpuBtn)
            onRightClicked: bar.run("kitty --class floating-term -e btop")
        }

        // Battery
        BarLabel {
            id: batBtn
            readonly property var dev: UPower.displayDevice
            readonly property bool present: dev !== null && dev.isLaptopBattery
            readonly property int pct: present ? Math.round(dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 0
            readonly property bool charging: present
                && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
            visible: present
            text: {
                if (charging) return "󰂄";
                const icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
                return icons[Math.min(10, Math.floor(pct / 10))];
            }
            color: statusPopup.tab === "battery" ? Theme.blue : (charging ? Theme.green : pct <= 15 ? Theme.red : pct <= 30 ? Theme.yellow : Theme.fg)
            onClicked: bar.toggleStatus("battery", batBtn)
            onRightClicked: bar.run("gnome-control-center power")
        }

        // Power
        BarLabel {
            id: powerBtn
            text: "󰐥"
            color: statusPopup.tab === "power" ? Theme.orange : Theme.red
            onClicked: bar.toggleStatus("power", powerBtn)
            onRightClicked: bar.run("~/.config/hypr/scripts/menu.sh system")
        }
    }
}
