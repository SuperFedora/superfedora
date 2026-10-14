import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Volume OSD (like Omarchy's swayosd): shows on volume/mute changes.
Scope {
    id: root
    property bool shown: false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    property bool _armed: false
    onVolChanged: show()
    onMutedChanged: show()

    function show() {
        if (!_armed) return;   // ignore the initial value on startup
        shown = true;
        hide.restart();
    }

    Timer { interval: 1500; running: true; onTriggered: root._armed = true }
    Timer { id: hide; interval: 1200; onTriggered: root.shown = false }

    PanelWindow {
        visible: root.shown
        screen: Quickshell.screens[0]
        color: "transparent"
        anchors.bottom: true
        margins.bottom: 80
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 260
        implicitHeight: 44

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius
            border.width: 2
            border.color: Theme.blue

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    text: root.muted ? "󰝟" : root.vol >= 0.66 ? "󰕾" : root.vol >= 0.33 ? "󰖀" : "󰕿"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 18
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: Theme.radiusSm
                    color: Theme.bgAlt
                    Rectangle {
                        width: parent.width * Math.min(1, root.vol)
                        height: parent.height
                        radius: Theme.radiusSm
                        color: root.muted ? Theme.muted : Theme.blue
                    }
                }

                Text {
                    text: Math.round(root.vol * 100)
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: 12
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
