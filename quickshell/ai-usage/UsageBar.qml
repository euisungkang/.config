import QtQuick
import QtQuick.Layouts

ColumnLayout {
    required property var theme
    property string label
    property var win
    property color colour: theme.barColour(win ? win.percent : 0)
    spacing: 5
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: parent.parent.label
            color: theme.c("secondary", "#cccccc")
            font.pixelSize: 12
            Layout.fillWidth: true
        }
        Text {
            text: parent.parent.win ? Math.round(parent.parent.win.percent) + "%" : "–"
            color: theme.c("primary", "#ffffff")
            font.pixelSize: 13
            font.bold: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 8
        radius: 4
        color: theme.c("surfaceContainerHighest", "#262626")

        Rectangle {
            width: parent.width * Math.min(100, parent.parent.win ? parent.parent.win.percent : 0) / 100
            height: parent.height
            radius: 4
            color: parent.parent.colour
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }

    Text {
        text: parent.win ? theme.resetText(parent.win.resets_at) : ""
        color: theme.c("tertiary", "#ababab")
        opacity: 0.8
        font.pixelSize: 11
    }
}
