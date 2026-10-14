import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification daemon: persistent history + DND + transient top-right toast popups.
Scope {
    id: root
    property var activeToasts: []
    readonly property string statePath: Quickshell.env("HOME") + "/.config/superfedora/notifications.json"

    FileView { id: stateFile; path: root.statePath }

    function loadState(): void {
        stateFile.reload();
        const raw = stateFile.text().trim();
        if (!raw) return;
        try {
            const d = JSON.parse(raw);
            if (typeof d.dnd === "boolean") Status.dnd = d.dnd;
            if (Array.isArray(d.history)) {
                Status.notifHistory = d.history.slice(0, 50);
                Status.notifUnread = Status.notifHistory.length;
            }
        } catch (e) {}
    }

    function saveState(): void {
        const payload = JSON.stringify({ dnd: Status.dnd, history: Status.notifHistory });
        Quickshell.execDetached(["python3", "-c",
            "import json,os,sys; p=os.path.expanduser('~/.config/superfedora/notifications.json'); " +
            "os.makedirs(os.path.dirname(p), exist_ok=True); " +
            "open(p,'w').write(sys.argv[1])", payload]);
    }

    function findLive(nid) {
        for (const n of server.trackedNotifications.values) {
            if (n.id === nid) return n;
        }
        return null;
    }

    function hideToast(nid): void {
        root.activeToasts = root.activeToasts.filter(t => t.id !== nid);
    }

    function dismissById(nid): void {
        root.hideToast(nid);
        Status.notifHistory = Status.notifHistory.filter(item => item.id !== nid);
        Status.notifUnread = Status.notifHistory.length;
        const live = root.findLive(nid);
        if (live) live.dismiss();
        root.saveState();
    }

    function clearAll(): void {
        root.activeToasts = [];
        Status.notifHistory = [];
        Status.notifUnread = 0;
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        root.saveState();
    }

    function setDnd(val: bool): void {
        Status.dnd = val;
        if (val) root.activeToasts = root.activeToasts.filter(t => t.urgency === "critical");
        root.saveState();
    }

    function invokeAction(nid, actIdx): void {
        const live = root.findLive(nid);
        if (live && live.actions && live.actions[actIdx]) live.actions[actIdx].invoke();
        root.hideToast(nid);
    }

    Component.onCompleted: {
        root.loadState();
        Status.notifAction = function(act, arg1, arg2) {
            if (act === "toggleDnd") root.setDnd(!Status.dnd);
            else if (act === "setDnd") root.setDnd(Boolean(arg1));
            else if (act === "clearAll") root.clearAll();
            else if (act === "dismiss") root.dismissById(arg1);
            else if (act === "hideToast") root.hideToast(arg1);
            else if (act === "invoke") root.invokeAction(arg1, arg2);
            else if (act === "reload") root.loadState();
        };
    }

    // qs ipc call notifications dismiss|dismissAll|toggleDnd|setDnd|toggle|reload
    IpcHandler {
        target: "notifications"
        function dismiss(): void {
            if (root.activeToasts.length > 0) root.hideToast(root.activeToasts[0].id);
            else if (Status.notifHistory.length > 0) root.dismissById(Status.notifHistory[0].id);
        }
        function dismissAll(): void { root.clearAll(); }
        function toggleDnd(): void { root.setDnd(!Status.dnd); }
        function setDnd(mode: string): void { root.setDnd(mode === "on" || mode === "1" || mode === "true"); }
        function toggle(): void { Status.centerToggleSeq += 1; }
        function reload(): void { root.loadState(); }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const urg = n.urgency === NotificationUrgency.Critical ? "critical"
                : (n.urgency === NotificationUrgency.Low ? "low" : "normal");
            const acts = [];
            if (n.actions) {
                for (let i = 0; i < n.actions.length; i++) acts.push({ idx: i, text: n.actions[i].text });
            }
            const item = {
                id: n.id,
                appName: n.appName || "System",
                appIcon: n.appIcon || "",
                image: n.image || "",
                summary: n.summary || "Notification",
                body: n.body || "",
                urgency: urg,
                time: Qt.formatDateTime(new Date(), "HH:mm"),
                timeout: n.expireTimeout > 0 ? n.expireTimeout : 5000,
                actions: acts
            };
            const filtered = Status.notifHistory.filter(x => x.id !== n.id);
            Status.notifHistory = [item].concat(filtered).slice(0, 50);
            Status.notifUnread = Status.notifHistory.length;
            root.saveState();

            if ((!Status.dnd || urg === "critical") && !Status.sessionLocked) {
                const rest = root.activeToasts.filter(t => t.id !== n.id);
                root.activeToasts = [item].concat(rest).slice(0, 5);
            }
        }
    }

    PanelWindow {
        id: popup
        visible: root.activeToasts.length > 0 && !Status.sessionLocked
        screen: Quickshell.screens[0]
        color: "transparent"
        anchors { top: true; right: true }
        margins { top: Theme.barHeight + 8; right: 10 }
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 360
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 8

            Repeater {
                model: root.activeToasts

                Rectangle {
                    id: card
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: content.implicitHeight + 22
                    color: Theme.bg
                    radius: Theme.radius
                    border.width: 2
                    border.color: modelData.urgency === "critical" ? Theme.red : Theme.blue

                    Timer {
                        running: card.modelData.urgency !== "critical"
                        interval: card.modelData.timeout || 5000
                        onTriggered: root.hideToast(card.modelData.id)
                    }

                    RowLayout {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 10

                        IconImage {
                            readonly property string src: card.modelData.image || card.modelData.appIcon
                            visible: src !== ""
                            source: src.startsWith("/") ? "file://" + src : (src !== "" ? Quickshell.iconPath(src, true) : "")
                            implicitSize: 36
                            Layout.alignment: Qt.AlignTop
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true; text: card.modelData.summary; color: Theme.fg
                                    font.family: Theme.font; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight
                                }
                                Text {
                                    text: "[x]"; color: closeM.containsMouse ? Theme.red : Theme.muted
                                    font.family: Theme.font; font.pixelSize: 11; font.bold: true
                                    MouseArea { id: closeM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissById(card.modelData.id) }
                                }
                            }
                            Text {
                                Layout.fillWidth: true; visible: text !== ""; text: card.modelData.body; color: Theme.fgDim
                                font.family: Theme.font; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 4
                                elide: Text.ElideRight; textFormat: Text.StyledText
                            }
                            Text {
                                text: card.modelData.appName + " · " + card.modelData.time; color: Theme.muted
                                font.family: Theme.font; font.pixelSize: 10
                            }
                            Row {
                                visible: (card.modelData.actions || []).length > 0
                                spacing: 6
                                Repeater {
                                    model: card.modelData.actions || []
                                    Rectangle {
                                        required property var modelData
                                        width: actText.implicitWidth + 14; height: 22; radius: Theme.radiusSm
                                        color: actMouse.containsMouse ? Theme.bgHover : Theme.bgAlt
                                        Text {
                                            id: actText; anchors.centerIn: parent; text: parent.modelData.text
                                            color: Theme.cyan; font.family: Theme.font; font.pixelSize: 11; font.bold: true
                                        }
                                        MouseArea {
                                            id: actMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.invokeAction(card.modelData.id, parent.modelData.idx)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; z: -1
                        onClicked: root.hideToast(card.modelData.id)
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPressed: mouse => { if (mouse.button === Qt.RightButton) root.dismissById(card.modelData.id); }
                    }
                }
            }
        }
    }
}
