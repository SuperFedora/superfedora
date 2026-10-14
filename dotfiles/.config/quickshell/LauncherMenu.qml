import QtQuick
import QtQuick.Layouts
import Quickshell

// SuperDesk Tabs 3, 4 & 5: [3] STATE & SNAPSHOTS, [4] SOFTWARE & FORGE, [5] SURFACE & FEEL.
ColumnLayout {
    id: deckBody
    property string activeSection: "state"
    property bool batPresent: false; property int batPct: 100; property bool batCharging: false
    signal executeCommand(string cmd, bool closeAfter); signal requestConfirm(string label, string cmd)
    signal switchTabRequested(int tabIndex); signal closeRequested()
    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
    function focusSearch() { forgeInput.forceActiveFocus(); }

    readonly property var telemetryCards: [
        { icon: "󰍛", title: "CPU COMPUTE", val: Status.cpu + "%", pct: Status.cpu / 100.0, col: Status.cpu >= 80 ? Theme.red : Theme.blue },
        { icon: "󰘚", title: "MEMORY (RAM)", val: Status.mem + "%", pct: Status.mem / 100.0, col: Status.mem >= 85 ? Theme.red : Theme.cyan },
        { icon: "󰢮", title: "GPU ENGINE", val: Status.gpu + "%", pct: Status.gpu / 100.0, col: Theme.green },
        { icon: "󰔏", title: "PACKAGE TEMP", val: Status.tempC + "°C", pct: Math.min(1, Status.tempC / 100.0), col: Status.tempC >= 80 ? Theme.red : Theme.yellow },
        { icon: "󰛳", title: "NETWORK I/O", val: "RX " + Status.netRxKbps.toFixed(1) + " / TX " + Status.netTxKbps.toFixed(1) + " KB/s", pct: Math.min(1, (Status.netRxKbps + Status.netTxKbps) / 2048.0), col: Theme.blue },
        { icon: deckBody.batCharging ? "󰂄" : "󰁹", title: "POWER / BATTERY", val: deckBody.batPresent ? (deckBody.batPct + "% (" + (deckBody.batCharging ? "Charging" : "Battery") + ")") : "AC Workstation", pct: deckBody.batPresent ? (deckBody.batPct / 100.0) : 1.0, col: deckBody.batCharging ? Theme.green : Theme.cyan }
    ]
    readonly property var stateRows: [
        { label: "󰐕  Create Btrfs Checkpoint Snapshot", hint: "sf rollback --create", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf rollback --create \"SuperDesk Checkpoint\"; read -n1 -rsp \"Press any key\"'", close: true, accent: true },
        { label: "󰋊  Open Btrfs Snapshot & Boot-Guard TUI", hint: "sf rollback", cmd: "kitty --class floating-term -e ~/.local/bin/sf rollback", close: true, accent: true },
        { label: "󰁯  Revert to Pre-Install Baseline Snapshot", hint: "Destructive Rollback", cmd: "kitty --class floating-term -e ~/.local/bin/sf rollback --baseline", close: true, confirm: true },
        { label: "󰍛  Activity Monitor (btop)", hint: "CPU " + Status.cpu + "% / RAM " + Status.mem + "%", cmd: "kitty --class floating-term -e btop", close: true },
        { label: "󰋼  System Overview (fastfetch)", hint: "Hardware & OS", cmd: "kitty --class floating-term -e bash -c 'fastfetch 2>/dev/null || ~/.local/bin/sf tui banner; echo; read -n1 -rsp \"Press any key\"'", close: true },
        { label: "󰒓  GNOME Control Center (Full GUI)", hint: "Desktop Settings", cmd: "gnome-control-center", close: true },
        { label: "󰆍  16-Bit SNES Control Deck TUI", hint: "sf tui", cmd: "kitty --class floating-term -e ~/.local/bin/sf tui", close: true, accent: true },
        { label: "󰈏  Verify Dotfiles & Drift Audit", hint: "sf status", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf status; echo; read -n1 -rsp \"Press any key\"'", close: true }
    ]
    readonly property var forgeRows: [
        { label: "󰣪  Forge Status & CPU Flags", hint: "-march=native", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge status; echo; read -n1 -rsp \"Press any key\"'", accent: true },
        { label: "󰑐  Rebuild All Forged Binaries", hint: "sf forge rebuild", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge rebuild; read -n1 -rsp \"Done. Press any key\"'", accent: true },
        { label: "󰣪  idlescreen (idlescreen/idlescreen)", hint: "Rust / Saver", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge idlescreen --force; read -n1 -rsp \"Done. Press any key\"'" },
        { label: "󰣪  ripgrep (BurntSushi/ripgrep)", hint: "Rust / rg", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge ripgrep --force; read -n1 -rsp \"Done. Press any key\"'" },
        { label: "󰣪  fastfetch (fastfetch-cli/fastfetch)", hint: "CMake / C", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge fastfetch --force; read -n1 -rsp \"Done. Press any key\"'" },
        { label: "󰣪  fd (sharkdp/fd)", hint: "Rust / fd", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge fd --force; read -n1 -rsp \"Done. Press any key\"'" },
        { label: "󰣪  zoxide (ajeetdsouza/zoxide)", hint: "Rust / cd", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge zoxide --force; read -n1 -rsp \"Done. Press any key\"'" },
        { label: "󰣪  btop (aristocratos/btop)", hint: "C++ / Make", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge btop --force; read -n1 -rsp \"Done. Press any key\"'" },
        { label: "󰣪  hyprland (hyprwm/Hyprland)", hint: "C++23 / Wayland", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge hyprland; read -n1 -rsp \"Done. Press any key\"'" },
        { label: "󰣪  quickshell (quickshell-mirror)", hint: "Qt6 / QML", cmd: "kitty --class floating-term -e bash -c '~/.local/bin/sf forge quickshell; read -n1 -rsp \"Done. Press any key\"'" }
    ]
    readonly property var devAndAppRows: [
        { label: "󰟓  Runtimes (mise): Rust / Go / Node / Python / Zig", hint: "mise status", cmd: "kitty --class floating-term -e bash -c 'mise use -g rust@latest go@latest node@lts python@latest zig@latest 2>/dev/null || mise ls; read -n1 -rsp \"Done. Press any key\"'", accent: true },
        { label: "󰆼  Dev DB: PostgreSQL 16 Container", hint: "127.0.0.1:5432", cmd: "kitty --class floating-term -e bash -c '(podman start sf-postgres || podman run -d --name sf-postgres -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:5432:5432 postgres:16-alpine); read -n1 -rsp \"Done. Press any key\"'" },
        { label: "󰆼  Dev DB: Redis 7 / MySQL 8 Containers", hint: "6379 / 3306", cmd: "kitty --class floating-term -e bash -c '(podman start sf-redis || podman run -d --name sf-redis -p 127.0.0.1:6379:6379 redis:7-alpine); read -n1 -rsp \"Done. Press any key\"'" },
        { label: "󰈹  Web Browser", hint: "SUPER+B", cmd: "gtk-launch \"$(xdg-settings get default-web-browser)\"" },
        { label: "󰉋  Home Folder (Files)", hint: "SUPER+F", cmd: "gtk-launch \"$(xdg-mime query default inode/directory)\"" },
        { label: "󰆍  Terminal (Kitty)", hint: "SUPER+T", cmd: "xdg-terminal-exec" },
        { label: "󰍉  Fuzzel App Launcher", hint: "SUPER+A", cmd: "fuzzel" },
        { label: "󰀻  Launchpad App Grid", hint: "SUPER+SHIFT+A", cmd: "qs ipc call dock toggleApps", accent: true },
        { label: "󰹑  Screenshot Region / Full Screen", hint: "Print / CTRL+Prt", cmd: "~/.config/hypr/scripts/screenshot.sh region" },
        { label: "󰈋  16-Bit Hex Color Picker", hint: "SUPER+Print", cmd: "sleep 0.2; hyprpicker -a" }
    ]
    readonly property var themePresets: [
        { id: "snes", label: "SNES 16-Bit" },         { id: "tokyo-night", label: "Tokyo Night" },
        { id: "catppuccin", label: "Catppuccin" },    { id: "nord", label: "Nord" },
        { id: "01-super-blue", label: "01 Super Blue" },      { id: "02-metroid-violet", label: "02 Metroid Violet" },
        { id: "03-super-ruby", label: "03 Super Ruby" },      { id: "04-emerald-green", label: "04 Emerald Green" },
        { id: "05-star-gold", label: "05 Star Gold" },        { id: "06-electric-cyan", label: "06 Electric Cyan" },
        { id: "07-flame-orange", label: "07 Flame Orange" },  { id: "08-neon-coral", label: "08 Neon Coral" }
    ]
    readonly property string dockPos: (Status.dockConfig && Status.dockConfig.position) || "bottom"
    readonly property var dockAndTilingRows: [
        { label: "󰘔  Dock Edge: Bottom" + (deckBody.dockPos === "bottom" ? " [*]" : ""), hint: "Quattro", cmd: "~/.local/bin/sf dock position bottom", close: false, accent: deckBody.dockPos === "bottom" },
        { label: "󰘔  Dock Edge: Left" + (deckBody.dockPos === "left" ? " [*]" : ""), hint: "Quattro", cmd: "~/.local/bin/sf dock position left", close: false, accent: deckBody.dockPos === "left" },
        { label: "󰘔  Dock Edge: Right" + (deckBody.dockPos === "right" ? " [*]" : ""), hint: "Quattro", cmd: "~/.local/bin/sf dock position right", close: false, accent: deckBody.dockPos === "right" },
        { label: "󰘔  Dock Edge: Top" + (deckBody.dockPos === "top" ? " [*]" : ""), hint: "Quattro", cmd: "~/.local/bin/sf dock position top", close: false, accent: deckBody.dockPos === "top" },
        { label: "󰘔  Dock Auto-Hide (" + (Status.dockConfig && Status.dockConfig.autohide ? "On" : "Off") + ")", hint: "Toggle", cmd: "~/.local/bin/sf dock autohide toggle", close: false },
        { label: "󰘔  Show on Tiled Workspaces (" + (Status.dockConfig && Status.dockConfig.showAlways !== false ? "Always" : "Float-Only") + ")", hint: "Toggle", cmd: "~/.local/bin/sf dock always toggle", close: false },
        { label: "󰕰  Cycle Workspace Layout (Tile / Scroll / Float)", hint: "SUPER+Y", cmd: "~/.config/hypr/scripts/toggle-tiling.sh cycle", close: false, accent: true },
        { label: "󰆓  Save Workspace Window Layout", hint: "SUPER+ALT+Home", cmd: "~/.config/hypr/scripts/toggle-tiling.sh save-layout", close: false },
        { label: "󰑐  Restore Workspace Window Layout", hint: "SUPER+Home", cmd: "~/.config/hypr/scripts/toggle-tiling.sh restore-layout", close: false },
        { label: "󰹑  Toggle Window Gaps", hint: "SUPER+BS", cmd: "~/.config/hypr/scripts/toggle-gaps.sh", close: false },
        { label: "󰌌  COSMIC Keybindings Reference", hint: "SUPER+F1", cmd: "~/.config/hypr/scripts/keybindings.sh", close: true, accent: true }
    ]

    function filterList(arr) { const q = forgeInput.text.trim().toLowerCase(); return !q ? arr : arr.filter(r => r.label.toLowerCase().includes(q) || (r.hint && r.hint.toLowerCase().includes(q))); }
    function runForgeInput() {
        const q = forgeInput.text.trim().replace(/"/g, ""); if (!q) return;
        if (q.includes("/") && !q.startsWith("/")) deckBody.executeCommand("kitty --class floating-term -e bash -c '~/.local/bin/sf forge \"" + q + "\"; read -n1 -rsp \"Done. Press any key\"'", true);
        else { const m = deckBody.filterList(deckBody.forgeRows.concat(deckBody.devAndAppRows)); if (m.length > 0) deckBody.executeCommand(m[0].cmd, true); }
    }

    // ---------------- TAB 3: [3] STATE & SNAPSHOTS ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "state"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        GridLayout {
            Layout.fillWidth: true; columns: 3; rowSpacing: 8; columnSpacing: 8
            Repeater {
                model: deckBody.telemetryCards
                Rectangle {
                    id: tCard; required property var modelData; Layout.fillWidth: true; implicitHeight: 62; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        anchors { fill: parent; margins: 8 } spacing: 4
                        RowLayout { Layout.fillWidth: true; Text { text: tCard.modelData.icon + " " + tCard.modelData.title; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.fillWidth: true } Text { text: tCard.modelData.val; color: tCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
                        Rectangle { Layout.fillWidth: true; height: 8; radius: Theme.radiusSm; color: Theme.bg; Rectangle { width: parent.width * Math.max(0.03, Math.min(1, tCard.modelData.pct)); height: parent.height; radius: Theme.radiusSm; color: tCard.modelData.col } }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
            ColumnLayout {
                anchors { fill: parent; margins: 9 } spacing: 6
                Text { text: "LAYER 1 // BTRFS SNAPSHOTS, BOOT-GUARD RECOVERY & TELEMETRY"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 6; columnSpacing: 8
                    Repeater {
                        model: deckBody.stateRows
                        Rectangle {
                            id: stRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: stM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 1; border.color: modelData.confirm ? Theme.red : (modelData.accent ? Theme.blue : Theme.border)
                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                Text { Layout.fillWidth: true; text: stRow.modelData.label; color: stRow.modelData.confirm ? Theme.red : (stRow.modelData.accent ? Theme.cyan : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: (stRow.modelData.accent === true) || (stRow.modelData.confirm === true); elide: Text.ElideRight }
                                Text { text: stRow.modelData.hint; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                            }
                            MouseArea { id: stM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const d = stRow.modelData; if (d.confirm) deckBody.requestConfirm(d.label, d.cmd); else deckBody.executeCommand(d.cmd, d.close === true); } }
                        }
                    }
                }
            }
        }
    }

    // ---------------- TAB 4: [4] SOFTWARE & FORGE ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "software"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: forgeInput.activeFocus ? 2 : 1; border.color: forgeInput.activeFocus ? Theme.blue : Theme.border
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8
                    Text { text: "󰣪"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                    TextInput {
                        id: forgeInput; Layout.fillWidth: true; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; clip: true
                        Keys.onEscapePressed: deckBody.closeRequested()
                        Keys.onReturnPressed: deckBody.runForgeInput()
                        Keys.onPressed: event => { if ((event.modifiers & (Qt.AltModifier | Qt.ControlModifier)) && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) { deckBody.switchTabRequested(event.key - Qt.Key_1); event.accepted = true; } }
                        Text { visible: forgeInput.text === ""; text: "Type GitHub owner/repo to build from source (-march=native) or filter software..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                    }
                }
            }
            Rectangle { implicitWidth: 138; implicitHeight: 34; radius: Theme.radiusSm; color: fgBtnM.containsMouse ? Theme.cyan : Theme.blue; Text { anchors.centerIn: parent; text: "󰣪 Forge / Launch"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } MouseArea { id: fgBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.runForgeInput() } }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Repeater {
                model: [
                    { title: "HARDWARE-TUNED SOURCE BUILDER (sf forge -march=native)", rows: deckBody.filterList(deckBody.forgeRows) },
                    { title: "DEV STACK (mise / Podman DBs) & WORKSTATION APPS", rows: deckBody.filterList(deckBody.devAndAppRows) }
                ]
                Rectangle {
                    id: swCol; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                    ColumnLayout {
                        anchors { fill: parent; margins: 8 } spacing: 3
                        Text { text: swCol.modelData.title; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                        Repeater {
                            model: swCol.modelData.rows
                            Rectangle {
                                id: swRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm; color: swM.containsMouse ? Theme.bgHover : (modelData.accent ? Theme.bg : "transparent")
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    Text { Layout.fillWidth: true; text: swRow.modelData.label; color: swRow.modelData.accent ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: swRow.modelData.accent === true; elide: Text.ElideRight }
                                    Text { text: swRow.modelData.hint || ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                                }
                                MouseArea { id: swM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand(swRow.modelData.cmd, true) }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    // ---------------- TAB 5: [5] SURFACE & FEEL ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "surface"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: [
                    { icon: Theme.mode === "light" ? "󰖙" : "󰖔", title: "Mode", sub: Theme.mode === "light" ? "Day (Light)" : "Night (Dark)", active: Theme.mode === "dark", cmd: "~/.local/bin/sf theme toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh toggle" },
                    { icon: Theme.corners === "rounded" ? "󰙀" : "󰝣", title: "Corners", sub: Theme.corners === "rounded" ? "Rounded" : "Square 90°", active: Theme.corners === "square", cmd: "~/.local/bin/sf theme corners toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh corners toggle" },
                    { icon: "󰖔", title: "Night Light", sub: Theme.nightlight ? "Warm On" : "Off", active: Theme.nightlight, cmd: "~/.local/bin/sf theme nightlight toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh nightlight toggle" },
                    { icon: "󰬴", title: "Text Size", sub: Theme.fontSize + "px", active: Theme.fontSize !== 14, act: "font" },
                    { icon: Status.sfxEnabled ? "󰕾" : "󰝟", title: "16-Bit SFX", sub: Status.sfxEnabled ? "Chimes On" : "Muted", active: Status.sfxEnabled, act: "sfx" }
                ]
                Rectangle {
                    id: sfCard; required property var modelData; Layout.fillWidth: true; implicitHeight: 46; radius: Theme.radiusSm; color: sfM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: modelData.active ? 2 : 1; border.color: modelData.active ? Theme.blue : Theme.border
                    RowLayout {
                        anchors { fill: parent; margins: 8 } spacing: 8
                        Text { text: sfCard.modelData.icon; color: sfCard.modelData.active ? Theme.cyan : Theme.muted; font.family: Theme.font; font.pixelSize: 18 }
                        ColumnLayout { Layout.fillWidth: true; spacing: 0; Text { text: sfCard.modelData.title; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } Text { text: sfCard.modelData.sub; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 } }
                    }
                    MouseArea {
                        id: sfM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const d = sfCard.modelData;
                            if (d.act === "font") { Theme.fontSize = Theme.fontSize === 14 ? 16 : (Theme.fontSize === 16 ? 12 : 14); Status.playSfx("toggle"); }
                            else if (d.act === "sfx") Status.toggleSfx(); else deckBody.executeCommand(d.cmd, false);
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                ColumnLayout {
                    anchors { fill: parent; margins: 8 } spacing: 6
                    Text { text: "16-BIT CARTRIDGE & JEWEL THEME PRESETS (ACTIVE: " + Theme.themeName.toUpperCase() + ")"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 5; columnSpacing: 6
                        Repeater {
                            model: deckBody.themePresets
                            Rectangle {
                                id: tpCard; required property var modelData; readonly property bool isCur: Theme.theme === modelData.id
                                Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm; color: tpM.containsMouse ? Theme.bgHover : Theme.bg; border.width: isCur ? 2 : 1; border.color: isCur ? Theme.blue : Theme.border
                                Text { anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8 } text: (tpCard.isCur ? "[*] " : "[ ] ") + tpCard.modelData.label; color: tpCard.isCur ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: tpCard.isCur }
                                MouseArea { id: tpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("~/.local/bin/sf theme " + tpCard.modelData.id + " || ~/Projects/superfedora/superfedora/lib/apply-theme.sh " + tpCard.modelData.id, false) }
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
                ColumnLayout {
                    anchors { fill: parent; margins: 8 } spacing: 3
                    Text { text: "QUATTRO DOCK & COSMIC WINDOW TILING"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    Repeater {
                        model: deckBody.dockAndTilingRows
                        Rectangle {
                            id: dkRow; required property var modelData; Layout.fillWidth: true; implicitHeight: 25; radius: Theme.radiusSm; color: dkM.containsMouse ? Theme.bgHover : (modelData.accent ? Theme.bg : "transparent")
                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                Text { Layout.fillWidth: true; text: dkRow.modelData.label; color: dkRow.modelData.accent ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: dkRow.modelData.accent === true; elide: Text.ElideRight }
                                Text { text: dkRow.modelData.hint; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
                            }
                            MouseArea { id: dkM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand(dkRow.modelData.cmd, dkRow.modelData.close === true) }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
