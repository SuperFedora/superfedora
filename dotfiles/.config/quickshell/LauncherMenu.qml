import QtQuick
import QtQuick.Layouts
import Quickshell

// Top-left Fedora menu popover anchored directly beneath the Fedora logo.
PanelWindow {
    id: menu

    property bool open: false
    property var targetScreen: Quickshell.screens[0]

    visible: menu.open
    screen: menu.targetScreen
    color: "transparent"

    anchors {
        top: true
        left: true
    }
    margins {
        top: Theme.barHeight + 6
        left: 6
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 310
    implicitHeight: box.implicitHeight

    function runAndClose(cmd) {
        menu.open = false;
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    readonly property var items: [
        { section: "LAUNCH" },
        { label: "App Launcher",       hint: "SUPER+A", cmd: "fuzzel" },
        { label: "Terminal",           hint: "SUPER+T", cmd: "xdg-terminal-exec" },
        { label: "Web Browser",        hint: "SUPER+B", cmd: "gtk-launch \"$(xdg-settings get default-web-browser)\"" },
        { label: "Home Folder",        hint: "SUPER+F", cmd: "gtk-launch \"$(xdg-mime query default inode/directory)\"" },
        { section: "16-BIT THEME & STYLE" },
        { label: "Next 16-Bit Color",  hint: "Cycle",   cmd: "~/.config/hypr/scripts/wallpaper.sh next" },
        { label: "Dark / Light Mode",  hint: "Toggle",  cmd: "~/.config/hypr/scripts/wallpaper.sh toggle" },
        { label: "Pick Theme Palette", hint: "Menu",    cmd: "~/.config/hypr/scripts/wallpaper.sh pick" },
        { label: "Toggle Window Gaps", hint: "SUPER+BS",cmd: "~/.config/hypr/scripts/toggle-gaps.sh" },
        { section: "CAPTURE" },
        { label: "Screenshot Region",  hint: "Print",   cmd: "~/.config/hypr/scripts/screenshot.sh region" },
        { label: "Screenshot Screen",  hint: "CTRL+Prt",cmd: "~/.config/hypr/scripts/screenshot.sh screen" },
        { label: "Color Picker",       hint: "Hex",     cmd: "sleep 0.2; hyprpicker -a" },
        { section: "SETTINGS & SYSTEM" },
        { label: "System Settings",    hint: "All",     cmd: "gnome-control-center" },
        { label: "Audio Settings",     hint: "Sound",   cmd: "gnome-control-center sound" },
        { label: "Network Settings",   hint: "Wi-Fi",   cmd: "gnome-control-center wifi" },
        { label: "Bluetooth Settings", hint: "BT",      cmd: "gnome-control-center bluetooth" },
        { label: "IdleScreen Setup",   hint: "TUI",     cmd: "kitty --class floating-term -e idlescreen tui" },
        { label: "Keybindings",        hint: "SUPER+F1",cmd: "~/.config/hypr/scripts/keybindings.sh" },
        { label: "Hyprland Config",    hint: "Edit",    cmd: "kitty --class floating-term -e ${EDITOR:-nano} ~/.config/hypr/hyprland.conf" },
        { label: "About SuperFedora",  hint: "Info",    cmd: "kitty --class floating-term -e bash -c 'fastfetch 2>/dev/null || hyprctl version; read -n1 -rsp \"Press any key\"'" }
    ]

    Rectangle {
        id: box
        width: parent.width
        implicitHeight: col.implicitHeight + 20
        color: Theme.bg
        border.width: 2
        border.color: Theme.blue

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 10
            spacing: 2

            Repeater {
                model: menu.items

                Item {
                    required property var modelData
                    readonly property bool isHeader: modelData.section !== undefined

                    Layout.fillWidth: true
                    implicitHeight: isHeader ? 24 : 28

                    Text {
                        visible: parent.isHeader
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        text: parent.modelData.section || ""
                        color: Theme.blue
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                        font.bold: true
                    }

                    Rectangle {
                        visible: !parent.isHeader
                        anchors.fill: parent
                        radius: 3
                        color: rowMouse.containsMouse ? Theme.bgHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Text {
                                Layout.fillWidth: true
                                text: parent.parent.parent.modelData.label || ""
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                            }

                            Text {
                                text: parent.parent.parent.modelData.hint || ""
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menu.runAndClose(parent.parent.modelData.cmd)
                        }
                    }
                }
            }
        }
    }
}
