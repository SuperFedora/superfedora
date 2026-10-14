import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Top-bar AI Agent Selector & Quake Console Popover anchored beneath the AI icon.
PanelWindow {
    id: pop

    property bool open: false
    property int rightOffset: 6
    property var targetScreen: Quickshell.screens[0]
    signal closeRequested()

    property string activeAgent: "agy"
    property string activeLabel: "Antigravity CLI (agy)"
    property string ollamaHost: "127.0.0.1:11434"
    property string ollamaModel: "llama3.2"
    property var agents: [
        { id: "agy",     cat: "core",     label: "Antigravity CLI (agy)",    cmd: "agy",    installed: true,  active: true },
        { id: "mcode",   cat: "core",     label: "MiniMax Code (mcode)",     cmd: "mcode",  installed: true,  active: false },
        { id: "grok",    cat: "core",     label: "xAI Grok CLI (grok)",      cmd: "grok",   installed: true,  active: false },
        { id: "vibe",    cat: "core",     label: "Mistral Vibe (vibe)",      cmd: "vibe",   installed: true,  active: false },
        { id: "claude",  cat: "standard", label: "Claude Code (claude)",     cmd: "claude", installed: false, active: false },
        { id: "chatgpt", cat: "standard", label: "ChatGPT / Codex",          cmd: "codex",  installed: false, active: false },
        { id: "ollama",  cat: "local",    label: "Ollama (127.0.0.1:11434)", cmd: "ollama", installed: false, active: false }
    ]

    visible: pop.open
    screen: pop.targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 6; right: Math.max(6, pop.rightOffset) }
    implicitWidth: 320
    implicitHeight: box.implicitHeight

    onOpenChanged: { if (pop.open) pop.refresh(); }
    Component.onCompleted: pop.refresh()

    function refresh() { agentProc.running = true; }

    function runCmd(cmd, closeAfter) {
        if (closeAfter) pop.closeRequested();
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    Process {
        id: agentProc
        command: ["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh list-agents 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.trim().split("\n")) {
                    const p = line.split("|");
                    if (p[0] === "CFG" && p.length >= 5) {
                        pop.activeAgent = p[1] || "agy";
                        pop.activeLabel = p[2] || p[1];
                        pop.ollamaHost = p[3] || "127.0.0.1:11434";
                        pop.ollamaModel = p[4] || "llama3.2";
                    } else if (p[0] === "AGENT" && p.length >= 7) {
                        list.push({
                            id: p[1], cat: p[2], label: p[3], cmd: p[4],
                            installed: p[5] === "1", active: p[6] === "1"
                        });
                    }
                }
                if (list.length > 0) pop.agents = list;
            }
        }
    }

    readonly property var displayRows: {
        const out = [{ header: "YOUR AGENTS (CORE STACK)" }];
        for (const a of pop.agents) {
            if (a.cat === "core") out.push({ agent: a });
        }
        out.push({ header: "STANDARD & LOCAL AGENTS" });
        for (const a of pop.agents) {
            if (a.cat === "standard" || a.cat === "local") out.push({ agent: a });
        }
        const custom = pop.agents.filter(a => a.cat === "custom");
        if (custom.length > 0) {
            out.push({ header: "CUSTOM AGENTS" });
            for (const a of custom) out.push({ agent: a, custom: true });
        }
        out.push({ header: "OLLAMA & EXTENSIBLE FRAMEWORK" });
        out.push({ info: "Ollama: " + pop.ollamaHost + " (" + pop.ollamaModel + ")" });
        out.push({ label: "Set Ollama IP:Port & Model...", cmd: "~/.config/hypr/scripts/quake-ai.sh prompt-ollama", close: true });
        out.push({ label: "+ Add Other AI Agent...", cmd: "~/.config/hypr/scripts/quake-ai.sh prompt-add", close: true });
        out.push({ label: "Configure Ollama & Agents (TUI)...", cmd: "kitty --class floating-term -e ~/.config/hypr/scripts/quake-ai.sh configure", close: true, accent: true });
        return out;
    }

    Rectangle {
        id: box
        width: parent.width
        implicitHeight: col.implicitHeight + 22
        color: Theme.bg
        radius: Theme.radius
        border.width: 2
        border.color: Theme.blue

        ColumnLayout {
            id: col
            anchors { fill: parent; margins: 10 }
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰚩  QUAKE AI // AGENT & CONSOLE"
                    color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    text: "Esc / Super+`"
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3
                }
            }

            Text {
                text: "Active: " + pop.activeLabel
                color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm
                    color: togMouse.containsMouse ? Theme.blue : Theme.bgAlt
                    border.width: 1; border.color: Theme.blue
                    Text {
                        anchors.centerIn: parent; text: "Toggle Quake [Super+`]"
                        color: togMouse.containsMouse ? Theme.bg : Theme.cyan
                        font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
                    }
                    MouseArea {
                        id: togMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: pop.runCmd("~/.config/hypr/scripts/quake-ai.sh toggle", true)
                    }
                }
                Rectangle {
                    implicitWidth: 82; implicitHeight: 26; radius: Theme.radiusSm
                    color: rspMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
                    border.width: 1; border.color: Theme.border
                    Text {
                        anchors.centerIn: parent; text: "Respawn"
                        color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2
                    }
                    MouseArea {
                        id: rspMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: pop.runCmd("~/.config/hypr/scripts/quake-ai.sh restart", true)
                    }
                }
            }

            Repeater {
                model: pop.displayRows

                ColumnLayout {
                    id: rowCol
                    required property var modelData
                    readonly property bool isCustom: modelData.custom === true
                    readonly property var ag: modelData.agent || ({ id: "", label: "", active: false, installed: false })
                    readonly property bool isCur: ag.id === pop.activeAgent || ag.active === true
                    Layout.fillWidth: true; spacing: 2

                    Text {
                        visible: rowCol.modelData.header !== undefined
                        text: rowCol.modelData.header || ""
                        color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                        Layout.topMargin: 4
                    }

                    Text {
                        visible: rowCol.modelData.info !== undefined
                        text: rowCol.modelData.info || ""
                        color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2
                    }

                    Rectangle {
                        id: agRect
                        visible: rowCol.modelData.agent !== undefined
                        Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm
                        color: agMouse.containsMouse ? Theme.bgHover : (rowCol.isCur ? Theme.bgAlt : "transparent")
                        border.width: rowCol.isCur ? 1 : 0; border.color: Theme.blue

                        RowLayout {
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                text: (rowCol.isCur ? "[*] " : "[ ] ") + rowCol.ag.label
                                color: rowCol.isCur ? Theme.cyan : Theme.fg
                                font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: rowCol.isCur
                                elide: Text.ElideRight
                            }
                            Text {
                                text: (rowCol.isCustom && rmMouse.containsMouse) ? "[x]" : (rowCol.isCur ? "ACTIVE" : (rowCol.ag.installed ? "[OK]" : "[--]"))
                                color: (rowCol.isCustom && rmMouse.containsMouse) ? Theme.red : (rowCol.isCur ? Theme.blue : (rowCol.ag.installed ? Theme.green : Theme.muted))
                                font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                                MouseArea {
                                    id: rmMouse; anchors.fill: parent
                                    enabled: rowCol.isCustom; hoverEnabled: rowCol.isCustom
                                    cursorShape: rowCol.isCustom ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        pop.runCmd("~/.config/hypr/scripts/quake-ai.sh remove-agent '" + rowCol.ag.id + "'", false);
                                        pop.refresh();
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: agMouse
                            anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: parent.right; rightMargin: rowCol.isCustom ? 32 : 0 }
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pop.activeAgent = rowCol.ag.id;
                                pop.activeLabel = rowCol.ag.label;
                                pop.runCmd("~/.config/hypr/scripts/quake-ai.sh set-agent '" + rowCol.ag.id + "'", true);
                            }
                        }
                    }

                    Rectangle {
                        visible: rowCol.modelData.label !== undefined
                        Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm
                        color: actMouse.containsMouse ? Theme.bgHover : (rowCol.modelData.accent ? Theme.bgAlt : "transparent")
                        Text {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 6 }
                            text: rowCol.modelData.label || ""
                            color: rowCol.modelData.accent ? Theme.blue : Theme.fg
                            font.family: Theme.font; font.pixelSize: Theme.fontSize - 2
                            font.bold: rowCol.modelData.accent === true
                        }
                        MouseArea {
                            id: actMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: pop.runCmd(rowCol.modelData.cmd, rowCol.modelData.close === true)
                        }
                    }
                }
            }
        }
    }
}
