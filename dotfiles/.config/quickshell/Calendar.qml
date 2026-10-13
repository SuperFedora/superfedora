import QtQuick
import QtQuick.Layouts
import Quickshell

// Month calendar popup anchored below the center clock on the top bar.
PanelWindow {
    id: cal

    property bool open: false
    property var targetScreen: Quickshell.screens[0]
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    visible: cal.open
    screen: cal.targetScreen
    color: "transparent"

    anchors.top: true
    margins.top: Theme.barHeight + 6
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 280
    implicitHeight: box.implicitHeight

    function resetToToday() {
        const now = new Date();
        cal.viewYear = now.getFullYear();
        cal.viewMonth = now.getMonth();
    }

    function stepMonth(delta) {
        let m = cal.viewMonth + delta;
        let y = cal.viewYear;
        if (m < 0) { m = 11; y -= 1; }
        else if (m > 11) { m = 0; y += 1; }
        cal.viewMonth = m;
        cal.viewYear = y;
    }

    readonly property var cells: {
        const out = [];
        const firstDow = new Date(cal.viewYear, cal.viewMonth, 1).getDay();
        const daysInMonth = new Date(cal.viewYear, cal.viewMonth + 1, 0).getDate();
        const daysInPrev = new Date(cal.viewYear, cal.viewMonth, 0).getDate();
        const now = new Date();
        const todayY = now.getFullYear();
        const todayM = now.getMonth();
        const todayD = now.getDate();

        for (let i = 0; i < 42; i++) {
            const offset = i - firstDow + 1;
            let d = offset;
            let inMonth = true;
            let isToday = false;
            if (offset < 1) {
                d = daysInPrev + offset;
                inMonth = false;
            } else if (offset > daysInMonth) {
                d = offset - daysInMonth;
                inMonth = false;
            } else {
                isToday = (cal.viewYear === todayY && cal.viewMonth === todayM && d === todayD);
            }
            out.push({ day: d, inMonth: inMonth, isToday: isToday });
        }
        return out;
    }

    Rectangle {
        id: box
        width: parent.width
        implicitHeight: col.implicitHeight + 24
        color: Theme.bg
        border.width: 2
        border.color: Theme.blue

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Month navigation header
            RowLayout {
                Layout.fillWidth: true

                BarLabel {
                    text: "<"
                    bold: true
                    pixelSize: Theme.fontSize
                    onClicked: cal.stepMonth(-1)
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Theme.barHeight

                    Text {
                        anchors.centerIn: parent
                        text: Qt.formatDate(new Date(cal.viewYear, cal.viewMonth, 1), "MMMM yyyy")
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cal.resetToToday()
                    }
                }

                BarLabel {
                    text: ">"
                    bold: true
                    pixelSize: Theme.fontSize
                    onClicked: cal.stepMonth(1)
                }
            }

            // Day-of-week header
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 2
                rowSpacing: 2

                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    Item {
                        required property string modelData
                        Layout.fillWidth: true
                        implicitHeight: 24
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: Theme.blue
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: true
                        }
                    }
                }

                // 6-week day cells
                Repeater {
                    model: cal.cells
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 4
                        color: modelData.isToday ? Theme.blue : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: String(parent.modelData.day)
                            color: parent.modelData.isToday
                                ? Theme.bg
                                : (parent.modelData.inMonth ? Theme.fg : Theme.muted)
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: parent.modelData.isToday
                        }
                    }
                }
            }
        }
    }
}
