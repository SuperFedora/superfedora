import QtQuick
import QtQuick.Layouts
import Quickshell

// SuperDesk 16-Bit SNES Cartridges: [5] SYSTEM (3 Horizontal Zero-Trust Cards) & [6] POWER (Battery Energy Tank & 4 Arcade Cards).
ColumnLayout {
    id: deckBody
    property string activeSection: "system"
    property bool batPresent: false; property int batPct: 100; property bool batCharging: false
    property string forgeStatus: "READY (-march=native)"
    signal executeCommand(string cmd, bool closeAfter); signal requestConfirm(string label, string cmd)
    signal switchTabRequested(int tabIndex); signal cycleTabRequested(bool backward); signal closeRequested()
    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
    function focusSearch() { if (deckBody.activeSection === "system") forgeInput.forceActiveFocus(); }

    readonly property var forgeChips: ["idlescreen", "ripgrep", "fastfetch", "btop", "fd", "zoxide"]
    readonly property var themePresets: [
        { id: "snes", label: "[ SNES ]" },               { id: "01-super-blue", label: "[ SUPER BLUE ]" },
        { id: "tokyo-night", label: "[ TOKYO NIGHT ]" }, { id: "catppuccin", label: "[ CATPPUCCIN ]" },
        { id: "nord", label: "[ NORD ]" },               { id: "02-metroid-violet", label: "[ METROID VIOLET ]" }
    ]

    function asciiBar(pct) {
        const filled = Math.max(0, Math.min(16, Math.round((pct / 100.0) * 16)));
        return "[" + "█".repeat(filled) + "░".repeat(16 - filled) + "]";
    }

    function runForge(target) {
        const q = String(target || forgeInput.text || "").trim().replace(/['"]/g, "");
        if (!q) return;
        deckBody.forgeStatus = "BUILDING: " + q.toUpperCase() + "...";
        deckBody.executeCommand("(~/.local/bin/sf forge '" + q + "' || ~/Projects/superfedora/superfedora/lib/forge.sh '" + q + "') && notify-send -a SuperFedora 'Source Forge' 'Built " + q + " (-march=native)'", false);
    }

    function nextDockEdge() {
        const order = ["bottom", "left", "right", "top"];
        const cur = String((Status.dockConfig && Status.dockConfig.position) || "bottom").toLowerCase();
        const next = order[(order.indexOf(cur) + 1) % order.length];
        Status.runDockCmd("position " + next);
    }

    // ---------------- TAB 5: [5] SYSTEM (3 Clean 16-Bit Horizontal Cards) ----------------
    ColumnLayout {
        visible: deckBody.activeSection === "system"
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10

        // CARD 1 — STATE & BTRFS SNAPSHOTS (Layer 1 Integrity)
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 112; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 12 } spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "▸ CARD 1 // STATE & BTRFS SNAPSHOTS (LAYER 1 INTEGRITY)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: statTxt.implicitWidth + 16; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.cyan
                        Text { id: statTxt; anchors.centerIn: parent; text: "CPU " + Status.cpu + "%  |  RAM " + Status.mem + "%  |  TEMP " + Status.tempC + "°C"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                        color: ckM.containsMouse ? Theme.green : Theme.bg; border.width: 2; border.color: Theme.green
                        Text { anchors.centerIn: parent; text: (ckM.containsMouse ? "▸ " : "") + "[ + SAVE BTRFS CHECKPOINT ]"; color: ckM.containsMouse ? Theme.bg : Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                        MouseArea {
                            id: ckM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: deckBody.executeCommand("(pkexec snapper -c root create -d 'SuperDesk Checkpoint' || ~/.local/bin/sf rollback --create 'SuperDesk Checkpoint') && notify-send -a SuperFedora 'Btrfs Checkpoint' 'Saved SuperDesk Checkpoint'", false)
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                        color: rbM.containsMouse ? Theme.yellow : Theme.bg; border.width: 2; border.color: Theme.yellow
                        Text { anchors.centerIn: parent; text: (rbM.containsMouse ? "▸ " : "") + "[ ↺ ROLLBACK TO BASELINE ]"; color: rbM.containsMouse ? Theme.bg : Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                        MouseArea {
                            id: rbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: deckBody.requestConfirm("ROLLBACK TO BASELINE SNAPSHOT", "pkexec ~/.local/bin/sf rollback --baseline || ~/.local/bin/sf rollback --baseline")
                        }
                    }
                }
            }
        }

        // CARD 2 — SOFTWARE & SOURCE FORGE (Layer 2 Supply Chain)
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 126; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 12 } spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "▸ CARD 2 // SOFTWARE & SOURCE FORGE (LAYER 2 SUPPLY CHAIN)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; Layout.fillWidth: true }
                    Text { text: deckBody.forgeStatus; color: Theme.green; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "FORGE FROM SOURCE (-march=native):"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm; color: Theme.bg; border.width: 2; border.color: forgeInput.activeFocus ? Theme.cyan : Theme.border
                        TextInput {
                            id: forgeInput; anchors { fill: parent; leftMargin: 8; rightMargin: 8 } verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; clip: true
                            Keys.onReturnPressed: deckBody.runForge(forgeInput.text)
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) { deckBody.closeRequested(); event.accepted = true; }
                                else if ((event.modifiers & (Qt.AltModifier | Qt.ControlModifier)) && event.key >= Qt.Key_1 && event.key <= Qt.Key_6) { deckBody.switchTabRequested(event.key - Qt.Key_1); event.accepted = true; }
                                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { deckBody.cycleTabRequested(event.key === Qt.Key_Backtab || Boolean(event.modifiers & Qt.ShiftModifier)); event.accepted = true; }
                            }
                            Text { visible: forgeInput.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "owner/repo or preset..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                        }
                    }
                    Rectangle {
                        implicitWidth: 96; implicitHeight: 32; radius: Theme.radiusSm; color: fgGo.containsMouse ? Theme.cyan : Theme.blue
                        Text { anchors.centerIn: parent; text: "[ BUILD ]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                        MouseArea { id: fgGo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deckBody.runForge(forgeInput.text) }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: deckBody.forgeChips
                        Rectangle {
                            id: chipBtn; required property string modelData
                            Layout.fillWidth: true; implicitHeight: 28; radius: Theme.radiusSm
                            color: chM.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: chM.containsMouse ? Theme.cyan : Theme.border
                            Text { anchors.centerIn: parent; text: "[ " + chipBtn.modelData + " ]"; color: chM.containsMouse ? Theme.bg : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                            MouseArea { id: chM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { forgeInput.text = chipBtn.modelData; deckBody.runForge(chipBtn.modelData); } }
                        }
                    }
                }
            }
        }

        // CARD 3 — SURFACE & THEME (Layer 3 Interface)
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radius; color: Theme.bgAlt; border.width: 2; border.color: Theme.blue
            Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; border.width: 1; border.color: Theme.border; radius: Theme.radius }
            ColumnLayout {
                anchors { fill: parent; margins: 12 } spacing: 8
                Text { text: "▸ CARD 3 // SURFACE & THEME (LAYER 3 INTERFACE)"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                    Repeater {
                        model: [
                            { act: "mode",    label: "[ MODE: " + (Theme.mode === "light" ? "DAY" : "NIGHT") + " ]", col: Theme.cyan },
                            { act: "corners", label: "[ CORNERS: " + (Theme.corners === "rounded" ? "ROUNDED" : "SQUARE 90°") + " ]", col: Theme.blue },
                            { act: "sfx",     label: "[ 16-BIT SFX: " + (Status.sfxEnabled ? "ON" : "OFF") + " ]", col: Status.sfxEnabled ? Theme.green : Theme.muted },
                            { act: "dock",    label: "[ DOCK: " + String((Status.dockConfig && Status.dockConfig.position) || "bottom").toUpperCase() + " ]", col: Theme.yellow }
                        ]
                        Rectangle {
                            id: sfTog; required property var modelData
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                            color: sfM.containsMouse ? Theme.bgHover : Theme.bg; border.width: 2; border.color: sfM.containsMouse ? Theme.cyan : modelData.col
                            Text { anchors.centerIn: parent; text: sfTog.modelData.label; color: sfTog.modelData.col; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
                            MouseArea {
                                id: sfM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const a = sfTog.modelData.act;
                                    if (a === "sfx") Status.toggleSfx();
                                    else if (a === "dock") deckBody.nextDockEdge();
                                    else if (a === "corners") deckBody.executeCommand("~/.local/bin/sf theme corners toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh corners toggle", false);
                                    else deckBody.executeCommand("~/.local/bin/sf theme toggle || ~/Projects/superfedora/superfedora/lib/apply-theme.sh toggle", false);
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                    Repeater {
                        model: deckBody.themePresets
                        Rectangle {
                            id: tpBtn; required property var modelData; readonly property bool isCur: Theme.theme === modelData.id
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                            color: tpM.containsMouse ? Theme.bgHover : (isCur ? Theme.blue : Theme.bg)
                            border.width: isCur ? 2 : 1; border.color: isCur ? Theme.cyan : Theme.border
                            Text {
                                anchors.centerIn: parent; text: (tpBtn.isCur ? "▸ " : "") + tpBtn.modelData.label
                                color: tpBtn.isCur ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
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
                    Text { text: "▸ " + (deckBody.batCharging ? "󰂄" : "󰁹") + "  BATTERY HEALTH & ENERGY TANK"; color: deckBody.batCharging ? Theme.green : Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                    Text { text: deckBody.asciiBar(deckBody.batPresent ? deckBody.batPct : 100) + " " + (deckBody.batPresent ? deckBody.batPct : 100) + "% — " + (deckBody.batPresent ? (deckBody.batCharging ? "AC CHARGING" : "DISCHARGING") : "AC LINE POWER"); color: deckBody.batCharging ? Theme.green : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                }
                RowLayout {
                    Layout.fillWidth: true; height: 26; spacing: 4
                    Repeater {
                        model: 16
                        Rectangle {
                            required property int index; readonly property int pct: deckBody.batPresent ? deckBody.batPct : 100
                            readonly property bool lit: (index + 1) * 6.25 <= pct + 2
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm
                            color: !lit ? Theme.bg : (deckBody.batCharging ? Theme.green : (pct <= 20 ? Theme.red : Theme.cyan))
                            border.width: 1; border.color: lit ? Theme.cyan : Theme.border
                        }
                    }
                }
                Text { text: Status.bat0Present ? ("THINKPAD BAT0 CHARGE THRESHOLD: " + Status.bat0Threshold) : "POWER SUPPLY: STANDARD ACPI / THINKPAD BAT0 READY"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
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
                    MouseArea { id: pwM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const d = pwCard.modelData; if (d.confirm) deckBody.requestConfirm(d.label, d.cmd); else deckBody.executeCommand(d.cmd, true); } }
                }
            }
        }
    }
}
