import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import ".."

// SuperFedora Settings Application: Mirrors GNOME Settings' classic two-pane layout (Left Category Sidebar + Right Preference Groups).
PanelWindow {
    id: win
    property var targetScreen: Quickshell.screens[0]
    readonly property var hyprMon: Hyprland.monitorFor(win.targetScreen)
    readonly property bool isTargetMon: !Hyprland.focusedMonitor ? (win.targetScreen === Quickshell.screens[0]) : (win.hyprMon !== null && win.hyprMon.id === Hyprland.focusedMonitor.id)
    readonly property string activePage: Status.normalizeSettingsPage(Status.settingsPage)
    readonly property int winW: Math.max(1040, Math.min(1260, Math.round(win.targetScreen.width * 0.72)))
    readonly property int winH: Math.max(620, Math.min(760, Math.round(win.targetScreen.height * 0.72)))
    property string searchQuery: ""

    visible: Status.settingsOpen && win.isTargetMon; screen: win.targetScreen; color: "transparent"
    WlrLayershell.namespace: "superfedora-settings"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barHeight; exclusionMode: ExclusionMode.Ignore

    readonly property var categories: [
        { id: "wifi",         icon: "󰤨", title: "Wi-Fi",            sub: "Wireless networks, saved connections & radio state", keywords: "wifi wireless wlan ssid network internet" },
        { id: "network",      icon: "󰈀", title: "Network",          sub: "Wired Ethernet, VPN, DNS & firewall configuration", keywords: "network ethernet vpn dns ip firewall nmtui" },
        { id: "bluetooth",    icon: "󰂯", title: "Bluetooth",        sub: "Bluetooth adapter, device pairing & peripherals", keywords: "bluetooth bt pair audio mouse headphones" },
        { id: "displays",     icon: "󰍹", title: "Displays",         sub: "Monitor scale, brightness, night light & DPMS", keywords: "display monitor screen scale resolution brightness nightlight" },
        { id: "sound",        icon: "󰕾", title: "Sound",            sub: "Output speakers, microphone gain, privacy & 16-bit SFX", keywords: "sound audio volume speaker microphone camera privacy sfx" },
        { id: "power",        icon: "󰁹", title: "Power",            sub: "Battery health, ThinkPad charge thresholds & sleep", keywords: "power battery charge threshold suspend reboot shutdown idle" },
        { id: "multitasking", icon: "󰕮", title: "Multitasking",     sub: "Workspace tiling layouts, window gaps, Dock & Top Bar", keywords: "multitasking workspace tiling gaps dock bar icons" },
        { id: "appearance",   icon: "󰸉", title: "Appearance",       sub: "16-Bit color palettes, Day/Night mode, corners & saver", keywords: "appearance theme color dark light corners wallpaper idlescreen" },
        { id: "startup",      icon: "󰀻", title: "Startup Apps",     sub: "Applications and services launched automatically at login", keywords: "startup autostart apps login launch services" },
        { id: "input",        icon: "󰌌", title: "Keyboard & Mouse", sub: "Keyboard repeat rate, XKB layouts, touchpad & shortcuts", keywords: "keyboard mouse touchpad trackpoint shortcuts bindings" },
        { id: "forge",        icon: "󰙪", title: "Source Forge",     sub: "Hardware-tuned -march=native compiler & package builder", keywords: "forge build source github compile rust cmake native" },
        { id: "system",       icon: "󰋊", title: "System & State",   sub: "Btrfs Snapper checkpoints, AI harness & system details", keywords: "system state btrfs snapshot rollback ai harness ollama" }
    ]

    readonly property var filteredCategories: {
        const q = win.searchQuery.trim().toLowerCase();
        if (!q) return win.categories;
        return win.categories.filter(c => c.title.toLowerCase().includes(q) || c.sub.toLowerCase().includes(q) || c.keywords.includes(q));
    }

    readonly property var currentCatObj: {
        for (const c of win.categories) if (c.id === win.activePage) return c;
        return win.categories[0];
    }

    NumberAnimation { id: openAnim; target: rootBox; property: "opacity"; from: 0.85; to: 1.0; duration: 65; easing.type: Easing.OutQuad }
    onVisibleChanged: if (win.visible) { win.searchQuery = ""; searchBox.text = ""; openAnim.restart(); rootBox.forceActiveFocus(); }

    function selectCategory(id) { Status.settingsPage = id; Status.playSfx("click"); }
    function stepCategory(delta) {
        const list = win.filteredCategories; if (list.length === 0) return;
        const idx = list.findIndex(c => c.id === win.activePage);
        const next = (Math.max(0, idx) + delta + list.length) % list.length;
        win.selectCategory(list[next].id);
    }
    function runCmd(cmd, closeAfter) { if (closeAfter) Status.settingsOpen = false; Status.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", cmd]); Status.refresh(); }

    MouseArea { id: bgArea; anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Status.settingsOpen = false }

    Rectangle {
        id: rootBox; width: win.winW; height: win.winH; anchors.centerIn: parent
        color: Theme.bg; radius: Theme.radius; border.width: 2; border.color: Theme.blue; focus: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Status.settingsOpen = false;
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                searchBox.forceActiveFocus(); event.accepted = true;
            } else if (!searchBox.activeFocus && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                win.stepCategory(event.key === Qt.Key_Down ? 1 : -1); event.accepted = true;
            }
        }

        RowLayout {
            anchors { fill: parent; margins: 6 }
            spacing: 0

            // ================ LEFT PANE: GNOME Settings Sidebar (256px) ================
            Rectangle {
                Layout.preferredWidth: 256; Layout.fillHeight: true; color: Theme.bgAlt; radius: Theme.radiusSm
                border.width: 1; border.color: Theme.border
                ColumnLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 8

                    // Sidebar Title Bar
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "󰣛"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3; font.bold: true }
                        Text { text: "SETTINGS"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                    }

                    // GNOME-style Sidebar Search Filter
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bg
                        border.width: 1; border.color: searchBox.activeFocus ? Theme.cyan : Theme.border
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 } spacing: 6
                            Text { text: "󰍉"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                            TextInput {
                                id: searchBox; Layout.fillWidth: true; verticalAlignment: TextInput.AlignVCenter
                                color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; clip: true
                                onTextChanged: win.searchQuery = text
                                Keys.onEscapePressed: Status.settingsOpen = false
                                Keys.onDownPressed: win.stepCategory(1)
                                Keys.onUpPressed: win.stepCategory(-1)
                                Text { visible: searchBox.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Search settings..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                            }
                        }
                    }

                    // Category Navigation List
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 3
                        Repeater {
                            model: win.filteredCategories
                            Rectangle {
                                id: catRow; required property var modelData; readonly property bool isCur: win.activePage === modelData.id
                                Layout.fillWidth: true; implicitHeight: 36; radius: Theme.radiusSm
                                color: isCur ? Theme.blue : (catM.containsMouse ? Theme.bgHover : "transparent")
                                border.width: isCur ? 1 : 0; border.color: Theme.cyan
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 10
                                    Text { text: catRow.modelData.icon; color: catRow.isCur ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
                                    Text { text: catRow.modelData.title; color: catRow.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: catRow.isCur; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { visible: catRow.isCur; text: "▸"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                                }
                                MouseArea { id: catM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.selectCategory(catRow.modelData.id) }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // ================ RIGHT PANE: GNOME Settings Content Area ================
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

                // Right Pane Top Header Bar
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 54; color: "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 20; rightMargin: 16 } spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { text: win.currentCatObj.icon + "  " + win.currentCatObj.title.toUpperCase(); color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true }
                            Text { text: win.currentCatObj.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                        }
                        Rectangle {
                            implicitWidth: 138; implicitHeight: 32; radius: Theme.radiusSm; color: qdM.containsMouse ? Theme.blue : Theme.bgAlt; border.width: 1; border.color: Theme.cyan
                            Text { anchors.centerIn: parent; text: "[ 󰣛 QUICK DECK ]"; color: qdM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                            MouseArea { id: qdM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.toggleSuperDeck(win.activePage) }
                        }
                        Rectangle {
                            implicitWidth: 68; implicitHeight: 32; radius: Theme.radiusSm; color: clsM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: clsM.containsMouse ? Theme.red : Theme.border
                            Text { anchors.centerIn: parent; text: "[ ESC ]"; color: clsM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                            MouseArea { id: clsM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Status.settingsOpen = false }
                        }
                    }
                    Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 } height: 1; color: Theme.border }
                }

                // Right Pane Preference Groups Body
                SettingsPages {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    activePage: win.activePage
                    onExecuteCommand: (cmd, closeAfter) => win.runCmd(cmd, closeAfter)
                }
            }
        }
    }
}
