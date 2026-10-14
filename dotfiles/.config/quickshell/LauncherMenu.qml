import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Unified SuperDeck Drill-Down Catalog & Section View (Apps, Forge, Style, Sound/Net, Bar/Dock, Snapshots, Session).
ColumnLayout {
    id: deckBody
    property string activeSection: Status.superDeckSection || "quick"
    property string searchQuery: ""
    property string confirmCmd: ""
    property string confirmLabel: ""
    signal executeCommand(string cmd, bool closeAfter)

    Layout.fillWidth: true
    spacing: 6

    readonly property var sections: [
        { id: "quick",     icon: "󰀻", label: "Apps" },
        { id: "forge",     icon: "󰣪", label: "Forge" },
        { id: "style",     icon: "󰏘", label: "Style" },
        { id: "net",       icon: "󰕾", label: "Net/Snd" },
        { id: "dock",      icon: "󰘔", label: "Dock" },
        { id: "snapshots", icon: "󰋊", label: "Snaps" },
        { id: "power",     icon: "󰐥", label: "Power" }
    ]

    readonly property var allRows: {
        const list = [];
        const add = (sec, label, hint, cmd, close, accent, confirm) =>
            list.push({ sec: sec, label: label, hint: hint || "", cmd: cmd || "", close: close === true, accent: accent === true, confirm: confirm === true });

        // 1. Quick & Apps (Omarchy Menu + TUI)
        add("quick", "󰚩  Quake AI Drop-Down Console", "SUPER+`", "~/.config/hypr/scripts/quake-ai.sh toggle", true, true);
        add("quick", "󰀻  Launchpad App Grid", "SUPER+SHIFT+A", "qs ipc call dock toggleApps", true);
        add("quick", "󰍉  Fuzzel App Launcher", "SUPER+A", "fuzzel", true);
        add("quick", "󰆍  16-Bit SNES Control Deck TUI", "sf tui", "kitty --class floating-term -e ~/.local/bin/sf tui", true, true);
        add("quick", "󰆍  Terminal (Kitty)", "SUPER+T", "xdg-terminal-exec", true);
        add("quick", "󰈹  Web Browser", "SUPER+B", "gtk-launch \"$(xdg-settings get default-web-browser)\"", true);
        add("quick", "󰉋  Home Folder (Files)", "SUPER+F", "gtk-launch \"$(xdg-mime query default inode/directory)\"", true);
        add("quick", "󰹑  Screenshot Region", "Print", "~/.config/hypr/scripts/screenshot.sh region", true);
        add("quick", "󰍹  Screenshot Full Screen", "CTRL+Prt", "~/.config/hypr/scripts/screenshot.sh screen", true);
        add("quick", "󰈋  16-Bit Hex Color Picker", "SUPER+Prt", "sleep 0.2; hyprpicker -a", true);
        add("quick", "󰌌  Keybindings Reference", "SUPER+F1", "~/.config/hypr/scripts/keybindings.sh", true);

        // 2. Install & Forge (From Source with -march=native)
        add("forge", "󰣪  Forge Status & CPU Flags", "-march=native", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge status; echo; read -n1 -rsp \"Press any key\"'", true, true);
        add("forge", "󰣪  Forge ripgrep (BurntSushi/ripgrep)", "Rust / rg", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge ripgrep --force; read -n1 -rsp \"Done. Press any key\"'", true);
        add("forge", "󰣪  Forge fastfetch (fastfetch-cli/fastfetch)", "CMake / C", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge fastfetch --force; read -n1 -rsp \"Done. Press any key\"'", true);
        add("forge", "󰣪  Forge idlescreen (idlescreen/idlescreen)", "Rust / CLI", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge idlescreen --force; read -n1 -rsp \"Done. Press any key\"'", true);
        add("forge", "󰣪  Forge fd (sharkdp/fd)", "Rust / fd", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge fd --force; read -n1 -rsp \"Done. Press any key\"'", true);
        add("forge", "󰣪  Forge zoxide (ajeetdsouza/zoxide)", "Rust / cd", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge zoxide --force; read -n1 -rsp \"Done. Press any key\"'", true);
        add("forge", "󰣪  Forge btop (aristocratos/btop)", "C++ / Make", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge btop --force; read -n1 -rsp \"Done. Press any key\"'", true);
        add("forge", "󰣪  Forge Hyprland (hyprwm/Hyprland)", "C++23 / Wayland", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge hyprland; read -n1 -rsp \"Done. Press any key\"'", true);
        add("forge", "󰣪  Forge Quickshell (quickshell-mirror)", "Qt6 / CMake", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge quickshell; read -n1 -rsp \"Done. Press any key\"'", true);
        add("forge", "󰑐  Rebuild All Forged Binaries", "sf forge rebuild", "kitty --class floating-term -e bash -c '~/.local/bin/sf forge rebuild; read -n1 -rsp \"Done. Press any key\"'", true, true);

        // 3. Style & Theme (Day/Night, Corners, Palettes, Nightlight, Text Size)
        add("style", "󰔎  Mode: " + (Theme.mode === "light" ? "Day (Light) -> Night" : "Night (Dark) -> Day"), "sf theme toggle", "~/.local/bin/sf theme toggle", false, true);
        add("style", "󰙀  Corners: " + (Theme.corners === "rounded" ? "Rounded -> Square 90°" : "Square 90° -> Rounded"), "sf theme corners", "~/.local/bin/sf theme corners toggle", false, true);
        add("style", "󰖔  Eye-Care Night Light (" + (Theme.nightlight ? "On" : "Off") + ")", "wlsunset", "~/.local/bin/sf theme nightlight toggle", false);
        add("style", "format  Text Size: Compact / Standard / Large", Theme.fontSize + "px", "FONT_CYCLE", false);
        add("style", "󰏘  Preset: SNES 16-Bit", "Cartridge", "~/.local/bin/sf theme snes", false);
        add("style", "󰏘  Preset: Tokyo Night", "Cyber", "~/.local/bin/sf theme tokyo-night", false);
        add("style", "󰏘  Preset: Catppuccin", "Pastel", "~/.local/bin/sf theme catppuccin", false);
        add("style", "󰏘  Preset: Nord", "Arctic", "~/.local/bin/sf theme nord", false);
        add("style", "󰏘  01 Super Blue", "Jewel 01", "~/.local/bin/sf theme 01-super-blue", false);
        add("style", "󰏘  02 Metroid Violet", "Jewel 02", "~/.local/bin/sf theme 02-metroid-violet", false);
        add("style", "󰏘  03 Super Ruby", "Jewel 03", "~/.local/bin/sf theme 03-super-ruby", false);
        add("style", "󰏘  04 Emerald Green", "Jewel 04", "~/.local/bin/sf theme 04-emerald-green", false);
        add("style", "󰏘  05 Star Gold", "Jewel 05", "~/.local/bin/sf theme 05-star-gold", false);
        add("style", "󰏘  06 Electric Cyan", "Jewel 06", "~/.local/bin/sf theme 06-electric-cyan", false);
        add("style", "󰏘  07 Flame Orange", "Jewel 07", "~/.local/bin/sf theme 07-flame-orange", false);
        add("style", "󰏘  08 Neon Coral", "Jewel 08", "~/.local/bin/sf theme 08-neon-coral", false);

        // 4. Sound & Network
        add("net", "󰕾  Audio Mixer TUI (wiremix)", "PipeWire", "PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wiremix", true, true);
        add("net", "󰤨  Wi-Fi Manager TUI (wlctl)", Status.ssid || Status.netType, "PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e wlctl", true, true);
        add("net", "󰂯  Bluetooth Manager TUI (bluetui)", "BlueZ", "PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$PATH\" kitty --class floating-term -e bluetui", true, true);
        for (const w of Status.wifiList) {
            const safe = w.ssid.replace(/'/g, "'\\''");
            add("net", (w.active ? "[*] Wi-Fi: " : "[ ] Wi-Fi: ") + w.ssid, w.signal + "%",
                w.active ? "nmcli connection down '" + safe + "'" : "nmcli device wifi connect '" + safe + "'", false);
        }
        if (Bluetooth.defaultAdapter) {
            for (const d of Bluetooth.devices.values) {
                if (d.connected || d.paired) {
                    add("net", (d.connected ? "[*] BT: " : "[ ] BT: ") + (d.name || d.address), d.connected ? "Connected" : "Paired",
                        "bluetoothctl " + (d.connected ? "disconnect " : "connect ") + d.address, false);
                }
            }
        }

        // 5. Desktop, Bar & Omarchy Quattro Dock
        const pos = (Status.dockConfig && Status.dockConfig.position) || "bottom";
        add("dock", "󰘔  Dock Edge: Bottom" + (pos === "bottom" ? " [*]" : ""), "Quattro", "~/.local/bin/sf dock position bottom", false);
        add("dock", "󰘔  Dock Edge: Left" + (pos === "left" ? " [*]" : ""), "Quattro", "~/.local/bin/sf dock position left", false);
        add("dock", "󰘔  Dock Edge: Right" + (pos === "right" ? " [*]" : ""), "Quattro", "~/.local/bin/sf dock position right", false);
        add("dock", "󰘔  Dock Edge: Top" + (pos === "top" ? " [*]" : ""), "Quattro", "~/.local/bin/sf dock position top", false);
        add("dock", "󰘔  Toggle Dock Auto-Hide", Status.dockConfig && Status.dockConfig.autohide ? "On" : "Off", "~/.local/bin/sf dock autohide toggle", false);
        add("dock", "󰘔  Toggle Dock on Tiled Workspaces", Status.dockConfig && Status.dockConfig.showAlways !== false ? "Always" : "Float-only", "~/.local/bin/sf dock always toggle", false);
        add("dock", "󰕰  Cycle Workspace Layout (Tile/Scroll/Float)", "SUPER+Y", "~/.config/hypr/scripts/toggle-tiling.sh cycle", false, true);
        add("dock", "󰆓  Save Workspace Window Layout", "SUPER+ALT+Home", "~/.config/hypr/scripts/toggle-tiling.sh save-layout", false);
        add("dock", "󰑐  Restore Workspace Window Layout", "SUPER+Home", "~/.config/hypr/scripts/toggle-tiling.sh restore-layout", false);
        add("dock", "󰹑  Toggle Window Gaps", "SUPER+BS", "~/.config/hypr/scripts/toggle-gaps.sh", false);

        // 6. Snapshots & System
        add("snapshots", "󰋊  Btrfs Snapshot & Boot-Guard TUI", "sf rollback", "kitty --class floating-term -e ~/.local/bin/sf rollback", true, true);
        add("snapshots", "󰐕  Create Btrfs Checkpoint Snapshot", "pkexec/sudo", "kitty --class floating-term -e bash -c '~/.local/bin/sf rollback --create \"SuperDeck Checkpoint\"; read -n1 -rsp \"Press any key\"'", true);
        add("snapshots", "󰁯  Revert to Pre-Install Baseline Snapshot", "Rollback", "kitty --class floating-term -e ~/.local/bin/sf rollback --baseline", true, false, true);
        add("snapshots", "󰍛  Activity Monitor (btop)", "CPU " + Status.cpu + "%", "kitty --class floating-term -e btop", true);
        add("snapshots", "󰒓  GNOME Control Center (Full GUI)", "Settings", "gnome-control-center", true);
        add("snapshots", "󰋼  About SuperFedora (fastfetch)", "System", "kitty --class floating-term -e bash -c 'fastfetch 2>/dev/null || ~/.local/bin/sf tui banner; echo; read -n1 -rsp \"Press any key\"'", true);

        // 7. Session & Power (with confirmation popup & polkit support)
        add("power", "󰌾  Lock Screen", "SUPER+Esc", "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session", true, true);
        add("power", "󰒲  Start 16-Bit IdleScreen Now", "SUPER+SHIFT+I", "idlescreen start", true);
        add("power", "󰤄  Suspend Workstation", "Sleep", "systemctl suspend", true, false, true);
        add("power", "󰍃  Log Out of Session", "Exit DE", "hyprctl dispatch exit", true, false, true);
        add("power", "󰜉  Restart Workstation", "Reboot", "systemctl reboot", true, false, true);
        add("power", "󰐥  Shut Down Workstation", "Power Off", "systemctl poweroff", true, true, true);
        return list;
    }

    readonly property var filteredRows: {
        const q = deckBody.searchQuery.trim().toLowerCase();
        if (q.length > 0) {
            const matches = deckBody.allRows.filter(r => r.label.toLowerCase().includes(q) || r.hint.toLowerCase().includes(q) || r.sec.toLowerCase().includes(q));
            if (q.includes("/") && !q.startsWith("/")) {
                matches.unshift({
                    sec: "forge", accent: true, close: true, confirm: false,
                    label: "󰣪  Forge GitHub Repo: " + deckBody.searchQuery.trim(),
                    hint: "-march=native",
                    cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge \"" + deckBody.searchQuery.trim().replace(/"/g, "") + "\"; read -n1 -rsp \"Done. Press any key\"'"
                });
            }
            return matches.slice(0, 10);
        }
        return deckBody.allRows.filter(r => r.sec === deckBody.activeSection);
    }

    // Section Selector Bar
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: deckBody.sections
            Rectangle {
                required property var modelData
                readonly property bool active: deckBody.activeSection === modelData.id && deckBody.searchQuery.trim() === ""
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Theme.radiusSm
                color: active ? Theme.blue : (tabMouse.containsMouse ? Theme.bgHover : Theme.bgAlt)
                border.width: active ? 0 : 1
                border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    text: (parent.modelData.displayIcon || parent.modelData.icon) + " " + parent.modelData.label
                    color: parent.active ? Theme.bg : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                    font.bold: parent.active
                }
                MouseArea {
                    id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        deckBody.confirmCmd = "";
                        Status.superDeckSection = parent.modelData.id;
                        Status.playSfx("click");
                    }
                }
            }
        }
    }

    // Inline Confirmation Banner for Destructive Power/Snapshot Actions
    Rectangle {
        visible: deckBody.confirmCmd !== ""
        Layout.fillWidth: true
        implicitHeight: 36
        radius: Theme.radiusSm
        color: Theme.bgAlt
        border.width: 2
        border.color: Theme.red
        RowLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 6
            Text { Layout.fillWidth: true; text: "Confirm: " + deckBody.confirmLabel + "?"; color: Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; elide: Text.ElideRight }
            Rectangle {
                implicitWidth: 64; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.red
                Text { anchors.centerIn: parent; text: "Confirm"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const c = deckBody.confirmCmd; deckBody.confirmCmd = ""; deckBody.executeCommand(c, true); } }
            }
            Rectangle {
                implicitWidth: 56; implicitHeight: 22; radius: Theme.radiusSm; color: Theme.bgHover
                Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.confirmCmd = "" }
            }
        }
    }

    // Drill-Down Items List
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: deckBody.filteredRows
            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Theme.radiusSm
                color: rowMouse.containsMouse ? Theme.bgHover : (modelData.accent ? Theme.bgAlt : "transparent")
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    Text { Layout.fillWidth: true; text: parent.parent.modelData.label; color: parent.parent.modelData.accent ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: parent.parent.modelData.accent; elide: Text.ElideRight }
                    Text { text: parent.parent.modelData.hint; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                }
                MouseArea {
                    id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const d = parent.modelData;
                        if (d.cmd === "FONT_CYCLE") {
                            Theme.fontSize = Theme.fontSize === 14 ? 16 : (Theme.fontSize === 16 ? 12 : 14);
                            Status.playSfx("toggle");
                        } else if (d.confirm) {
                            deckBody.confirmLabel = d.label;
                            deckBody.confirmCmd = d.cmd;
                            Status.playSfx("alert");
                        } else {
                            deckBody.executeCommand(d.cmd, d.close);
                        }
                    }
                }
            }
        }
    }
}
