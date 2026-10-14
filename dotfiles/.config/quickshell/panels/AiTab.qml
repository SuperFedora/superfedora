import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// SuperDesk Tab 1: [1] AI AGENT — Quickshell Prompt Console, Response Viewer, Agent & Ollama Model Selector.
ColumnLayout {
    id: aiTab
    property bool active: false
    signal switchTabRequested(int tabIndex)
    signal closeRequested()
    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

    property string activeAgent: "agy"; property string activeLabel: "Antigravity CLI (agy)"
    property string ollamaHost: "127.0.0.1:11434"; property string ollamaModel: "gemma4:latest"
    property bool ollamaOnline: false; property var ollamaModels: []
    property string pendingCmd: ""; property bool queryRunning: false
    property string responseText: "SuperDesk AI Console ready. Type a prompt above and press Return to query right inside Quickshell, or click [Launch TTY Console] for full interactive TUI."
    property var agents: [
        { id: "agy",     cat: "core",     label: "Antigravity CLI (agy)",    cmd: "agy",    installed: true,  active: true },
        { id: "mcode",   cat: "core",     label: "MiniMax Code (mcode)",     cmd: "mcode",  installed: true,  active: false },
        { id: "grok",    cat: "core",     label: "xAI Grok CLI (grok)",      cmd: "grok",   installed: true,  active: false },
        { id: "vibe",    cat: "core",     label: "Mistral Vibe (vibe)",      cmd: "vibe",   installed: true,  active: false },
        { id: "claude",  cat: "standard", label: "Claude Code (claude)",     cmd: "claude", installed: false, active: false },
        { id: "chatgpt", cat: "standard", label: "ChatGPT / Codex",          cmd: "codex",  installed: false, active: false },
        { id: "ollama",  cat: "local",    label: "Ollama (127.0.0.1:11434)", cmd: "ollama", installed: false, active: false }
    ]

    onActiveChanged: if (aiTab.active) { aiTab.refresh(""); promptInput.forceActiveFocus(); }
    Component.onCompleted: aiTab.refresh("")

    function focusPrompt() { promptInput.forceActiveFocus(); }
    function refresh(preCmd) { aiTab.pendingCmd = preCmd ? (preCmd + "; ") : ""; agentProc.running = false; agentProc.running = true; }
    function runCmd(cmd, closeAfter) { if (closeAfter) aiTab.closeRequested(); Status.playSfx("confirm"); Quickshell.execDetached(["sh", "-c", cmd]); }
    function submitPrompt() {
        const q = promptInput.text.trim();
        if (!q || aiTab.queryRunning) return;
        Status.playSfx("confirm"); aiTab.queryRunning = true;
        aiTab.responseText = "> [" + aiTab.activeAgent.toUpperCase() + " // " + aiTab.ollamaModel + "] " + q + "\n\nQuerying agent...";
        askProc.command = ["sh", "-c", "~/.config/hypr/scripts/quake-ai.sh ask '" + q.replace(/'/g, "'\\''") + "' 2>&1"];
        askProc.running = false; askProc.running = true;
    }

    Process {
        id: askProc
        stdout: StdioCollector {
            onStreamFinished: {
                aiTab.queryRunning = false;
                const q = promptInput.text.trim(); promptInput.text = "";
                aiTab.responseText = (q ? ("> [" + aiTab.activeAgent.toUpperCase() + "] " + q + "\n\n") : "") + (text.trim() || "(No output returned)");
            }
        }
    }

    Process {
        id: agentProc
        command: ["sh", "-c", aiTab.pendingCmd + "~/.config/hypr/scripts/quake-ai.sh list-agents 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                aiTab.pendingCmd = "";
                const list = [], oModels = [];
                for (const line of text.trim().split("\n")) {
                    const p = line.split("|");
                    if (p[0] === "CFG" && p.length >= 5) {
                        aiTab.activeAgent = p[1] || "agy"; aiTab.activeLabel = p[2] || p[1];
                        aiTab.ollamaHost = p[3] || "127.0.0.1:11434"; aiTab.ollamaModel = p[4] || "";
                    } else if (p[0] === "AGENT" && p.length >= 7) {
                        list.push({ id: p[1], cat: p[2], label: p[3], cmd: p[4], installed: p[5] === "1", active: p[6] === "1" });
                    } else if (p[0] === "OLLAMA_STATUS" && p.length >= 4) {
                        aiTab.ollamaHost = p[1] || aiTab.ollamaHost; aiTab.ollamaOnline = p[2] === "1";
                        if (p[3]) aiTab.ollamaModel = p[3];
                    } else if (p[0] === "OLLAMA_MODEL" && p.length >= 6) {
                        const spec = [p[3], p[4]].filter(Boolean).join(" ");
                        oModels.push({ name: p[1], loaded: p[2] === "1", spec: spec, label: spec ? (p[1] + " (" + spec + ")") : p[1] });
                    }
                }
                if (list.length > 0) aiTab.agents = list;
                aiTab.ollamaModels = oModels;
            }
        }
    }

    // 1. Top Status & Quick Action Bar
    Rectangle {
        Layout.fillWidth: true; implicitHeight: 38; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8
            Text { text: "󰚩 ACTIVE: " + aiTab.activeLabel; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
            Rectangle {
                implicitWidth: olBadge.implicitWidth + 14; implicitHeight: 24; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: aiTab.ollamaOnline ? Theme.green : Theme.red
                Text { id: olBadge; anchors.centerIn: parent; text: "OLLAMA " + (aiTab.ollamaOnline ? "ONLINE" : "OFFLINE") + " // " + aiTab.ollamaHost + (aiTab.ollamaModel ? (" (" + aiTab.ollamaModel + ")") : ""); color: aiTab.ollamaOnline ? Theme.green : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
            }
            Repeater {
                model: [
                    { label: "󰆍 Launch TTY Console", cmd: "~/.config/hypr/scripts/quake-ai.sh toggle", close: true, accent: true },
                    { label: "󰑐 Respawn TTY", cmd: "~/.config/hypr/scripts/quake-ai.sh restart", close: true, accent: false },
                    { label: "󰒓 Configure", cmd: "kitty --class floating-term -e ~/.config/hypr/scripts/quake-ai.sh configure", close: true, accent: false }
                ]
                Rectangle {
                    required property var modelData; implicitWidth: btnTxt.implicitWidth + 16; implicitHeight: 26; radius: Theme.radiusSm
                    color: bMouse.containsMouse ? Theme.blue : (modelData.accent ? Theme.bg : Theme.bgHover); border.width: 1; border.color: modelData.accent || bMouse.containsMouse ? Theme.blue : Theme.border
                    Text { id: btnTxt; anchors.centerIn: parent; text: parent.modelData.label; color: bMouse.containsMouse ? Theme.bg : (parent.modelData.accent ? Theme.cyan : Theme.fg); font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: parent.modelData.accent }
                    MouseArea { id: bMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: aiTab.runCmd(parent.modelData.cmd, parent.modelData.close) }
                }
            }
        }
    }

    // 2. Interactive Quickshell Prompt Input + Response Viewer
    RowLayout {
        Layout.fillWidth: true; spacing: 6
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 34; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: promptInput.activeFocus ? 2 : 1; border.color: promptInput.activeFocus ? Theme.blue : Theme.border
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8
                Text { text: "󰚩 >"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                TextInput {
                    id: promptInput; Layout.fillWidth: true; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; clip: true
                    Keys.onEscapePressed: aiTab.closeRequested()
                    Keys.onReturnPressed: aiTab.submitPrompt()
                    Keys.onPressed: event => {
                        if ((event.modifiers & (Qt.AltModifier | Qt.ControlModifier)) && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) { aiTab.switchTabRequested(event.key - Qt.Key_1); event.accepted = true; }
                    }
                    Text { visible: promptInput.text === ""; text: "Ask " + aiTab.activeAgent + " / " + (aiTab.ollamaModel || "Ollama") + " (Press Return to run in SuperDesk)..."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                }
            }
        }
        Rectangle {
            implicitWidth: 84; implicitHeight: 34; radius: Theme.radiusSm; color: askMouse.containsMouse ? Theme.cyan : Theme.blue
            Text { anchors.centerIn: parent; text: aiTab.queryRunning ? "Running..." : "Ask [Ret]"; color: Theme.bg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
            MouseArea { id: askMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: aiTab.submitPrompt() }
        }
        Rectangle {
            implicitWidth: 60; implicitHeight: 34; radius: Theme.radiusSm; color: clrMouse.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: Theme.border
            Text { anchors.centerIn: parent; text: "Clear"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
            MouseArea { id: clrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { promptInput.text = ""; aiTab.responseText = "Console cleared. Ready for next prompt."; } }
        }
    }

    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 112; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
        Flickable {
            anchors { fill: parent; margins: 8 } contentWidth: width; contentHeight: respTxt.implicitHeight; clip: true
            Text { id: respTxt; width: parent.width; text: aiTab.responseText; color: aiTab.queryRunning ? Theme.yellow : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; wrapMode: Text.Wrap }
        }
    }

    // 3. Two-Column Selector: Active CLI Agents (Left) & Ollama Models + Server Actions (Right)
    RowLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
            ColumnLayout {
                anchors { fill: parent; margins: 8 } spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "AI CODING & CLI AGENTS"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: addAgTxt.implicitWidth + 12; implicitHeight: 20; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.blue
                        Text { id: addAgTxt; anchors.centerIn: parent; text: "+ Add Custom Agent"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: aiTab.runCmd("~/.config/hypr/scripts/quake-ai.sh prompt-add", true) }
                    }
                }
                Repeater {
                    model: aiTab.agents
                    Rectangle {
                        id: agRow; required property var modelData
                        readonly property bool isCur: modelData.id === aiTab.activeAgent || modelData.active === true
                        readonly property bool isCustom: modelData.cat === "custom"
                        Layout.fillWidth: true; implicitHeight: 25; radius: Theme.radiusSm; color: agM.containsMouse ? Theme.bgHover : (isCur ? Theme.bg : "transparent"); border.width: isCur ? 1 : 0; border.color: Theme.blue
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 } spacing: 6
                            Text { Layout.fillWidth: true; text: (agRow.isCur ? "[*] " : "[ ] ") + agRow.modelData.label; color: agRow.isCur ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: agRow.isCur; elide: Text.ElideRight }
                            Text {
                                text: (agRow.isCustom && rmM.containsMouse) ? "[x]" : (agRow.isCur ? "ACTIVE" : (agRow.modelData.installed ? "[OK]" : "[--]"))
                                color: (agRow.isCustom && rmM.containsMouse) ? Theme.red : (agRow.isCur ? Theme.blue : (agRow.modelData.installed ? Theme.green : Theme.muted))
                                font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                                MouseArea { id: rmM; anchors.fill: parent; enabled: agRow.isCustom; hoverEnabled: agRow.isCustom; onClicked: aiTab.refresh("~/.config/hypr/scripts/quake-ai.sh remove-agent '" + agRow.modelData.id + "'") }
                            }
                        }
                        MouseArea {
                            id: agM; anchors { fill: parent; rightMargin: agRow.isCustom ? 30 : 0 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { aiTab.activeAgent = agRow.modelData.id; aiTab.activeLabel = agRow.modelData.label; Status.playSfx("click"); aiTab.refresh("~/.config/hypr/scripts/quake-ai.sh select-agent '" + agRow.modelData.id + "'"); }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
            ColumnLayout {
                anchors { fill: parent; margins: 8 } spacing: 3
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text { text: "OLLAMA MODELS (" + aiTab.ollamaHost + ")"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                    Rectangle {
                        implicitWidth: srvTxt.implicitWidth + 12; implicitHeight: 20; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.blue
                        Text { id: srvTxt; anchors.centerIn: parent; text: "Set Server / Model"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: aiTab.runCmd("~/.config/hypr/scripts/quake-ai.sh prompt-ollama", true) }
                    }
                    Rectangle {
                        implicitWidth: 58; implicitHeight: 20; radius: Theme.radiusSm; color: Theme.bg; border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "Refresh"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Status.playSfx("click"); aiTab.refresh(""); } }
                    }
                }
                Text { visible: aiTab.ollamaModels.length === 0; text: aiTab.ollamaOnline ? ("No models installed on " + aiTab.ollamaHost) : ("Server unreachable: http://" + aiTab.ollamaHost); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
                Repeater {
                    model: aiTab.ollamaModels
                    Rectangle {
                        id: omRow; required property var modelData
                        readonly property bool isOmCur: modelData.name !== "" && modelData.name === aiTab.ollamaModel
                        Layout.fillWidth: true; implicitHeight: 26; radius: Theme.radiusSm; color: omM.containsMouse ? Theme.bgHover : (isOmCur ? Theme.bg : "transparent"); border.width: isOmCur ? 1 : 0; border.color: modelData.loaded ? Theme.green : Theme.blue
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 } spacing: 6
                            Text { Layout.fillWidth: true; text: (omRow.isOmCur ? "[*] " : "[ ] ") + omRow.modelData.label; color: omRow.isOmCur ? Theme.cyan : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: omRow.isOmCur; elide: Text.ElideRight }
                            Text { text: omRow.modelData.loaded ? "LOADED" : "READY"; color: omRow.modelData.loaded ? Theme.green : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                        }
                        MouseArea {
                            id: omM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { aiTab.ollamaModel = omRow.modelData.name; aiTab.activeAgent = "ollama"; Status.playSfx("click"); aiTab.refresh("~/.config/hypr/scripts/quake-ai.sh set-ollama '" + aiTab.ollamaHost + "' '" + omRow.modelData.name + "' && ~/.config/hypr/scripts/quake-ai.sh select-agent ollama"); }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
