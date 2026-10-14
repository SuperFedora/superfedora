import QtQuick
import QtQuick.Layouts
import Quickshell

// SuperDesk 16-Bit SNES Cartridges: [5] SYSTEM (2x2 Essentials Grid) & [6] POWER (Battery Health & 4 Arcade Action Cards).
ColumnLayout {
    id: deckBody
    property string activeSection: "system"
    property bool batPresent: false; property int batPct: 100; property bool batCharging: false
    signal executeCommand(string cmd, bool closeAfter); signal requestConfirm(string label, string cmd)
    signal switchTabRequested(int tabIndex); signal cycleTabRequested(bool backward); signal closeRequested()
    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
    function focusSearch() { if (deckBody.activeSection === "system") forgeInput.forceActiveFocus(); }

    readonly property var themePresets: [
        { id: "snes", label: "SNES 16-BIT" },              { id: "01-super-blue", label: "SUPER BLUE" },
        { id: "tokyo-night", label: "TOKYO NIGHT" },       { id: "catppuccin", label: "CATPPUCCIN" },
        { id: "nord", label: "NORD" },                     { id: "02-metroid-violet", label: "METROID VIOLET" },
        { id: "03-super-ruby", label: "SUPER RUBY" },      { id: "04-emerald-green", label: "EMERALD GREEN" }
    ]

    function asciiBar(pct) {
        const filled = Math.max(0, Math.min(16, Math.round((pct / 100.0) * 16)));
        return "[" + "█".repeat(filled) + "░".repeat(16 - filled) + "]";
    }

    function runForgeInput() {
        const q = forgeInput.text.trim().replace(/"/g, "");
        if (!q) deckBody.executeCommand("kitty --class floating-term -e bash -c '~/.local/bin/sf forge status; echo; read -n1 -rsp \"Press any key\"'", true);
        else deckBody.executeCommand("kitty --class floating-term -e bash -c '~/.local/bin/sf forge \"" + q + "\"; echo; read -n1 -rsp \"Done. Press any key\"'", true);
    }

    // ---------------- TAB 5: [5] SYSTEM (Clean 2x2 16-Bit SNES Cartridge Grid) ----------------
    GridLayout {
        visible: deckBody.activeSection === "system"
        Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 12; columnSpacing: 12

        // Cartridge 1 (Top-Left): APPEARANCE & 16-BIT HARDWARE FEEL
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 10
                Text { text: "▸ APPEARANCE & 16-BIT FEEL"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                Repeater {
                    model: [
                        { label: "[ DAY / NIGHT MODE: " + (Theme.mode === "light" ? "DAY (LIGHT)" : "NIGHT (DARK)") + " ]", act: "mode", col: Theme.cyan },
                        { label: "[ CORNERS: " + (Theme.corners === "rounded" ? "ROUNDED" : "SQUARE 90°") + " ]", act: "corners", col: Theme.blue },
                        { label: "[ 16-BIT SFX: " + (Status.sfxEnabled ? "ON" : "OFF") + " ]", act: "sfx", col: Status.sfxEnabled ? Theme.green : Theme.muted }
                    ]
                    Rectangle {
                        id: apRow; required property var modelData
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                        color: apM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 2; border.color: apM.containsMouse ? Theme.cyan : modelData.col
                        Text { anchors.centerIn: parent; text: (apM.containsMouse ? "▸ " : "") + apRow.modelData.label; color: apRow.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                        MouseArea {
                            id: apM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const a = apRow.modelData.act;
                                if (a === "sfx") Status.toggleSfx();
                                else if (a === "corners") deckBody.executeCommand("~/.local/bin/sf theme corners toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh corners toggle", false);
                                else deckBody.executeCommand("~/.local/bin/sf theme toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh toggle", false);
                            }
                        }
                    }
                }
            }
        }

        // Cartridge 2 (Top-Right): 16-BIT THEME PRESETS
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 8
                Text { text: "▸ THEME PRESET // " + Theme.themeName.toUpperCase(); color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 6; columnSpacing: 6
                    Repeater {
                        model: deckBody.themePresets
                        Rectangle {
                            id: tpBtn; required property var modelData; readonly property bool isCur: Theme.theme === modelData.id
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                            color: tpM.containsMouse ? Theme.bgHover : (isCur ? Theme.blue : Theme.bg)
                            border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border
                            Text {
                                anchors.centerIn: parent; text: (tpBtn.isCur ? "▸ [*] " : "[ ] ") + tpBtn.modelData.label
                                color: tpBtn.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: tpBtn.isCur
                            }
                            MouseArea {
                                id: tpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: deckBody.executeCommand("~/.local/bin/sf theme " + tpBtn.modelData.id + " || ~/Projects/superfedora/superfedora/lib/apply-theme.sh " + tpBtn.modelData.id, false)
                            }
                        }
                    }
                }
            }
        }

        // Cartridge 3 (Bottom-Left): BTRFS SNAPSHOTS & RECOVERY
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 10
                Text { text: "▸ BTRFS SNAPSHOTS & BOOT-GUARD"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                Text { text: "CPU " + Status.cpu + "%  ·  RAM " + Status.mem + "%  ·  TEMP " + Status.tempC + "°C"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                    color: ckM.containsMouse ? Theme.green : Theme.bg; border.width: 2; border.color: Theme.green
                    Text { anchors.centerIn: parent; text: "▸ [ + SAVE CHECKPOINT ]"; color: ckM.containsMouse ? Theme.bg : Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    MouseArea { id: ckM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("kitty --class floating-term -e bash -c '~/.local/bin/sf rollback --create \"SuperDesk Checkpoint\"; read -n1 -rsp \"Press any key\"'", true) }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                    color: rbM.containsMouse ? Theme.blue : Theme.bg; border.width: 2; border.color: Theme.cyan
                    Text { anchors.centerIn: parent; text: "▸ [ 󰋊 LAUNCH SNAPSHOT TUI (sf rollback) ]"; color: rbM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                    MouseArea { id: rbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("kitty --class floating-term -e ~/.local/bin/sf rollback", true) }
                }
            }
        }

        // Cartridge 4 (Bottom-Right): SOFTWARE & SOURCE FORGE (-march=native)
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 10
                Text { text: "▸ SOFTWARE & SOURCE FORGE (-march=native)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 36; radius: Theme.radiusSm; color: Theme.bg; border.width: 2; border.color: forgeInput.activeFocus ? Theme.cyan : Theme.border
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8
                            Text { text: "󰣪 >"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                            TextInput {
                                id: forgeInput; Layout.fillWidth: true; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; clip: true
                                Keys.onEscapePressed: deckBody.closeRequested(); Keys.onReturnPressed: deckBody.runForgeInput()
                                Text { visible: forgeInput.text === ""; text: "owner/repo (e.g. BurntSushi/ripgrep)..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                            }
                        }
                    }
                    Rectangle {
                        implicitWidth: 96; implicitHeight: 36; radius: Theme.radiusSm; color: fgGo.containsMouse ? Theme.cyan : Theme.blue
                        Text { anchors.centerIn: parent; text: "[FORGE]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                        MouseArea { id: fgGo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.runForgeInput() }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                    color: fgTui.containsMouse ? Theme.blue : Theme.bg; border.width: 2; border.color: Theme.cyan
                    Text { anchors.centerIn: parent; text: "▸ [ 󰣪 LAUNCH FORGE TUI ]"; color: fgTui.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                    MouseArea { id: fgTui; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.runForgeInput() }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                    color: sfTui.containsMouse ? Theme.blue : Theme.bg; border.width: 2; border.color: Theme.cyan
                    Text { anchors.centerIn: parent; text: "▸ [ 󰆍 LAUNCH CONTROL DECK TUI (sf tui) ]"; color: sfTui.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                    MouseArea { id: sfTui; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.executeCommand("kitty --class floating-term -e ~/.local/bin/sf tui", true) }
                }
            }
        }
    }

    // ---------------- TAB 6: [6] POWER (16-Bit Battery Energy Tank & 4 Arcade Action Cards) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "power"
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12

        Rectangle {
            Layout.fillWidth: true; implicitHeight: 126; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: deckBody.batCharging ? Theme.green : Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 16 } spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "▸ " + (deckBody.batCharging ? "󰂄" : "󰁹") + "  BATTERY HEALTH & ENERGY TANK"
                        color: deckBody.batCharging ? Theme.green : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true; Layout.fillWidth: true
                    }
                    Text {
                        text: deckBody.asciiBar(deckBody.batPresent ? deckBody.batPct : 100) + " " + (deckBody.batPresent ? deckBody.batPct : 100) + "% — " + (deckBody.batPresent ? (deckBody.batCharging ? "AC CHARGING" : "DISCHARGING") : "AC LINE POWER")
                        color: deckBody.batCharging ? Theme.green : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; height: 26; spacing: 4
                    Repeater {
                        model: 16
                        Rectangle {
                            required property int index
                            readonly property int pct: deckBody.batPresent ? deckBody.batPct : 100
                            readonly property bool lit: (index + 1) * 6.25 <= pct + 2
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                            color: !lit ? Theme.bg : (deckBody.batCharging ? Theme.green : (pct <= 20 ? Theme.red : Theme.cyan))
                            border.width: 1; border.color: lit ? Theme.cyan : Theme.border
                        }
                    }
                }
                Text {
                    text: Status.bat0Present ? ("THINKPAD BAT0 CHARGE THRESHOLD: " + Status.bat0Threshold) : "POWER SUPPLY: STANDARD ACPI / THINKPAD BAT0 READY"
                    color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
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
                    id: pwCard; required property var modelData
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius
                    color: pwM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 2; border.color: pwM.containsMouse ? Theme.cyan : modelData.col
                    Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { Layout.alignment: Qt.AlignHCenter; text: (pwM.containsMouse ? "▸ " : "") + pwCard.modelData.label; color: pwCard.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3; font.bold: true }
                        Text { Layout.alignment: Qt.AlignHCenter; text: pwCard.modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                    }
                    MouseArea {
                        id: pwM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { const d = pwCard.modelData; if (d.confirm) deckBody.requestConfirm(d.label, d.cmd); else deckBody.executeCommand(d.cmd, true); }
                    }
                }
            }
        }
    }
}
