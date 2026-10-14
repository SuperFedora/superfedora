import QtQuick
import QtQuick.Layouts
import Quickshell

// SuperDesk 16-Bit SNES Cartridges: [6] THEME, [7] SHELL, [8] FORGE, [9] STATE, and [0] POWER.
ColumnLayout {
    id: deckBody
    property string activeSection: "theme"
    property bool batPresent: false; property int batPct: 100; property bool batCharging: false
    property string forgeStatus: "READY (-march=native)"; property string selBarIcon: "wifi"
    signal executeCommand(string cmd, bool closeAfter); signal requestConfirm(string label, string cmd)
    signal switchTabRequested(int tabIndex); signal cycleTabRequested(bool backward); signal closeRequested()
    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
    function focusSearch() { if (deckBody.activeSection === "forge") forgeInput.forceActiveFocus(); }

    readonly property var forgeChips: ["hyprland", "quickshell", "idlescreen", "ripgrep", "fastfetch", "btop", "fd", "zoxide"]
    readonly property var themePresets: [
        { id: "snes", label: "[ SNES ]" }, { id: "01-super-blue", label: "[ SUPER BLUE ]" }, { id: "tokyo-night", label: "[ TOKYO NIGHT ]" },
        { id: "catppuccin", label: "[ CATPPUCCIN ]" }, { id: "nord", label: "[ NORD ]" }, { id: "02-metroid-violet", label: "[ METROID VIOLET ]" }
    ]
    readonly property var barIconLabels: ({ wifi: "󰤨 WIFI", bluetooth: "󰂯 BT", speaker: "󰕾 SPK", mic: "󰍬 MIC", camera: "󰄀 CAM", battery: "󰁹 BAT", power: "󰐥 PWR" })

    function asciiBar(pct) { const f = Math.max(0, Math.min(16, Math.round((pct / 100.0) * 16))); return "[" + "█".repeat(f) + "░".repeat(16 - f) + "]"; }
    function runForge(target) {
        const q = String(target || forgeInput.text || "").trim().replace(/['"]/g, ""); if (!q) return;
        deckBody.forgeStatus = "BUILDING: " + q.toUpperCase() + "...";
        deckBody.executeCommand("(~/.local/bin/sf forge '" + q + "' || ~/Projects/superfedora/superfedora/lib/forge.sh '" + q + "') && notify-send -a SuperFedora 'Source Forge' 'Built " + q + " (-march=native)'", false);
    }
    function nextDockEdge() { const order = ["bottom", "left", "right", "top"], cur = String((Status.dockConfig && Status.dockConfig.position) || "bottom").toLowerCase(); Status.runDockCmd("position " + order[(order.indexOf(cur) + 1) % order.length]); }

    // ---------------- TAB 6: [6] THEME (16-Bit Cartridges, Mode, Corners & SFX) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "theme"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "▸ 16-BIT PALETTE CARTRIDGES & WALLPAPERS"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true }
                    Rectangle { implicitWidth: 168; implicitHeight: 28; radius: Theme.radiusSm; color: wpM.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ 󰸉 NEXT THEME ]"; color: wpM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: wpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("~/.config/hypr/scripts/wallpaper.sh next", false) } }
                }
                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; columns: 3; rowSpacing: 10; columnSpacing: 10
                    Repeater {
                        model: deckBody.themePresets
                        Rectangle {
                            id: tpBtn; required property var modelData; readonly property bool isCur: Theme.theme === modelData.id
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: tpM.containsMouse ? Theme.bgHover : (isCur ? Theme.blue : Theme.bg); border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border
                            Text { anchors.centerIn: parent; text: (tpBtn.isCur ? "▸ " : "") + tpBtn.modelData.label; color: tpBtn.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                            MouseArea { id: tpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("~/.local/bin/sf theme " + tpBtn.modelData.id + " || ~/Projects/superfedora/superfedora/lib/apply-theme.sh " + tpBtn.modelData.id, false) }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; implicitHeight: 96; spacing: 10
            Repeater {
                model: [
                    { act: "mode", label: "[ MODE: " + (Theme.mode === "light" ? "DAY" : "NIGHT") + " ]", sub: "Toggle Light / Dark Palette", col: Theme.cyan },
                    { act: "corners", label: "[ CORNERS: " + (Theme.corners === "rounded" ? "ROUNDED" : "SQUARE 90°") + " ]", sub: "Toggle Window & Panel Bevels", col: Theme.blue },
                    { act: "sfx", label: "[ 16-BIT SFX: " + (Status.sfxEnabled ? "ON" : "OFF") + " ]", sub: "Retro SNES UI Audio Feedback", col: Status.sfxEnabled ? Theme.green : Theme.muted }
                ]
                Rectangle {
                    id: sfTog; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: sfM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: sfM.containsMouse ? Theme.cyan : modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout { anchors.centerIn: parent; spacing: 6; Text { Layout.alignment: Qt.AlignHCenter; text: sfTog.modelData.label; color: sfTog.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: sfTog.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                    MouseArea { id: sfM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const a = sfTog.modelData.act; if (a === "sfx") Status.toggleSfx(); else if (a === "corners") deckBody.executeCommand("~/.local/bin/sf theme corners toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh corners toggle", false); else deckBody.executeCommand("~/.local/bin/sf theme toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh toggle", false); } }
                }
            }
        }
    }

    // ---------------- TAB 7: [7] SHELL (Top Bar Icon Organizer & SuperDock Layout) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "shell"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 10
                RowLayout { Layout.fillWidth: true; Text { text: "▸ TOP-RIGHT BAR ICON ORGANIZER"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true } Text { text: "CLICK CHIP TO SELECT · RIGHT-CLICK TO HIDE · DRAG DIRECTLY ON TOP BAR"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                    Repeater {
                        model: Status.barIcons.filter(x => x !== "|")
                        Rectangle {
                            id: biChip; required property string modelData; readonly property bool isSel: deckBody.selBarIcon === modelData; readonly property bool isHid: Status.barHiddenIcons.indexOf(modelData) >= 0
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: biM.containsMouse ? Theme.bgHover : (isSel ? Theme.blue : Theme.bg); border.width: isSel ? 2 : 1; border.color: isSel ? Theme.cyan : (isHid ? Theme.muted : Theme.border)
                            Text { anchors.centerIn: parent; text: (biChip.isHid ? "× " : "") + (deckBody.barIconLabels[biChip.modelData] || biChip.modelData); color: biChip.isSel ? Theme.bg : (biChip.isHid ? Theme.muted : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                            MouseArea { id: biM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: e => { deckBody.selBarIcon = biChip.modelData; if (e.button === Qt.RightButton) Status.toggleBarIconHidden(biChip.modelData); else Status.playSfx("nav"); } }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; implicitHeight: 42; spacing: 8
                    Repeater {
                        model: [
                            { act: "left", label: "[ ◀ MOVE LEFT ]" }, { act: "right", label: "[ MOVE RIGHT ▶ ]" },
                            { act: "hide", label: Status.barHiddenIcons.indexOf(deckBody.selBarIcon) >= 0 ? "[ SHOW ICON ]" : "[ HIDE ICON ]" },
                            { act: "div",  label: Status.barIcons.indexOf("|") >= 0 ? "[ DIVIDERS │: ON ]" : "[ DIVIDERS │: OFF ]" }, { act: "reset", label: "[ RESET ORDER ]" }
                        ]
                        Rectangle {
                            id: biAct; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: biActM.containsMouse ? Theme.cyan : Theme.bg; border.width: 2; border.color: Theme.cyan
                            Text { anchors.centerIn: parent; text: biAct.modelData.label; color: biActM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                            MouseArea { id: biActM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const a = biAct.modelData.act; if (a === "left") Status.moveBarIcon(deckBody.selBarIcon, -1); else if (a === "right") Status.moveBarIcon(deckBody.selBarIcon, 1); else if (a === "hide") Status.toggleBarIconHidden(deckBody.selBarIcon); else if (a === "div") Status.toggleBarDividers(); else Status.resetBarIcons(); } }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; implicitHeight: 96; spacing: 10
            Repeater {
                model: [
                    { act: "edge", label: "[ DOCK EDGE: " + String((Status.dockConfig && Status.dockConfig.position) || "bottom").toUpperCase() + " ]", sub: "Cycle Bottom / Left / Right / Top", col: Theme.yellow },
                    { act: "vis", label: "[ DOCK: " + ((Status.dockConfig && Status.dockConfig.showAlways === false) ? "AUTO-HIDE" : "ALWAYS ON") + " ]", sub: "Toggle Dock Visibility", col: Theme.cyan },
                    { act: "tiling", label: "[ WORKSPACE LAYOUT ]", sub: "Super + Y  ·  Tiling / Floating", col: Theme.green },
                    { act: "gaps", label: "[ TOGGLE WINDOW GAPS ]", sub: "Super + Backspace  ·  Zero / 10px", col: Theme.blue }
                ]
                Rectangle {
                    id: shCard; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: shM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: shCard.modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout { anchors.centerIn: parent; spacing: 6; Text { Layout.alignment: Qt.AlignHCenter; text: shCard.modelData.label; color: shCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: shCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                    MouseArea { id: shM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const a = shCard.modelData.act; if (a === "edge") deckBody.nextDockEdge(); else if (a === "vis") Status.runDockCmd("always toggle"); else if (a === "tiling") deckBody.executeCommand("~/.config/hypr/scripts/toggle-tiling.sh cycle", false); else deckBody.executeCommand("~/.config/hypr/scripts/toggle-gaps.sh", false); } }
                }
            }
        }
    }

    // ---------------- TAB 8: [8] FORGE (Zero-Trust Source Supply Chain) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "forge"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 118; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 10
                RowLayout { Layout.fillWidth: true; Text { text: "▸ ZERO-TRUST SOURCE FORGE (-O3 -march=native -flto=auto)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; Layout.fillWidth: true } Text { text: deckBody.forgeStatus; color: Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Text { text: "TARGET REPO / PRESET:"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 36; radius: Theme.radiusSm; color: Theme.bg; border.width: 2; border.color: forgeInput.activeFocus ? Theme.cyan : Theme.border
                        TextInput {
                            id: forgeInput; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; clip: true; Keys.onReturnPressed: deckBody.runForge(forgeInput.text)
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) { deckBody.closeRequested(); event.accepted = true; }
                                else if ((event.modifiers & (Qt.MetaModifier | Qt.AltModifier | Qt.ControlModifier)) && ((event.key >= Qt.Key_1 && event.key <= Qt.Key_9) || event.key === Qt.Key_0)) { deckBody.switchTabRequested(event.key === Qt.Key_0 ? 9 : (event.key - Qt.Key_1)); event.accepted = true; }
                                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { deckBody.cycleTabRequested(event.key === Qt.Key_Backtab || Boolean(event.modifiers & Qt.ShiftModifier)); event.accepted = true; }
                            }
                            Text { visible: forgeInput.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "owner/repo or preset name..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
                        }
                    }
                    Rectangle { implicitWidth: 132; implicitHeight: 36; radius: Theme.radiusSm; color: fgGo.containsMouse ? Theme.cyan : Theme.blue; Text { anchors.centerIn: parent; text: "[ BUILD NOW ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true } MouseArea { id: fgGo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.runForge(forgeInput.text) } }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 10
                Text { text: "▸ CORE HARDWARE-TUNED WORKSTATION TARGETS (CLICK TO FORGE INTO ~/.local/bin)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; columns: 4; rowSpacing: 10; columnSpacing: 10
                    Repeater {
                        model: deckBody.forgeChips
                        Rectangle {
                            id: chipBtn; required property string modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: chM.containsMouse ? Theme.blue : Theme.bg; border.width: 2; border.color: chM.containsMouse ? Theme.cyan : Theme.border
                            Text { anchors.centerIn: parent; text: (chM.containsMouse ? "▸ " : "") + "[ " + chipBtn.modelData + " ]"; color: chM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                            MouseArea { id: chM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { forgeInput.text = chipBtn.modelData; deckBody.runForge(chipBtn.modelData); } }
                        }
                    }
                }
            }
        }
    }

    // ---------------- TAB 9: [9] STATE (Btrfs Snapshots & Hardware Telemetry) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "state"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
        RowLayout {
            Layout.fillWidth: true; implicitHeight: 112; spacing: 10
            Repeater {
                model: [
                    { title: "CPU UTILIZATION", val: Status.cpu, unit: "%", col: Status.cpu > 80 ? Theme.red : Theme.cyan },
                    { title: "MEMORY ALLOCATED", val: Status.mem, unit: "%", col: Status.mem > 85 ? Theme.yellow : Theme.blue },
                    { title: "THERMAL SENSOR", val: Status.tempC, unit: "°C", col: Status.tempC > 80 ? Theme.red : Theme.green }
                ]
                Rectangle {
                    required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout { anchors.centerIn: parent; spacing: 6; Text { Layout.alignment: Qt.AlignHCenter; text: parent.parent.modelData.title; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: parent.parent.modelData.val + parent.parent.modelData.unit; color: parent.parent.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize + 6; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: deckBody.asciiBar(parent.parent.modelData.val); color: parent.parent.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: ckM.containsMouse ? Theme.green : Theme.bgAlt; border.width: 2; border.color: Theme.green
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout { anchors.centerIn: parent; spacing: 8; Text { Layout.alignment: Qt.AlignHCenter; text: (ckM.containsMouse ? "▸ " : "") + "[ + SAVE BTRFS CHECKPOINT ]"; color: ckM.containsMouse ? Theme.bg : Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: "Create Atomic Root Snapshot via Snapper"; color: ckM.containsMouse ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
                MouseArea { id: ckM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("(pkexec snapper -c root create -d 'SuperDesk Checkpoint' || ~/.local/bin/sf rollback --create 'SuperDesk Checkpoint') && notify-send -a SuperFedora 'Btrfs Checkpoint' 'Saved SuperDesk Checkpoint'", false) }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: rbM.containsMouse ? Theme.yellow : Theme.bgAlt; border.width: 2; border.color: Theme.yellow
                Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                ColumnLayout { anchors.centerIn: parent; spacing: 8; Text { Layout.alignment: Qt.AlignHCenter; text: (rbM.containsMouse ? "▸ " : "") + "[ ↺ ROLLBACK TO BASELINE ]"; color: rbM.containsMouse ? Theme.bg : Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: "Restore Clean Pre-Install Btrfs Baseline"; color: rbM.containsMouse ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
                MouseArea { id: rbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.requestConfirm("ROLLBACK TO BASELINE SNAPSHOT", "pkexec ~/.local/bin/sf rollback --baseline || ~/.local/bin/sf rollback --baseline") }
            }
        }
    }

    // ---------------- TAB 0: [0] POWER (16-Bit Battery Energy Tank & Session Lifecycle) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "power"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 120; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: deckBody.batCharging ? Theme.green : Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 8
                RowLayout { Layout.fillWidth: true; Text { text: "▸ " + (deckBody.batCharging ? "󰂄" : "󰁹") + "  BATTERY HEALTH & ENERGY TANK"; color: deckBody.batCharging ? Theme.green : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true; Layout.fillWidth: true } Text { text: deckBody.asciiBar(deckBody.batPresent ? deckBody.batPct : 100) + " " + (deckBody.batPresent ? deckBody.batPct : 100) + "% — " + (deckBody.batPresent ? (deckBody.batCharging ? "AC CHARGING" : "DISCHARGING") : "AC LINE POWER"); color: deckBody.batCharging ? Theme.green : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true } }
                RowLayout { Layout.fillWidth: true; height: 24; spacing: 4; Repeater { model: 16; Rectangle { required property int index; readonly property int pct: deckBody.batPresent ? deckBody.batPct : 100; readonly property bool lit: (index + 1) * 6.25 <= pct + 2; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: !lit ? Theme.bg : (deckBody.batCharging ? Theme.green : (pct <= 20 ? Theme.red : Theme.cyan)); border.width: 1; border.color: lit ? Theme.cyan : Theme.border } } }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: Status.bat0Present ? ("THINKPAD BAT0 CHARGE THRESHOLD: " + Status.bat0Threshold) : "POWER SUPPLY: STANDARD ACPI / THINKPAD BAT0 READY"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; Layout.fillWidth: true }
                    Rectangle { implicitWidth: 204; implicitHeight: 24; radius: Theme.radiusSm; color: dpmsM.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.cyan; Text { anchors.centerIn: parent; text: "[ 󰍹 SCREEN + KBD OFF ]"; color: dpmsM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true } MouseArea { id: dpmsM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("sleep 0.2; ~/.config/hypr/scripts/toggle-touchpad.sh dpms off", true) } }
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 12; columnSpacing: 12
            Repeater {
                model: [
                    { label: "[ 󰌾 LOCK SCREEN ]", sub: "SUPER + Esc  ·  Instant Session Lock", cmd: "qs ipc --any-display call lock activate >/dev/null 2>&1 || loginctl lock-session", confirm: false, col: Theme.cyan },
                    { label: "[ 󰤄 SLEEP / SUSPEND ]", sub: "Low-Power S3 / s2idle Suspend", cmd: "systemctl suspend", confirm: true, col: Theme.yellow },
                    { label: "[ 󰜉 REBOOT SYSTEM ]", sub: "Warm Hardware Restart", cmd: "systemctl reboot", confirm: true, col: Theme.orange },
                    { label: "[ 󰐥 POWER OFF ]", sub: "Full System Shutdown", cmd: "systemctl poweroff", confirm: true, col: Theme.red }
                ]
                Rectangle {
                    id: pwCard; required property var modelData; Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: pwM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: pwM.containsMouse ? Theme.cyan : modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout { anchors.centerIn: parent; spacing: 8; Text { Layout.alignment: Qt.AlignHCenter; text: (pwM.containsMouse ? "▸ " : "") + pwCard.modelData.label; color: pwCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3; font.bold: true } Text { Layout.alignment: Qt.AlignHCenter; text: pwCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true } }
                    MouseArea { id: pwM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const d = pwCard.modelData; if (d.confirm) deckBody.requestConfirm(d.label, d.cmd); else deckBody.executeCommand(d.cmd, true); } }
                }
            }
        }
    }
}
